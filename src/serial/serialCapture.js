// serialCapture.js - BULLETPROOF DATA CAPTURE
// This module's ONLY job is to capture raw serial data to disk
// It does NO parsing, NO logic - just writes bytes
// This means it virtually never crashes

const { SerialPort } = require('serialport');
const fs = require('fs');
const path = require('path');
const EventEmitter = require('events');

class SerialCapture extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.serialPort = null;
    this.spoolPath = config.spoolPath || '/opt/gambino-pi/data/printer-spool.txt';
    this.spoolStream = null;
    this.isConnected = false;
    this.bytesCaptured = 0;
    
    // Ensure spool directory exists
    const spoolDir = path.dirname(this.spoolPath);
    if (!fs.existsSync(spoolDir)) {
      fs.mkdirSync(spoolDir, { recursive: true });
    }
  }

  async start() {
    try {
      await this.connect();
      this.setupRawCapture();
      console.log(`📡 Serial capture started - spooling to: ${this.spoolPath}`);
    } catch (error) {
      console.error('❌ Failed to start serial capture:', error);
      throw error;
    }
  }

  async connect() {
    const portPath = this.config.get('serialPort');
    const baudRate = this.config.get('serialBaud') || 9600;

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
          console.error(`❌ Failed to open serial port ${portPath}:`, err);
          reject(err);
        } else {
          this.isConnected = true;
          console.log(`✅ Serial port ${portPath} opened - capturing to spool`);
          this.emit('connected');
          resolve();
        }
      });

      this.serialPort.on('error', (err) => {
        console.error('❌ Serial port error:', err);
        this.isConnected = false;
        this.emit('error', err);
      });

      this.serialPort.on('close', () => {
        console.warn('⚠️  Serial port closed');
        this.isConnected = false;
        this.emit('disconnected');
      });
    });
  }

  setupRawCapture() {
    // Open append stream to spool file
    this.spoolStream = fs.createWriteStream(this.spoolPath, { flags: 'a' });
    
    // RAW data handler - just write everything
    this.serialPort.on('data', (data) => {
      this.writeToSpool(data);
    });
  }

  writeToSpool(data) {
    try {
      const timestamp = new Date().toISOString();
      const dataStr = data.toString ? data.toString() : data;
      
      // Write with timestamp for later parsing
      const spoolEntry = `[${timestamp}] ${dataStr}`;
      
      if (this.spoolStream) {
        this.spoolStream.write(spoolEntry);
      } else {
        // Fallback to sync write if stream not available
        fs.appendFileSync(this.spoolPath, spoolEntry);
      }
      
      this.bytesCaptured += dataStr.length;
      this.emit('data', dataStr); // Emit for live parsing if desired
      
    } catch (error) {
      // Even if spool write fails, log to console and continue
      console.error('⚠️  Spool write error (non-fatal):', error);
    }
  }

  async stop() {
    if (this.spoolStream) {
      this.spoolStream.end();
    }
    
    return new Promise((resolve) => {
      if (this.serialPort && this.serialPort.isOpen) {
        this.serialPort.close(() => {
          console.log('📡 Serial port closed');
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
      spoolPath: this.spoolPath,
      bytesCaptured: this.bytesCaptured,
      spoolSize: this.getSpoolSize()
    };
  }

  getSpoolSize() {
    try {
      const stats = fs.statSync(this.spoolPath);
      return stats.size;
    } catch (error) {
      return 0;
    }
  }

  // Rotate spool file when it gets too large
  rotateSpoolIfNeeded(maxSizeBytes = 100 * 1024 * 1024) { // 100MB default
    try {
      const size = this.getSpoolSize();
      if (size > maxSizeBytes) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const archivePath = `${this.spoolPath}.${timestamp}`;
        
        // Close current stream
        if (this.spoolStream) {
          this.spoolStream.end();
        }
        
        // Rotate file
        fs.renameSync(this.spoolPath, archivePath);
        
        // Reopen new spool
        this.spoolStream = fs.createWriteStream(this.spoolPath, { flags: 'a' });
        
        console.log(`📦 Spool rotated: ${archivePath} (${(size / 1024 / 1024).toFixed(2)}MB)`);
        this.emit('spool-rotated', archivePath);
      }
    } catch (error) {
      console.error('⚠️  Spool rotation error (non-fatal):', error);
    }
  }
}

module.exports = SerialCapture;