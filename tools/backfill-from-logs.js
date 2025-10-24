#!/usr/bin/env node
// backfill-from-logs.js
// Re-parse historical serial data from logs and backfill database
// Usage: node tools/backfill-from-logs.js [date]

const { execSync } = require('child_process');
const sqlite3 = require('sqlite3').verbose();
const DataParser = require('../src/serial/dataParser');
const path = require('path');

// Colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m'
};

function log(color, ...args) {
  console.log(colors[color], ...args, colors.reset);
}

// Parse command line args
const targetDate = process.argv[2] || new Date().toISOString().split('T')[0];
const DB_PATH = path.join(__dirname, '..', 'data', 'gambino-pi.db');

log('cyan', '═══════════════════════════════════════════════════════════');
log('cyan', '🔄 BACKFILL TOOL - Re-parse logs and insert missing events');
log('cyan', '═══════════════════════════════════════════════════════════');
console.log('');
log('blue', `📅 Target date: ${targetDate}`);
log('blue', `💾 Database: ${DB_PATH}`);
console.log('');

// Step 1: Extract raw lines from logs
log('yellow', '📥 Step 1: Extracting serial data from logs...');
console.log('');

let rawLines;
try {
  // Get all serial port lines from the target date
  // Use grep -a to treat binary data as text
  // Escape emoji properly by using environment variable
  const logData = execSync(
    `sudo journalctl -u gambino-pi --since "${targetDate} 00:00:00" --until "${targetDate} 23:59:59" --no-pager | grep -a "Line:"`,
    { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 }
  );
  
  rawLines = logData
    .split('\n')
    .filter(line => line.includes('Line:'))
    .map(line => {
      // Format: "Oct 17 18:07:29 pi-2 gambino-pi[800036]: 2025-10-17T22:07:29.026Z [debug] 📥 Line: ________________________________________..."
      // Extract everything between "Line: " and the trailing "..."
      const match = line.match(/Line:\s*(.+?)\.{3}$/);
      if (match) {
        return match[1].trim();
      }
      // Fallback: just take everything after "Line: "
      const fallback = line.match(/Line:\s*(.+)$/);
      return fallback ? fallback[1].trim().replace(/\.{3,}$/, '') : null;
    })
    .filter(line => line && line.length > 0 && line.length < 500);  // Filter out corrupt/too long lines
  
  log('green', `✅ Found ${rawLines.length} raw serial lines`);
} catch (error) {
  log('red', '❌ Failed to extract logs. Make sure gambino-pi service has logs for this date.');
  log('gray', `   Error: ${error.message}`);
  process.exit(1);
}

if (rawLines.length === 0) {
  log('yellow', '⚠️  No serial data found for this date in logs');
  log('blue', '💡 Try a different date or check if the service was running');
  process.exit(0);
}

console.log('');
log('gray', 'Sample lines:');
rawLines.slice(0, 5).forEach(line => {
  log('gray', `  "${line.substring(0, 60)}..."`);
});
console.log('');

// Step 2: Re-parse with current parser
log('yellow', '🔍 Step 2: Re-parsing with current parser...');
console.log('');

const parser = new DataParser();
const parsedEvents = [];
const skippedLines = [];

rawLines.forEach((line, index) => {
  try {
    const event = parser.parse(line);
    if (event) {
      parsedEvents.push({
        ...event,
        lineNumber: index + 1,
        originalLine: line.substring(0, 80)
      });
    } else {
      skippedLines.push({
        lineNumber: index + 1,
        line: line.substring(0, 80)
      });
    }
  } catch (error) {
    log('red', `  ❌ Parse error on line ${index + 1}: ${error.message}`);
  }
});

log('green', `✅ Parsed ${parsedEvents.length} events`);
log('gray', `   Skipped ${skippedLines.length} lines (decorative/empty)`);

// Show breakdown
const eventTypeCounts = {};
parsedEvents.forEach(e => {
  eventTypeCounts[e.eventType] = (eventTypeCounts[e.eventType] || 0) + 1;
});

console.log('');
log('blue', '📊 Events by type:');
Object.entries(eventTypeCounts).forEach(([type, count]) => {
  log('cyan', `   ${type}: ${count}`);
});
console.log('');

// Step 3: Check what's already in DB
log('yellow', '🔍 Step 3: Checking database for existing events...');
console.log('');

const db = new sqlite3.Database(DB_PATH);

function queryDB(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

async function main() {
  try {
    // Get existing events for this date
    const existingEvents = await queryDB(
      `SELECT id, event_type, machine_id, amount, timestamp 
       FROM events 
       WHERE date(created_at) = ?`,
      [targetDate]
    );

    log('blue', `📊 Database has ${existingEvents.length} events for ${targetDate}`);
    
    if (existingEvents.length > 0) {
      const existingTypes = {};
      existingEvents.forEach(e => {
        existingTypes[e.event_type] = (existingTypes[e.event_type] || 0) + 1;
      });
      
      log('cyan', '   Breakdown:');
      Object.entries(existingTypes).forEach(([type, count]) => {
        log('cyan', `     ${type}: ${count}`);
      });
    }
    console.log('');

    // Compare and find new events
    log('yellow', '🔍 Step 4: Comparing parsed vs database...');
    console.log('');

    const newEvents = [];
    const duplicates = [];

    parsedEvents.forEach(parsed => {
      // Check if this event already exists
      const exists = existingEvents.some(existing => 
        existing.event_type === parsed.eventType &&
        existing.machine_id === parsed.machineId &&
        Math.abs(existing.amount - (parsed.amount || 0)) < 0.01 &&
        new Date(existing.timestamp).toISOString().split('T')[0] === targetDate
      );

      if (exists) {
        duplicates.push(parsed);
      } else {
        newEvents.push(parsed);
      }
    });

    log('green', `✅ Found ${newEvents.length} NEW events to insert`);
    log('gray', `   ${duplicates.length} events already in database`);
    console.log('');

    if (newEvents.length === 0) {
      log('green', '✅ Database is already up to date!');
      db.close();
      return;
    }

    // Show what will be inserted
    log('blue', '📋 New events to insert:');
    newEvents.forEach(event => {
      const amount = event.amount ? `$${event.amount.toFixed(2)}` : 'N/A';
      log('cyan', `   ${event.eventType.padEnd(12)} ${event.machineId.padEnd(12)} ${amount}`);
    });
    console.log('');

    // Ask for confirmation
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    readline.question('Insert these events into database? (y/n): ', (answer) => {
      readline.close();

      if (answer.toLowerCase() !== 'y') {
        log('yellow', 'Cancelled');
        db.close();
        return;
      }

      // Step 5: Insert new events
      log('yellow', '💾 Step 5: Inserting new events...');
      console.log('');

      let insertCount = 0;
      const insertPromises = newEvents.map(event => {
        return new Promise((resolve, reject) => {
          const sql = `
            INSERT INTO events (event_type, machine_id, amount, timestamp, raw_data, synced, created_at)
            VALUES (?, ?, ?, ?, ?, 0, datetime('now'))
          `;
          
          const params = [
            event.eventType,
            event.machineId,
            event.amount || null,
            event.timestamp,
            event.rawData || event.originalLine
          ];

          db.run(sql, params, function(err) {
            if (err) {
              log('red', `  ❌ Failed to insert: ${err.message}`);
              reject(err);
            } else {
              insertCount++;
              resolve(this.lastID);
            }
          });
        });
      });

      Promise.all(insertPromises)
        .then(() => {
          log('green', `✅ Successfully inserted ${insertCount} events`);
          console.log('');
          
          // Show final summary
          return queryDB(
            `SELECT event_type, COUNT(*) as count, SUM(amount) as total
             FROM events 
             WHERE date(created_at) = ?
             GROUP BY event_type`,
            [targetDate]
          );
        })
        .then(summary => {
          log('cyan', '═══════════════════════════════════════════════════════════');
          log('cyan', '📊 FINAL DATABASE STATE FOR ' + targetDate);
          log('cyan', '═══════════════════════════════════════════════════════════');
          console.log('');
          
          summary.forEach(row => {
            const total = row.total ? `$${row.total.toFixed(2)}` : 'N/A';
            log('blue', `${row.event_type.padEnd(12)} ${String(row.count).padEnd(8)} Total: ${total}`);
          });
          
          console.log('');
          log('green', '✅ Backfill complete!');
          log('blue', '💡 Events marked synced=0 will sync to backend in ~30 seconds');
          console.log('');
          
          db.close();
        })
        .catch(error => {
          log('red', '❌ Error during insertion:', error.message);
          db.close();
        });
    });

  } catch (error) {
    log('red', '❌ Error:', error.message);
    db.close();
  }
}

main();