const EventEmitter = require('events');
const logger = require('../utils/logger');

class HealthMonitor extends EventEmitter {
  constructor(config, apiClient) {
    super();
    this.config = config;
    this.apiClient = apiClient;
    this.heartbeatInterval = null;
    this.lastDataReceived = null;
    this.serialConnected = false;
    this.isRunning = false;
  }

  start() {
    if (this.isRunning) return;
    
    const interval = this.config.get('heartbeatInterval') || 30000;
    
    this.heartbeatInterval = setInterval(async () => {
      await this.sendHeartbeat();
    }, interval);
    
    this.isRunning = true;
    logger.info(`❤️ Health monitoring started (${interval}ms interval)`);
  }

  stop() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
    this.isRunning = false;
    logger.info('Health monitoring stopped');
  }

  async sendHeartbeat() {
    try {
      const healthData = this.getHealthData();
      await this.apiClient.sendHeartbeat(healthData);
    } catch (error) {
      logger.error('Failed to send heartbeat:', error.message);
    }
  }

  getHealthData() {
    const data = {
      timestamp: new Date().toISOString(),
      serialConnected: this.serialConnected,
      lastDataReceived: this.lastDataReceived,
      queueSize: this.apiClient?.eventQueue?.size() || 0
    };
    logger.debug(`📊 Health data: serialConnected=${this.serialConnected}`);
    return data;
  }

  updateSerialStatus(connected) {
    logger.info(`🔌 Serial status update: ${connected ? 'CONNECTED' : 'DISCONNECTED'}`);
    this.serialConnected = connected;
    if (connected) {
      this.lastDataReceived = new Date().toISOString();
    }
  }
}

module.exports = HealthMonitor;