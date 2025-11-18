// spoolParser.js - SEPARATE PARSER THAT CAN CRASH SAFELY
// This reads from the spool file created by serialCapture
// It can crash, be restarted, or modified without losing data

const fs = require('fs');
const readline = require('readline');
const EventEmitter = require('events');
const DataParser = require('./dataParser'); // Your existing parser

class SpoolParser extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.spoolPath = config.spoolPath || '/opt/gambino-pi/data/printer-spool.txt';
    this.positionPath = config.positionPath || '/opt/gambino-pi/data/parser-position.txt';
    this.dataParser = new DataParser();
    this.currentPosition = 0;
    this.isWatching = false;
    this.watcher = null;
    this.parseInterval = null;
  }

  async start() {
    try {
      // Load last known position
      this.loadPosition();
      
      // Parse any existing unprocessed data
      await this.parseFromPosition();
      
      // Watch for new data
      this.startWatching();
      
      console.log(`🔍 Spool parser started - watching ${this.spoolPath} from position ${this.currentPosition}`);
    } catch (error) {
      console.error('❌ Failed to start spool parser:', error);
      throw error;
    }
  }

  loadPosition() {
    try {
      if (fs.existsSync(this.positionPath)) {
        const pos = fs.readFileSync(this.positionPath, 'utf8').trim();
        this.currentPosition = parseInt(pos, 10) || 0;
        console.log(`📍 Resuming from position: ${this.currentPosition}`);
      } else {
        this.currentPosition = 0;
        console.log(`📍 Starting from beginning`);
      }
    } catch (error) {
      console.warn('⚠️  Could not load position, starting from 0:', error);
      this.currentPosition = 0;
    }
  }

  savePosition() {
    try {
      fs.writeFileSync(this.positionPath, this.currentPosition.toString());
    } catch (error) {
      console.error('⚠️  Could not save position (non-fatal):', error);
    }
  }

  async parseFromPosition() {
    return new Promise((resolve, reject) => {
      try {
        if (!fs.existsSync(this.spoolPath)) {
          console.log('📄 Spool file not found yet, waiting for data...');
          resolve();
          return;
        }

        const stats = fs.statSync(this.spoolPath);
        
        // If we're at the end, nothing to parse
        if (this.currentPosition >= stats.size) {
          resolve();
          return;
        }

        console.log(`📖 Parsing from position ${this.currentPosition} to ${stats.size}`);

        const stream = fs.createReadStream(this.spoolPath, {
          start: this.currentPosition,
          encoding: 'utf8'
        });

        const rl = readline.createInterface({
          input: stream,
          crlfDelay: Infinity
        });

        let linesParsed = 0;
        let eventsFound = 0;

        rl.on('line', (line) => {
          linesParsed++;
          
          try {
            // Extract timestamp and data from spool format: [timestamp] data
            const match = line.match(/^\[([^\]]+)\]\s*(.*)$/);
            if (match) {
              const timestamp = match[1];
              const rawData = match[2].trim();
              
              if (rawData) {
                // Parse the data
                const parsedEvent = this.parseSpoolLine(rawData, timestamp);
                
                if (parsedEvent) {
                  eventsFound++;
                  this.emit('event', parsedEvent);
                }
              }
            }
          } catch (parseError) {
            // Log parse errors but don't crash - just skip the line
            console.error('⚠️  Parse error on line (skipping):', parseError.message);
          }
          
          // Update position as we go
          this.currentPosition += Buffer.byteLength(line, 'utf8') + 1; // +1 for newline
        });

        rl.on('close', () => {
          this.savePosition();
          console.log(`✅ Parsed ${linesParsed} lines, found ${eventsFound} events`);
          resolve();
        });

        rl.on('error', (error) => {
          console.error('❌ Error reading spool:', error);
          reject(error);
        });

      } catch (error) {
        reject(error);
      }
    });
  }

  parseSpoolLine(rawData, timestamp) {
    try {
      // Clean the data - remove non-printable characters except newlines
      const cleanData = rawData.replace(/[^\x20-\x7E\r\n]/g, '');
      
      if (!cleanData.trim()) {
        return null;
      }

      // Use your existing parser
      const parsedEvent = this.dataParser.parse(cleanData);
      
      if (parsedEvent) {
        // Add spool metadata
        parsedEvent.capturedAt = timestamp;
        parsedEvent.parsedAt = new Date().toISOString();
        
        console.log(`🎯 Event: ${parsedEvent.eventType} - ${parsedEvent.machineId} - $${parsedEvent.amount || 'N/A'}`);
      }
      
      return parsedEvent;
      
    } catch (error) {
      console.error('⚠️  Parse error (non-fatal):', error.message);
      return null;
    }
  }

  startWatching() {
    this.isWatching = true;
    
    // Watch file for changes
    if (fs.existsSync(this.spoolPath)) {
      this.watcher = fs.watch(this.spoolPath, (eventType) => {
        if (eventType === 'change') {
          // Debounce - parse every 1 second when file changes
          if (!this.parseInterval) {
            this.parseInterval = setTimeout(() => {
              this.parseFromPosition().catch(err => {
                console.error('⚠️  Parse error during watch (will retry):', err);
              });
              this.parseInterval = null;
            }, 1000);
          }
        }
      });
    }
    
    // Also poll every 5 seconds as backup
    this.pollInterval = setInterval(() => {
      if (!this.parseInterval) {
        this.parseFromPosition().catch(err => {
          console.error('⚠️  Parse error during poll (will retry):', err);
        });
      }
    }, 5000);
  }

  async stop() {
    this.isWatching = false;
    
    if (this.watcher) {
      this.watcher.close();
    }
    
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
    }
    
    if (this.parseInterval) {
      clearTimeout(this.parseInterval);
    }
    
    // Final parse before stopping
    await this.parseFromPosition();
    
    console.log('🔍 Spool parser stopped');
  }

  // Manual reparse from beginning (for debugging)
  async reparseAll() {
    console.log('🔄 Reparsing entire spool from beginning...');
    this.currentPosition = 0;
    await this.parseFromPosition();
  }

  // Reset position to reprocess everything
  resetPosition() {
    this.currentPosition = 0;
    this.savePosition();
    console.log('🔄 Parser position reset to 0');
  }

  getStatus() {
    const spoolSize = fs.existsSync(this.spoolPath) 
      ? fs.statSync(this.spoolPath).size 
      : 0;
    
    const remaining = spoolSize - this.currentPosition;
    const progress = spoolSize > 0 ? ((this.currentPosition / spoolSize) * 100).toFixed(2) : 100;
    
    return {
      spoolPath: this.spoolPath,
      currentPosition: this.currentPosition,
      spoolSize: spoolSize,
      remainingBytes: remaining,
      progress: `${progress}%`,
      isWatching: this.isWatching
    };
  }
}

module.exports = SpoolParser;