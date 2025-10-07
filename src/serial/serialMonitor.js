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
    this.printerPort = null;
    this.parser = null;
    this.dataParser = new DataParser();
    this.isConnected = false;
    this.printerConnected = false;
    this.isDevelopmentMode = process.env.NODE_ENV === 'development';
    this.mockInterval = null;
  }

  async start() {
    try {
      if (this.isDevelopmentMode) {
        logger.info('📡 Starting in development mode - using mock data');
        this.startMockMode();
      } else {
        await this.connect();
        await this.connectPrinter();
        this.setupDataHandling();
      }
      logger.info(`📡 Serial monitor started`);
    } catch (error) {
      logger.error('Failed to start serial monitor:', error);
      throw error;
    }
  }

  startMockMode() {
    const MockMuthaGoose = require('../../tests/mockMuthaGoose');
    this.mockGenerator = new MockMuthaGoose();
    
    this.isConnected = true;
    this.emit('connected');
    
    const generateEvent = () => {
      const mockData = this.mockGenerator.generateRandomEvent();
      if (mockData) {
        this.processData(mockData);
      }
      
      const delay = Math.random() * 10000 + 5000;
      this.mockInterval = setTimeout(generateEvent, delay);
    };
    
    generateEvent();
    
    logger.info('📡 Mock data generator active (5-15 sec intervals)');
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

  async connectPrinter() {
    const printerPath = this.config.get('printerPort');
    
    // If no printer port configured, skip
    if (!printerPath) {
      logger.info('No printer port configured, skipping printer pass-through');
      return;
    }

    const baudRate = this.config.get('serialBaud');

    return new Promise((resolve, reject) => {
      this.printerPort = new SerialPort({
        path: printerPath,
        baudRate: baudRate,
        dataBits: 8,
        stopBits: 1,
        parity: 'none',
        autoOpen: false
      });

      this.printerPort.open((err) => {
        if (err) {
          logger.warn(`Failed to open printer port ${printerPath}:`, err);
          logger.warn('Continuing without printer pass-through');
          this.printerPort = null;
          resolve(); // Don't reject - continue without printer
        } else {
          this.printerConnected = true;
          logger.info(`🖨️ Printer port ${printerPath} opened successfully`);
          resolve();
        }
      });

      this.printerPort.on('error', (err) => {
        logger.error('Printer port error:', err);
        this.printerConnected = false;
      });

      this.printerPort.on('close', () => {
        logger.warn('Printer port closed');
        this.printerConnected = false;
      });
    });
  }

  setupDataHandling() {
    // Forward RAW data to printer BEFORE parsing
    this.serialPort.on('data', (rawData) => {
      if (this.printerPort && this.printerConnected) {
        this.printerPort.write(rawData, (err) => {
          if (err) {
            logger.error('Error writing to printer:', err);
          }
        });
      }
    });

    // Parse data for backend (separate stream)
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
    if (this.isDevelopmentMode && this.mockInterval) {
      clearTimeout(this.mockInterval);
      this.mockInterval = null;
    }
    
    if (this.isDevelopmentMode && this.mockGenerator) {
      this.mockGenerator.stop();
    }
    
    return new Promise((resolve) => {
      let closedCount = 0;
      const totalPorts = (this.serialPort ? 1 : 0) + (this.printerPort ? 1 : 0);
      
      if (totalPorts === 0) {
        resolve();
        return;
      }

      const checkComplete = () => {
        closedCount++;
        if (closedCount === totalPorts) {
          logger.info('All ports closed');
          resolve();
        }
      };

      if (this.serialPort && this.serialPort.isOpen) {
        this.serialPort.close(() => {
          logger.info('Serial port closed');
          checkComplete();
        });
      } else {
        checkComplete();
      }

      if (this.printerPort && this.printerPort.isOpen) {
        this.printerPort.close(() => {
          logger.info('Printer port closed');
          checkComplete();
        });
      } else if (this.printerPort) {
        checkComplete();
      }
    });
  }

  getStatus() {
    return {
      connected: this.isConnected,
      printerConnected: this.printerConnected,
      port: this.config.get('serialPort'),
      printerPort: this.config.get('printerPort'),
      developmentMode: this.isDevelopmentMode
    };
  }
}

module.exports = SerialMonitor;