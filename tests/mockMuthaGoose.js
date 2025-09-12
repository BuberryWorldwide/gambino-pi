#!/usr/bin/env node

class MockMuthaGoose {
  constructor() {
    this.isRunning = false;
    this.interval = null;
  }

  start() {
    if (this.isRunning) return;
    
    console.log('🎮 Starting Mock Mutha Goose data generator...');
    console.log('📡 Generating events every 5-15 seconds...');
    console.log('Press Ctrl+C to stop\n');
    this.isRunning = true;
    
    this.interval = setInterval(() => {
      this.generateRandomEvent();
    }, Math.random() * 10000 + 5000);
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.isRunning = false;
    console.log('\n🛑 Mock Mutha Goose stopped');
  }

  generateRandomEvent() {
    const events = [
      this.generateVoucherEvent(),
      this.generateMoneyInEvent(), 
      this.generateCollectEvent(),
      this.generateSessionStart(),
      this.generateSessionEnd()
    ];
    
    const event = events[Math.floor(Math.random() * events.length)];
    console.log(`🎲 ${new Date().toLocaleTimeString()} - ${event}`);
    return event;
  }

  generateVoucherEvent() {
    const amount = (Math.random() * 500 + 10).toFixed(2);
    const machine = Math.floor(Math.random() * 99) + 1;
    return `VOUCHER PRINT: $${amount} - MACHINE ${machine.toString().padStart(2, '0')}`;
  }

  generateMoneyInEvent() {
    const amount = (Math.random() * 100 + 5).toFixed(2);
    const machine = Math.floor(Math.random() * 99) + 1;
    return `MONEY IN: $${amount} - MACHINE ${machine.toString().padStart(2, '0')}`;
  }

  generateCollectEvent() {
    const amount = (Math.random() * 200 + 20).toFixed(2);
    const machine = Math.floor(Math.random() * 99) + 1;
    return `COLLECT: $${amount} - MACHINE ${machine.toString().padStart(2, '0')}`;
  }

  generateSessionStart() {
    const machine = Math.floor(Math.random() * 99) + 1;
    return `SESSION START - MACHINE ${machine.toString().padStart(2, '0')}`;
  }

  generateSessionEnd() {
    const machine = Math.floor(Math.random() * 99) + 1;
    return `SESSION END - MACHINE ${machine.toString().padStart(2, '0')}`;
  }
}

if (require.main === module) {
  const mock = new MockMuthaGoose();
  mock.start();
  
  process.on('SIGINT', () => {
    mock.stop();
    process.exit(0);
  });
}

module.exports = MockMuthaGoose;
