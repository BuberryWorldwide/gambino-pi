require('dotenv').config();
const SerialMonitor = require('./serial/serialMonitor');
const ApiClient = require('./api/apiClient');
const HealthMonitor = require('./health/healthMonitor');
const ConfigManager = require('./config/configManager');
const LocalDatabase = require('./database/localDb');
const SyncManager = require('./sync/syncManager');
const logger = require('./utils/logger');
const TokenManager = require('./utils/tokenManager');

class GambinoPi {
  constructor() {
    this.config = new ConfigManager();
    this.localDb = new LocalDatabase();
    this.apiClient = new ApiClient(this.config);
    this.syncManager = new SyncManager(this.localDb, this.apiClient);
    this.serialMonitor = new SerialMonitor(this.config);
    this.healthMonitor = new HealthMonitor(this.config, this.apiClient);
    this.tokenManager = null; // Will be initialized in start()
    
    this.isRunning = false;
    this.setupGracefulShutdown();
  }

async start() {
  try {
    logger.info('Starting Gambino Pi Edge Device...');
    
    await this.config.load();
    logger.info(`Machine ID: ${this.config.get('machineId')}`);
    
    // Initialize token manager for auto-refresh
    this.tokenManager = new TokenManager(this.config.get('apiEndpoint'));
    await this.tokenManager.init();
    this.apiClient.setTokenManager(this.tokenManager);
    logger.info('🔑 Token auto-refresh enabled');
    
    // Start sync manager first
    this.syncManager.start();
    logger.info('Sync manager started');
    
    // Test API connection (but don't fail if offline)
    try {
      await this.apiClient.testConnection();
      logger.info('API connection verified');
    } catch (error) {
      logger.warn('API offline - will work in offline mode');
    }
    
    // Start serial monitor (non-blocking if hardware missing)
        try {
          await this.serialMonitor.start();
          logger.info('Serial monitoring started');
          this.healthMonitor.updateSerialStatus(this.serialMonitor.isConnected);
        } catch (error) {
          logger.warn('⚠️  Serial monitor failed to start - running without hardware:', error.message);
          this.healthMonitor.updateSerialStatus(false);
          // Continue without serial - don't crash!
        }

    // Force update health status after serial starts
    this.healthMonitor.updateSerialStatus(this.serialMonitor.isConnected); 
    
    this.healthMonitor.start();  // ← Keep this one
    logger.info('Health monitoring started');
    
    this.setupEventHandlers();
    
    this.isRunning = true;
    logger.info('Gambino Pi is ready and monitoring...');
    
  } catch (error) {
    logger.error('Failed to start Gambino Pi:', error);
    process.exit(1);
  }
}

  setupEventHandlers() {
    // Handle parsed events from Mutha Goose
    this.serialMonitor.on('muthaEvent', async (event) => {
      try {
        // ALWAYS store locally first - this ensures no data loss
        const localId = this.localDb.storeEvent(event);
        
        // Try immediate sync if online, but don't fail if offline
        try {
          await this.apiClient.sendEvent(event);
          this.localDb.markEventSynced(localId);
          logger.info(`Event sent: ${event.eventType} - $${event.amount} from ${event.machineId}`);
        } catch (error) {
          logger.info(`Event stored offline: ${event.eventType} - will sync later`);
        }
      } catch (error) {
        logger.error('Failed to store event locally:', error);
      }
    });
  

    

    // Handle session events
    this.serialMonitor.on('sessionEvent', async (session) => {
      try {
        const localId = this.localDb.storeSession(session);
        
        try {
          await this.apiClient.sendSession(session);
          this.localDb.markSessionSynced(localId);
          logger.info(`Session sent: ${session.action} from ${session.machineId}`);
        } catch (error) {
          logger.info(`Session stored offline: ${session.action} - will sync later`);
        }
      } catch (error) {
        logger.error('Failed to store session locally:', error);
      }
    });

    // Handle serial connection status
    this.serialMonitor.on('connected', () => {
      this.healthMonitor.updateSerialStatus(true);
    });

    this.serialMonitor.on('disconnected', () => {
      this.healthMonitor.updateSerialStatus(false);
    });

    this.serialMonitor.on('error', (error) => {
      logger.error('Serial monitor error:', error);
    });
  }

  setupGracefulShutdown() {
    const shutdown = async (signal) => {
      if (!this.isRunning) return;
      
      logger.info(`Received ${signal}, shutting down gracefully...`);
      this.isRunning = false;
      
      try {
        // Try final sync before shutdown
        if (this.syncManager) {
          await this.syncManager.forcSync();
        }
        
        await this.serialMonitor.stop();
        this.healthMonitor.stop();
        this.syncManager.stop();
        await this.apiClient.shutdown();
        this.localDb.close();
        
        logger.info('Graceful shutdown complete');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
      }
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  }

  // Status endpoint for monitoring
  getStatus() {
    return {
      isRunning: this.isRunning,
      serial: this.serialMonitor.getStatus(),
      sync: this.syncManager.getStatus(),
      health: this.healthMonitor.getStatus()
    };
  }
}

if (require.main === module) {
  const gambinoPi = new GambinoPi();
  gambinoPi.start();
}

module.exports = GambinoPi;
