#!/usr/bin/env node
// spool-manager.js - Utility to manage spool files and parser

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const SPOOL_PATH = '/opt/gambino-pi/data/printer-spool.txt';
const POSITION_PATH = '/opt/gambino-pi/data/parser-position.txt';

const commands = {
  status: showStatus,
  tail: tailSpool,
  reparse: reparseAll,
  reset: resetParser,
  clean: cleanOldSpools,
  inspect: inspectSpool,
  help: showHelp
};

function showStatus() {
  console.log('\n📊 Spool System Status\n');
  
  // Spool file info
  if (fs.existsSync(SPOOL_PATH)) {
    const stats = fs.statSync(SPOOL_PATH);
    const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
    console.log(`📄 Spool File: ${SPOOL_PATH}`);
    console.log(`   Size: ${sizeMB} MB`);
    console.log(`   Modified: ${stats.mtime}`);
  } else {
    console.log(`📄 Spool File: Not created yet`);
  }
  
  // Parser position
  if (fs.existsSync(POSITION_PATH)) {
    const position = parseInt(fs.readFileSync(POSITION_PATH, 'utf8'), 10);
    const spoolSize = fs.existsSync(SPOOL_PATH) ? fs.statSync(SPOOL_PATH).size : 0;
    const remaining = spoolSize - position;
    const progress = spoolSize > 0 ? ((position / spoolSize) * 100).toFixed(2) : 100;
    
    console.log(`\n🔍 Parser Position: ${position} bytes`);
    console.log(`   Progress: ${progress}%`);
    console.log(`   Remaining: ${remaining} bytes`);
  } else {
    console.log(`\n🔍 Parser Position: Not set (will start from beginning)`);
  }
  
  // Archived spools
  const spoolDir = path.dirname(SPOOL_PATH);
  const archives = fs.readdirSync(spoolDir)
    .filter(f => f.startsWith('printer-spool.txt.'))
    .sort()
    .reverse();
  
  if (archives.length > 0) {
    console.log(`\n📦 Archived Spools (${archives.length}):`);
    archives.slice(0, 5).forEach(file => {
      const fullPath = path.join(spoolDir, file);
      const stats = fs.statSync(fullPath);
      const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
      console.log(`   ${file} (${sizeMB} MB)`);
    });
    if (archives.length > 5) {
      console.log(`   ... and ${archives.length - 5} more`);
    }
  }
  
  console.log('');
}

async function tailSpool(lines = 20) {
  console.log(`\n📖 Last ${lines} lines from spool:\n`);
  
  if (!fs.existsSync(SPOOL_PATH)) {
    console.log('❌ Spool file not found');
    return;
  }
  
  const fileContent = fs.readFileSync(SPOOL_PATH, 'utf8');
  const allLines = fileContent.split('\n').filter(l => l.trim());
  const lastLines = allLines.slice(-lines);
  
  lastLines.forEach((line, i) => {
    console.log(`${allLines.length - lines + i + 1}: ${line}`);
  });
  
  console.log('');
}

function reparseAll() {
  console.log('\n🔄 Resetting parser to reparse entire spool...\n');
  
  if (fs.existsSync(POSITION_PATH)) {
    fs.unlinkSync(POSITION_PATH);
    console.log('✅ Parser position reset - will reprocess all data on next start');
  } else {
    console.log('ℹ️  No position file found - parser will start from beginning anyway');
  }
  
  console.log('⚠️  Restart the gambino-pi service to apply');
  console.log('   sudo systemctl restart gambino-pi\n');
}

function resetParser() {
  console.log('\n🔄 Resetting parser position to 0...\n');
  fs.writeFileSync(POSITION_PATH, '0');
  console.log('✅ Parser will reprocess entire spool on next start');
  console.log('⚠️  Restart the gambino-pi service to apply\n');
}

function cleanOldSpools() {
  const spoolDir = path.dirname(SPOOL_PATH);
  const archives = fs.readdirSync(spoolDir)
    .filter(f => f.startsWith('printer-spool.txt.'))
    .map(f => ({
      name: f,
      path: path.join(spoolDir, f),
      stats: fs.statSync(path.join(spoolDir, f))
    }))
    .sort((a, b) => b.stats.mtime - a.stats.mtime);
  
  if (archives.length === 0) {
    console.log('\n✨ No archived spools to clean\n');
    return;
  }
  
  // Keep most recent 5, delete the rest
  const toKeep = archives.slice(0, 5);
  const toDelete = archives.slice(5);
  
  if (toDelete.length === 0) {
    console.log('\n✨ Only keeping 5 most recent archives - nothing to delete\n');
    return;
  }
  
  console.log(`\n🗑️  Cleaning up ${toDelete.length} old spool archives...\n`);
  
  let totalSize = 0;
  toDelete.forEach(file => {
    const sizeMB = (file.stats.size / 1024 / 1024).toFixed(2);
    console.log(`   Deleting: ${file.name} (${sizeMB} MB)`);
    fs.unlinkSync(file.path);
    totalSize += file.stats.size;
  });
  
  console.log(`\n✅ Freed ${(totalSize / 1024 / 1024).toFixed(2)} MB\n`);
}

async function inspectSpool(searchTerm) {
  console.log(`\n🔍 Inspecting spool for: "${searchTerm || 'all events'}"\n`);
  
  if (!fs.existsSync(SPOOL_PATH)) {
    console.log('❌ Spool file not found');
    return;
  }
  
  const fileStream = fs.createReadStream(SPOOL_PATH);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });
  
  let lineNum = 0;
  let matches = 0;
  
  for await (const line of rl) {
    lineNum++;
    
    if (!searchTerm || line.toLowerCase().includes(searchTerm.toLowerCase())) {
      matches++;
      console.log(`Line ${lineNum}: ${line}`);
      
      if (matches >= 50) {
        console.log(`\n... (showing first 50 matches, found more)\n`);
        break;
      }
    }
  }
  
  if (matches === 0) {
    console.log('❌ No matches found\n');
  } else {
    console.log(`\n✅ Found ${matches} matches\n`);
  }
}

function showHelp() {
  console.log(`
📚 Spool Manager - Manage your serial data capture

Usage: node spool-manager.js <command> [options]

Commands:
  status              Show spool and parser status
  tail [lines]        Show last N lines from spool (default: 20)
  reparse             Reset parser to reprocess entire spool
  reset               Alias for reparse
  clean               Delete old archived spool files (keeps 5 most recent)
  inspect [term]      Search spool for specific text (shows up to 50 matches)
  help                Show this help message

Examples:
  node spool-manager.js status
  node spool-manager.js tail 50
  node spool-manager.js inspect "VOUCHER"
  node spool-manager.js inspect "MACHINE 03"
  node spool-manager.js clean
  node spool-manager.js reparse

Notes:
  - The spool file captures ALL raw serial data
  - The parser reads from the spool and can be restarted safely
  - When you modify the parser code, existing spool data is preserved
  - Use 'reparse' to reprocess all data with updated parser logic
  `);
}

// Main
const command = process.argv[2] || 'help';
const arg = process.argv[3];

if (commands[command]) {
  commands[command](arg);
} else {
  console.log(`\n❌ Unknown command: ${command}\n`);
  showHelp();
  process.exit(1);
}