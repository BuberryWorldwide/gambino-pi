const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');

class LocalDatabase {
  constructor() {
    // Ensure data directory exists
    const dataDir = path.join(__dirname, '../../data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    
    this.dbPath = path.join(dataDir, 'gambino-pi.db');
    this.db = null;
    this.init();
  }

  init() {
    try {
      this.db = new Database(this.dbPath);
      this.db.pragma('journal_mode = WAL'); // Better for concurrent access
      this.createTables();
      logger.info(`Local database initialized: ${this.dbPath}`);
    } catch (error) {
      logger.error('Failed to initialize database:', error);
      throw error;
    }
  }

  createTables() {
    // Events table
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        machine_id TEXT NOT NULL,
        amount REAL,
        timestamp TEXT NOT NULL,
        raw_data TEXT,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Sessions table  
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        machine_id TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        raw_data TEXT,
        synced INTEGER DEFAULT 0,
        sync_attempts INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create indexes for performance
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_events_synced ON events(synced)');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_sessions_synced ON sessions(synced)');
    
    logger.info('Database tables and indexes created');
  }

  storeEvent(event) {
    const stmt = this.db.prepare(`
      INSERT INTO events (event_type, machine_id, amount, timestamp, raw_data)
      VALUES (?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
      event.eventType,
      event.machineId, 
      event.amount || null,
      event.timestamp,
      event.rawData || null
    );

    logger.debug(`Stored event locally: ${event.eventType} (ID: ${result.lastInsertRowid})`);
    return result.lastInsertRowid;
  }

  storeSession(session) {
    const stmt = this.db.prepare(`
      INSERT INTO sessions (session_id, machine_id, action, timestamp, raw_data)
      VALUES (?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
      session.sessionId,
      session.machineId,
      session.action,
      session.timestamp, 
      session.rawData || null
    );

    logger.debug(`Stored session locally: ${session.action} (ID: ${result.lastInsertRowid})`);
    return result.lastInsertRowid;
  }

  getUnsyncedEvents(limit = 20) {
    const stmt = this.db.prepare(`
      SELECT * FROM events 
      WHERE synced = 0 AND sync_attempts < 5
      ORDER BY created_at ASC 
      LIMIT ?
    `);
    return stmt.all(limit);
  }

  getUnsyncedSessions(limit = 20) {
    const stmt = this.db.prepare(`
      SELECT * FROM sessions 
      WHERE synced = 0 AND sync_attempts < 5
      ORDER BY created_at ASC 
      LIMIT ?
    `);
    return stmt.all(limit);
  }

  markEventSynced(id) {
    const stmt = this.db.prepare('UPDATE events SET synced = 1 WHERE id = ?');
    const result = stmt.run(id);
    logger.debug(`Marked event ${id} as synced`);
    return result.changes > 0;
  }

  markSessionSynced(id) {
    const stmt = this.db.prepare('UPDATE sessions SET synced = 1 WHERE id = ?');
    const result = stmt.run(id);
    logger.debug(`Marked session ${id} as synced`);
    return result.changes > 0;
  }

  incrementSyncAttempts(table, id) {
    const stmt = this.db.prepare(`UPDATE ${table} SET sync_attempts = sync_attempts + 1 WHERE id = ?`);
    stmt.run(id);
  }

  getSyncStats() {
    const eventCount = this.db.prepare('SELECT COUNT(*) as count FROM events WHERE synced = 0').get();
    const sessionCount = this.db.prepare('SELECT COUNT(*) as count FROM sessions WHERE synced = 0').get();
    const totalEvents = this.db.prepare('SELECT COUNT(*) as count FROM events').get();
    const totalSessions = this.db.prepare('SELECT COUNT(*) as count FROM sessions').get();
    
    return {
      pendingEvents: eventCount.count,
      pendingSessions: sessionCount.count,
      totalEvents: totalEvents.count,
      totalSessions: totalSessions.count
    };
  }

  cleanup() {
    // Remove synced records older than 7 days to prevent database bloat
    const stmt1 = this.db.prepare(`
      DELETE FROM events 
      WHERE synced = 1 AND created_at < datetime('now', '-7 days')
    `);
    const stmt2 = this.db.prepare(`
      DELETE FROM sessions 
      WHERE synced = 1 AND created_at < datetime('now', '-7 days')
    `);
    
    const eventsDeleted = stmt1.run().changes;
    const sessionsDeleted = stmt2.run().changes;
    
    if (eventsDeleted > 0 || sessionsDeleted > 0) {
      logger.info(`Cleaned up ${eventsDeleted} events and ${sessionsDeleted} sessions`);
    }
  }

  close() {
    if (this.db) {
      this.db.close();
      logger.info('Database connection closed');
    }
  }
}

module.exports = LocalDatabase;
