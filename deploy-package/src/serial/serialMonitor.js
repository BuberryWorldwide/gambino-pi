const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');
const EventEmitter = require('events');
const DataParser = require('./dataParser');
const logger = require('../utils/logger');

class SerialMonitor extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.serialPort = null;
    this.parser = null;
    this.dataParser = new DataParser();
    this.isConnected = false;
    this.isDevelopmentMode = process.env.NODE_ENV === 'development';
  }

  async start() {
    try {
      if (this.isDevelopmentMode) {
        logger.info('📡 Starting in development mode - using mock data');
        this.startMockMode();
      } else {
        await this.connect();
        this.setupDataHandling();
      }
      logger.info(`📡 Serial monitor started`);
    } catch (error) {
      logger.error('Failed to start serial monitor:', error);
      throw error;
    }
  }

  startMockMode() {
    // In development, simulate serial data using our mock generator
    const MockMuthaGoose = require('../../tests/mockMuthaGoose');
    this.mockGenerator = new MockMuthaGoose();
    
    // Override the mock generator to emit events instead of just logging
    const originalGenerate = this.mockGenerator.generateRandomEvent.bind(this.mockGenerator);
    this.mockGenerator.generateRandomEvent = () => {
      const mockData = originalGenerate();
      this.processData(mockData);
    };
    
    this.mockGenerator.start();
    this.isConnected = true;
    this.emit('connected');
  }

  async connect() {
    const portPath = this.config.get('serialPort');
    const baudRate = this.config.get('serialBaud');

    return new Promise((resolve, reject) => {
      this.serialPort = new SerialPort({
        path: portPath,
        baudRate: baudRate,
        dataBits: 8,
        stopBits: 1,
        parity: 'none',
        autoOpen: false
      });

      this.serialPort.open((err) => {
        if (err) {
          logger.error(`Failed to open serial port ${portPath}:`, err);
          reject(err);
        } else {
          this.isConnected = true;
          logger.info(`✅ Serial port ${portPath} opened successfully`);
          this.emit('connected');
          resolve();
        }
      });

      this.serialPort.on('error', (err) => {
        logger.error('Serial port error:', err);
        this.isConnected = false;
        this.emit('error', err);
        this.emit('disconnected');
      });

      this.serialPort.on('close', () => {
        logger.warn('Serial port closed');
        this.isConnected = false;
        this.emit('disconnected');
      });
    });
  }

  setupDataHandling() {
    this.parser = this.serialPort.pipe(new ReadlineParser({ delimiter: '\r\n' }));
    
    this.parser.on('data', (data) => {
      const trimmedData = data.toString().trim();
      if (trimmedData) {
        logger.debug(`📥 Raw serial data: ${trimmedData}`);
        this.processData(trimmedData);
      }
    });
  }

  processData(rawData) {
    try {
      const parsedEvent = this.dataParser.parse(rawData);
      
      if (parsedEvent) {
        logger.info(`🎯 Parsed event: ${parsedEvent.eventType} from ${parsedEvent.machineId}`);
        
        // Emit different events based on type
        if (parsedEvent.eventType.includes('session')) {
          this.emit('sessionEvent', parsedEvent);
        } else {
          this.emit('muthaEvent', parsedEvent);
        }
      }
    } catch (error) {
      logger.error('Error processing data:', error);
    }
  }

  async stop() {
    if (this.isDevelopmentMode && this.mockGenerator) {
      this.mockGenerator.stop();
    }
    
    return new Promise((resolve) => {
      if (this.serialPort && this.serialPort.isOpen) {
        this.serialPort.close(() => {
          logger.info('Serial port closed');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }

  getStatus() {
    return {
      connected: this.isConnected,
      port: this.config.get('serialPort'),
      developmentMode: this.isDevelopmentMode
    };
  }
}

module.exports = SerialMonitor;
