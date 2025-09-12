#!/usr/bin/env node

const LocalDatabase = require('../src/database/localDb');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

class DatabaseBrowser {
  constructor() {
    this.db = new LocalDatabase();
  }

  showMenu() {
    console.log('\n📊 Gambino Pi Database Browser');
    console.log('===============================');
    console.log('1. View all events');
    console.log('2. View all sessions');
    console.log('3. View unsynced events');
    console.log('4. View unsynced sessions');
    console.log('5. View database stats');
    console.log('6. Search events by machine');
    console.log('7. Clear all data');
    console.log('8. Exit');
    console.log('===============================');
  }

  async handleChoice(choice) {
    switch (choice) {
      case '1':
        this.viewAllEvents();
        break;
      case '2':
        this.viewAllSessions();
        break;
      case '3':
        this.viewUnsyncedEvents();
        break;
      case '4':
        this.viewUnsyncedSessions();
        break;
      case '5':
        this.viewStats();
        break;
      case '6':
        rl.question('Enter machine ID to search: ', (machineId) => {
          this.searchEventsByMachine(machineId);
          this.promptUser();
        });
        return;
      case '7':
        rl.question('Are you sure? Type "yes" to confirm: ', (confirm) => {
          if (confirm.toLowerCase() === 'yes') {
            this.clearAllData();
          }
          this.promptUser();
        });
        return;
      case '8':
        console.log('Goodbye!');
        this.db.close();
        rl.close();
        return;
      default:
        console.log('Invalid choice');
    }
    this.promptUser();
  }

  viewAllEvents() {
    const events = this.db.db.prepare('SELECT * FROM events ORDER BY created_at DESC LIMIT 20').all();
    console.log(`\n📝 Recent Events (${events.length}):`);
    events.forEach(event => {
      const status = event.synced ? '✅' : '⏳';
      console.log(`${status} ${event.event_type} | ${event.machine_id} | $${event.amount || 'N/A'} | ${event.created_at}`);
    });
  }

  viewAllSessions() {
    const sessions = this.db.db.prepare('SELECT * FROM sessions ORDER BY created_at DESC LIMIT 20').all();
    console.log(`\n🎮 Recent Sessions (${sessions.length}):`);
    sessions.forEach(session => {
      const status = session.synced ? '✅' : '⏳';
      console.log(`${status} ${session.action} | ${session.machine_id} | ${session.session_id} | ${session.created_at}`);
    });
  }

  viewUnsyncedEvents() {
    const events = this.db.getUnsyncedEvents(50);
    console.log(`\n⏳ Unsynced Events (${events.length}):`);
    events.forEach(event => {
      console.log(`📝 ${event.event_type} | ${event.machine_id} | $${event.amount || 'N/A'} | attempts: ${event.sync_attempts}`);
    });
  }

  viewUnsyncedSessions() {
    const sessions = this.db.getUnsyncedSessions(50);
    console.log(`\n⏳ Unsynced Sessions (${sessions.length}):`);
    sessions.forEach(session => {
      console.log(`🎮 ${session.action} | ${session.machine_id} | attempts: ${session.sync_attempts}`);
    });
  }

  viewStats() {
    const stats = this.db.getSyncStats();
    console.log('\n📊 Database Statistics:');
    console.log(`Total Events: ${stats.totalEvents}`);
    console.log(`Total Sessions: ${stats.totalSessions}`);
    console.log(`Pending Events: ${stats.pendingEvents}`);
    console.log(`Pending Sessions: ${stats.pendingSessions}`);
    
    // Get file size
    const fs = require('fs');
    try {
      const dbStats = fs.statSync(this.db.dbPath);
      const sizeKB = (dbStats.size / 1024).toFixed(2);
      console.log(`Database Size: ${sizeKB} KB`);
    } catch (error) {
      console.log('Database Size: Unknown');
    }
  }

  searchEventsByMachine(machineId) {
    const events = this.db.db.prepare(
      'SELECT * FROM events WHERE machine_id = ? ORDER BY created_at DESC LIMIT 20'
    ).all(machineId);
    
    console.log(`\n🔍 Events for ${machineId} (${events.length}):`);
    events.forEach(event => {
      const status = event.synced ? '✅' : '⏳';
      console.log(`${status} ${event.event_type} | $${event.amount || 'N/A'} | ${event.created_at}`);
    });
  }

  clearAllData() {
    this.db.db.exec('DELETE FROM events');
    this.db.db.exec('DELETE FROM sessions');
    console.log('🗑️ All data cleared');
  }

  promptUser() {
    this.showMenu();
    rl.question('\nEnter your choice (1-8): ', (choice) => {
      this.handleChoice(choice);
    });
  }

  start() {
    console.log('🎯 Gambino Pi Database Browser Started');
    this.promptUser();
  }
}

const browser = new DatabaseBrowser();
browser.start();
