// tests/mockMuthaGoose.js
// Mock Mutha Goose data generator that works with serialMonitor.js

const logger = require('../src/utils/logger');

class MockMuthaGoose {
  constructor() {
    this.machines = [69]; // Your test machines
    this.isRunning = false;
    this.interval = null;
  }

  start() {
    if (this.isRunning) return;
    
    console.log('🎮 Starting Simple Mock Mutha Goose...');
    console.log(`📋 Testing with machines: ${this.machines.join(', ')}`);
    console.log('📡 Generating events every 4-12 seconds...');
    console.log('Press Ctrl+C to stop\n');
    
    this.isRunning = true;
    
    // Generate first event after a short delay
    setTimeout(() => {
      if (this.isRunning) {
        this.generateRandomEvent();
        this.scheduleNext();
      }
    }, 2000);
  }

  scheduleNext() {
    if (!this.isRunning) return;
    
    const delay = Math.random() * 8000 + 4000; // 4-12 seconds
    this.interval = setTimeout(() => {
      if (this.isRunning) {
        this.generateRandomEvent();
        this.scheduleNext();
      }
    }, delay);
  }

  // This is the method that serialMonitor.js expects to exist
  generateRandomEvent() {
    if (!this.isRunning) return null;
    
    const machine = this.machines[Math.floor(Math.random() * this.machines.length)];
    const eventTypes = [
      () => this.generateVoucher(machine),
      () => this.generateMoneyIn(machine),
      () => this.generateCollect(machine),
      () => this.generateSessionStart(machine),
      () => this.generateSessionEnd(machine)
    ];
    
    const eventGenerator = eventTypes[Math.floor(Math.random() * eventTypes.length)];
    const eventData = eventGenerator();
    
    // Format the output to match your logs
    const time = new Date().toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
      hour12: true
    });
    
    console.log(`🎲 ${time} - ${eventData}`);
    
    return eventData;
  }

  generateVoucher(machine) {
    const amount = (Math.random() * 300 + 50).toFixed(2);
    return `VOUCHER PRINT: $${amount} - MACHINE ${machine}`;
  }

  generateMoneyIn(machine) {
    const amount = (Math.random() * 50 + 5).toFixed(2);
    return `MONEY IN: $${amount} - MACHINE ${machine}`;
  }

  generateCollect(machine) {
    const amount = (Math.random() * 200 + 20).toFixed(2);
    return `COLLECT: $${amount} - MACHINE ${machine}`;
  }

  generateSessionStart(machine) {
    return `SESSION START - MACHINE ${machine}`;
  }

  generateSessionEnd(machine) {
    return `SESSION END - MACHINE ${machine}`;
  }

  stop() {
    this.isRunning = false;
    if (this.interval) {
      clearTimeout(this.interval);
      this.interval = null;
    }
    console.log('\n🛑 Simple Mock Mutha Goose stopped');
  }
}

// Export for use as module or run standalone
if (require.main === module) {
  const mock = new MockMuthaGoose();
  mock.start();
  
  process.on('SIGINT', () => {
    console.log('\n🛑 Stopping mock generator...');
    mock.stop();
    process.exit(0);
  });
}

module.exports = MockMuthaGoose;