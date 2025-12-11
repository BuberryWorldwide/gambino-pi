const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');
const EventEmitter = require('events');
const fs = require('fs');
const DataParser = require('./dataParser');
const logger = require('../utils/logger');
const SerialLogger = require('../utils/serialLogger');

class SerialMonitor extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.serialPort = null;
    // Printer can be either serial (SerialPort) or USB (/dev/usb/lp*)
    this.printerPort = null;       // SerialPort instance for serial printers
    this.printerFd = null;         // File descriptor for USB printers
    this.printerWriteStream = null;
    this.printerReadStream = null;
    this.printerType = null;       // 'serial' or 'usb'
    this.parser = null;
    this.dataParser = new DataParser();
    this.serialLogger = new SerialLogger();
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
          // Set DTR/RTS high for V1.11 Goose compatibility (universal fix)
          this.serialPort.set({ dtr: true, rts: true }, (setErr) => {
            if (setErr) {
              logger.warn('Failed to set DTR/RTS:', setErr);
            } else {
              logger.info('✅ DTR/RTS signals set');
            }
          });

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

  // Detect printer type based on device path
  _detectPrinterType(printerPath) {
    // USB printers: /dev/usb/lp0, /dev/usb/lp1, etc.
    if (printerPath.includes('/dev/usb/lp')) {
      return 'usb';
    }
    // Serial printers: /dev/ttyUSB*, /dev/ttyS*, /dev/ttyACM*, etc.
    if (printerPath.includes('/dev/tty')) {
      return 'serial';
    }
    // Default to USB for other /dev paths (safer - won't try baud rate)
    return 'usb';
  }

  // Auto-detect printer device - checks USB printers first, then serial
  _autoDetectPrinter() {
    const mainSerialPort = this.config.get('serialPort'); // e.g., /dev/ttyUSB0

    // Try USB printers first (/dev/usb/lp0, lp1, etc.)
    for (let i = 0; i <= 3; i++) {
      const usbPath = `/dev/usb/lp${i}`;
      if (fs.existsSync(usbPath)) {
        logger.info(`🖨️ Auto-detected USB printer: ${usbPath}`);
        return usbPath;
      }
    }

    // Try serial printers (/dev/ttyUSB1, ttyUSB2, etc. - skip the main Goose port)
    for (let i = 0; i <= 5; i++) {
      const serialPath = `/dev/ttyUSB${i}`;
      // Skip the main serial port (Mutha Goose)
      if (serialPath === mainSerialPort) {
        continue;
      }
      if (fs.existsSync(serialPath)) {
        logger.info(`🖨️ Auto-detected serial printer: ${serialPath}`);
        return serialPath;
      }
    }

    // Try /dev/ttyACM* ports
    for (let i = 0; i <= 3; i++) {
      const acmPath = `/dev/ttyACM${i}`;
      if (fs.existsSync(acmPath)) {
        logger.info(`🖨️ Auto-detected ACM printer: ${acmPath}`);
        return acmPath;
      }
    }

    logger.info('🖨️ No printer device auto-detected');
    return null;
  }

  async connectPrinter() {
    // Try config first, then auto-detect
    let printerPath = this.config.get('printerPort');

    // If no config or configured path doesn't exist, auto-detect
    if (!printerPath || !fs.existsSync(printerPath)) {
      if (printerPath) {
        logger.warn(`🖨️ Configured printer ${printerPath} not found, auto-detecting...`);
      }
      printerPath = this._autoDetectPrinter();
    }

    if (!printerPath) {
      logger.info('No printer found, skipping printer pass-through');
      return;
    }

    // Auto-detect printer type based on device path
    this.printerType = this._detectPrinterType(printerPath);
    logger.info(`🖨️ Detected printer type: ${this.printerType} for ${printerPath}`);

    if (this.printerType === 'serial') {
      return this._connectSerialPrinter(printerPath);
    } else {
      return this._connectUsbPrinter(printerPath);
    }
  }

  // Connect to serial printer (DB9/DB25 via USB-to-serial adapter)
  async _connectSerialPrinter(printerPath) {
    const baudRate = this.config.get('serialBaud');

    return new Promise((resolve) => {
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
          logger.warn(`Failed to open serial printer ${printerPath}:`, err.message);
          logger.warn('Continuing without printer pass-through');
          this.printerPort = null;
          resolve();
        } else {
          this.printerConnected = true;
          logger.info(`🖨️ Serial printer ${printerPath} opened successfully`);

          // Forward printer responses back to Mutha Goose
          this.printerPort.on('data', (printerData) => {
            if (this.serialPort && this.isConnected) {
              this.serialPort.write(printerData, (writeErr) => {
                if (writeErr) {
                  logger.error('Error forwarding printer response to Goose:', writeErr);
                } else {
                  logger.debug('✅ Forwarded printer ACK to Goose');
                }
              });
            }
          });

          this.printerPort.on('error', (err) => {
            logger.error('Serial printer error:', err);
            this.printerConnected = false;
          });

          this.printerPort.on('close', () => {
            logger.warn('Serial printer closed');
            this.printerConnected = false;
          });

          resolve();
        }
      });
    });
  }

  // Connect to USB printer (/dev/usb/lp*)
  async _connectUsbPrinter(printerPath) {
    return new Promise((resolve) => {
      try {
        // Check if device exists
        if (!fs.existsSync(printerPath)) {
          logger.warn(`Printer device ${printerPath} does not exist`);
          logger.warn('Continuing without printer pass-through');
          resolve();
          return;
        }

        // Open for read+write using file descriptor
        fs.open(printerPath, fs.constants.O_RDWR | fs.constants.O_NONBLOCK, (err, fd) => {
          if (err) {
            logger.warn(`Failed to open USB printer ${printerPath}:`, err.message);
            logger.warn('Continuing without printer pass-through');
            resolve();
            return;
          }

          this.printerFd = fd;

          // Create write stream for sending data to printer
          this.printerWriteStream = fs.createWriteStream(null, { fd: fd, autoClose: false });

          // Create read stream for receiving ACKs from printer
          this.printerReadStream = fs.createReadStream(null, { fd: fd, autoClose: false });

          this.printerWriteStream.on('error', (err) => {
            logger.error('USB printer write error:', err.message);
            this.printerConnected = false;
          });

          this.printerReadStream.on('error', (err) => {
            // EAGAIN errors are normal for non-blocking reads when no data available
            if (err.code !== 'EAGAIN') {
              logger.error('USB printer read error:', err.message);
            }
          });

          // Forward printer responses back to Mutha Goose
          this.printerReadStream.on('data', (printerData) => {
            if (this.serialPort && this.isConnected) {
              this.serialPort.write(printerData, (writeErr) => {
                if (writeErr) {
                  logger.error('Error forwarding printer response to Goose:', writeErr);
                } else {
                  logger.debug('✅ Forwarded printer ACK to Goose');
                }
              });
            }
          });

          this.printerConnected = true;
          logger.info(`🖨️ USB printer ${printerPath} opened successfully`);
          resolve();
        });
      } catch (err) {
        logger.warn(`Exception opening USB printer ${printerPath}:`, err.message);
        logger.warn('Continuing without printer pass-through');
        resolve();
      }
    });
  }

  // Write data to printer (handles both serial and USB)
  _writeToPrinter(data, callback) {
    if (!this.printerConnected) {
      if (callback) callback(new Error('Printer not connected'));
      return;
    }

    if (this.printerType === 'serial' && this.printerPort) {
      this.printerPort.write(data, callback);
    } else if (this.printerType === 'usb' && this.printerWriteStream) {
      this.printerWriteStream.write(data, callback);
    } else {
      if (callback) callback(new Error('No printer available'));
    }
  }

  setupDataHandling() {
    // DUAL PARSING APPROACH:
    // 1. Raw buffer parsing for vouchers (buffer-based)
    // 2. Line-based parsing for daily reports (readline-based)

    // RAW DATA HANDLER - for voucher detection and printer passthrough
    this.serialPort.on('data', (rawData) => {
      // Send ACK back to Goose for V1.11 compatibility (universal - won't hurt newer versions)
      try {
        this.serialPort.write(Buffer.from([0x06]), (writeErr) => {
          if (writeErr) {
            logger.debug('ACK write error (non-critical):', writeErr);
          }
        });
      } catch (ackErr) {
        logger.debug('ACK error (non-critical):', ackErr);
      }

      // Log raw data
      this.serialLogger.logRaw(rawData, 'ttyUSB0');

      // 1. Forward to printer FIRST (before any processing)
      if (this.printerConnected) {
        this._writeToPrinter(rawData, (err) => {
          if (err) {
            logger.error('Error writing to printer:', err.message);
          }
        });
      }

      // 2. Try buffer-based voucher parsing
      const voucherEvent = this.dataParser.parseBuffer(rawData);
      if (voucherEvent) {
        logger.info(`🎯 Parsed voucher: ${voucherEvent.eventType} from ${voucherEvent.machineId}`);
        this.serialLogger.logEvent(voucherEvent, 'voucher');
        this.emit('muthaEvent', voucherEvent);
      }
    });

    // LINE-BASED HANDLER - for daily reports and other line-based events
    this.parser = this.serialPort.pipe(new ReadlineParser({ delimiter: '\r\n' }));

    this.parser.on('data', (data) => {
      const trimmedData = data.toString().trim();
      if (trimmedData) {
        this.serialLogger.logLine(trimmedData, 'readline');
        logger.debug(`📥 Line: ${trimmedData.substring(0, 60)}...`);
        this.processLineData(trimmedData);
      }
    });
  }

  processLineData(rawData) {
    try {
      // Use line-based parser for daily reports and legacy events
      const parsedEvent = this.dataParser.parse(rawData);

      if (parsedEvent) {
        logger.info(`🎯 Parsed event: ${parsedEvent.eventType} from ${parsedEvent.machineId}`);
        this.serialLogger.logEvent(parsedEvent, 'daily');

        if (parsedEvent.eventType.includes('session')) {
          this.emit('sessionEvent', parsedEvent);
        } else {
          this.emit('muthaEvent', parsedEvent);
        }
      }
    } catch (error) {
      logger.error('Error processing line data:', error);
    }
  }

  // Keep for backwards compatibility with mock mode
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
      let totalToClose = this.serialPort ? 1 : 0;

      // Count printer based on type
      if (this.printerType === 'serial' && this.printerPort) {
        totalToClose++;
      } else if (this.printerType === 'usb' && this.printerFd) {
        totalToClose++;
      }

      if (totalToClose === 0) {
        resolve();
        return;
      }

      const checkComplete = () => {
        closedCount++;
        if (closedCount === totalToClose) {
          logger.info('All ports closed');
          resolve();
        }
      };

      // Close main serial port
      if (this.serialPort && this.serialPort.isOpen) {
        this.serialPort.close(() => {
          logger.info('Serial port closed');
          checkComplete();
        });
      } else if (this.serialPort) {
        checkComplete();
      }

      // Close printer based on type
      if (this.printerType === 'serial' && this.printerPort) {
        if (this.printerPort.isOpen) {
          this.printerPort.close(() => {
            logger.info('Serial printer closed');
            this.printerConnected = false;
            checkComplete();
          });
        } else {
          checkComplete();
        }
      } else if (this.printerType === 'usb' && this.printerFd) {
        // End streams first
        if (this.printerWriteStream) {
          this.printerWriteStream.end();
        }
        if (this.printerReadStream) {
          this.printerReadStream.destroy();
        }

        fs.close(this.printerFd, (err) => {
          if (err) {
            logger.warn('Error closing USB printer fd:', err.message);
          }
          logger.info('USB printer closed');
          this.printerFd = null;
          this.printerConnected = false;
          checkComplete();
        });
      }
    });
  }

  getStatus() {
    return {
      connected: this.isConnected,
      printerConnected: this.printerConnected,
      printerType: this.printerType,
      port: this.config.get('serialPort'),
      printerPort: this.config.get('printerPort'),
      developmentMode: this.isDevelopmentMode
    };
  }
}

module.exports = SerialMonitor;
