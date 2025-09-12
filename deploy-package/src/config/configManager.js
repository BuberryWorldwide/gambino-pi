const fs = require('fs').promises;
const path = require('path');
const logger = require('../utils/logger');

class ConfigManager {
  constructor() {
    this.configPath = path.join(__dirname, 'config.json');
    this.config = {
      // Default configuration
      machineId: process.env.MACHINE_ID || 'dev-pi-001',
      storeId: process.env.STORE_ID || 'store_175593957368',
      apiEndpoint: process.env.API_ENDPOINT || 'https://api.gambino.gold',
      machineToken: process.env.MACHINE_TOKEN || '',
      serialPort: process.env.SERIAL_PORT || '/dev/ttyUSB0',
      serialBaud: 9600,
      heartbeatInterval: 30000, // 30 seconds
      retryAttempts: 3,
      retryDelay: 1000,
      logLevel: process.env.LOG_LEVEL || 'info'
    };
  }

  async load() {
    try {
      const data = await fs.readFile(this.configPath, 'utf8');
      const fileConfig = JSON.parse(data);
      this.config = { ...this.config, ...fileConfig };
      logger.info('Configuration loaded from file');
    } catch (error) {
      if (error.code === 'ENOENT') {
        await this.save();
        logger.info('Created default configuration file');
      } else {
        logger.error('Failed to load configuration:', error);
      }
    }
  }

  async save() {
    try {
      await fs.writeFile(this.configPath, JSON.stringify(this.config, null, 2));
      logger.info('Configuration saved');
    } catch (error) {
      logger.error('Failed to save configuration:', error);
    }
  }

  get(key) {
    return this.config[key];
  }

  set(key, value) {
    this.config[key] = value;
  }

  getAll() {
    return { ...this.config };
  }
}

module.exports = ConfigManager;
