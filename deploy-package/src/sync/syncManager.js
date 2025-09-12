const logger = require('../utils/logger');

class SyncManager {
  constructor(localDb, apiClient) {
    this.localDb = localDb;
    this.apiClient = apiClient;
    this.syncInterval = null;
    this.cleanupInterval = null;
    this.isOnline = false;
    this.isSyncing = false;
    this.syncIntervalMs = 30000; // 30 seconds
    this.lastSyncAttempt = null;
    this.lastSuccessfulSync = null;
  }

  start() {
    // Sync every 30 seconds
    this.syncInterval = setInterval(() => {
      this.syncToBackend();
    }, this.syncIntervalMs);

    // Cleanup old records daily
    this.cleanupInterval = setInterval(() => {
      this.localDb.cleanup();
    }, 24 * 60 * 60 * 1000); // 24 hours

    // Initial sync attempt
    setTimeout(() => this.syncToBackend(), 5000); // Wait 5 seconds after startup
    
    logger.info('Sync manager started');
  }

  stop() {
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
    logger.info('Sync manager stopped');
  }

  async syncToBackend() {
    if (this.isSyncing) {
      logger.debug('Sync already in progress, skipping');
      return;
    }
    
    this.isSyncing = true;
    this.lastSyncAttempt = new Date();
    
    try {
      // Test connectivity with a quick config call
      await this.apiClient.api.get('/api/edge/config');
      this.isOnline = true;
      
      // Sync events first
      const eventsSynced = await this.syncEvents();
      
      // Then sync sessions
      const sessionsSynced = await this.syncSessions();
      
      if (eventsSynced > 0 || sessionsSynced > 0) {
        logger.info(`Sync completed: ${eventsSynced} events, ${sessionsSynced} sessions`);
      }
      
      this.lastSuccessfulSync = new Date();
      
    } catch (error) {
      this.isOnline = false;
      logger.debug('Sync failed - working offline:', error.message);
    } finally {
      this.isSyncing = false;
    }
  }

  async syncEvents() {
    const events = this.localDb.getUnsyncedEvents(10);
    let synced = 0;
    
    for (const event of events) {
      try {
        await this.apiClient.sendEvent({
          eventType: event.event_type,
          machineId: event.machine_id,
          amount: event.amount,
          timestamp: event.timestamp,
          rawData: event.raw_data
        });
        
        this.localDb.markEventSynced(event.id);
        synced++;
        
      } catch (error) {
        this.localDb.incrementSyncAttempts('events', event.id);
        logger.warn(`Failed to sync event ID ${event.id}:`, error.message);
        break; // Stop syncing if backend is down
      }
    }
    
    return synced;
  }

  async syncSessions() {
    const sessions = this.localDb.getUnsyncedSessions(10);
    let synced = 0;
    
    for (const session of sessions) {
      try {
        await this.apiClient.sendSession({
          sessionId: session.session_id,
          machineId: session.machine_id,
          action: session.action,
          timestamp: session.timestamp,
          rawData: session.raw_data
        });
        
        this.localDb.markSessionSynced(session.id);
        synced++;
        
      } catch (error) {
        this.localDb.incrementSyncAttempts('sessions', session.id);
        logger.warn(`Failed to sync session ID ${session.id}:`, error.message);
        break;
      }
    }
    
    return synced;
  }

  getStatus() {
    const stats = this.localDb.getSyncStats();
    return {
      isOnline: this.isOnline,
      isSyncing: this.isSyncing,
      lastSyncAttempt: this.lastSyncAttempt,
      lastSuccessfulSync: this.lastSuccessfulSync,
      ...stats
    };
  }

  // Force immediate sync attempt
  async forcSync() {
    logger.info('Forcing immediate sync...');
    await this.syncToBackend();
  }
}

module.exports = SyncManager;
