const fs = require('fs');
const path = require('path');

class SerialLogger {
  constructor(logDir = './data/serial-logs') {
    this.enabled = process.env.ENABLE_SERIAL_LOGGING === 'true';
    this.logDir = logDir;
    this.currentSession = Date.now();
    
    if (this.enabled) {
      this.ensureLogDir();
      console.log('📝 Serial logging ENABLED');
    } else {
      console.log('📝 Serial logging DISABLED');
    }
  }

  ensureLogDir() {
    if (!fs.existsSync(this.logDir)) {
      fs.mkdirSync(this.logDir, { recursive: true });
    }
  }

  getLogFileName(type = 'raw') {
    const now = new Date();
    const date = now.toISOString().split('T')[0];
    return path.join(this.logDir, `${type}-${date}.jsonl`);
  }

  logRaw(data, source = 'ttyUSB0') {
    if (!this.enabled) return;
    
    const timestamp = new Date().toISOString();
    const hex = data.toString('hex');
    const ascii = data.toString('ascii').replace(/[\x00-\x1F\x7F-\x9F]/g, '.');
    
    const logEntry = {
      timestamp,
      session: this.currentSession,
      source,
      length: data.length,
      hex,
      ascii,
      base64: data.toString('base64')
    };

    try {
      fs.appendFileSync(this.getLogFileName('raw'), JSON.stringify(logEntry) + '\n');
    } catch (err) {
      console.error('Failed to write raw log:', err);
    }
  }

  logLine(line, source = 'readline') {
    if (!this.enabled) return;
    
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      session: this.currentSession,
      source,
      line
    };
    
    try {
      fs.appendFileSync(this.getLogFileName('lines'), JSON.stringify(logEntry) + '\n');
    } catch (err) {
      console.error('Failed to write line log:', err);
    }
  }

  logEvent(event, source = 'parser') {
    if (!this.enabled) return;
    
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      session: this.currentSession,
      source,
      event
    };
    
    try {
      fs.appendFileSync(this.getLogFileName('events'), JSON.stringify(logEntry) + '\n');
    } catch (err) {
      console.error('Failed to write event log:', err);
    }
  }
}

module.exports = SerialLogger;
