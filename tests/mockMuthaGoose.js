#!/usr/bin/env node

// Mock Mutha Goose - REALISTIC version based on actual Richmond Hot Streak data
// Only generates what the real Mutha Goose actually sends

class MockMuthaGoose {
  constructor() {
    this.isRunning = false;
    this.voucherInterval = null;
    this.summaryInterval = null;
    // Richmond Hot Streak actual machine numbers
    this.machines = [29, 30, 31, 32, 33, 34, 35, 36];
    // Track daily totals for realistic summaries
    this.dailyTotals = {};
    this.machines.forEach(m => this.dailyTotals[m] = 0);
  }

  start() {
    if (this.isRunning) return;
    
    console.log('Mock Mutha Goose - REALISTIC Mode');
    console.log('=================================');
    console.log('Richmond Hot Streak Location');
    console.log(`Machines: ${this.machines.join(', ')}`);
    console.log('');
    console.log('DATA TYPES GENERATED:');
    console.log('1. Voucher prints (random, 30-90 sec intervals)');
    console.log('2. Daily summaries (every 5 minutes, simulating manual button press)');
    console.log('');
    console.log('NOTE: Real Mutha Goose does NOT send:');
    console.log('- Money in events');
    console.log('- Collect events');
    console.log('- Session events');
    console.log('');
    console.log('Press Ctrl+C to stop\n');
    
    this.isRunning = true;
    
    // Vouchers come randomly (players cashing out)
    this.scheduleNextVoucher();
    
    // Daily summaries every 5 minutes (simulating someone pressing the report button)
    this.summaryInterval = setInterval(() => {
      this.generateDailySummaries();
    }, 5 * 60 * 1000); // 5 minutes
  }

  scheduleNextVoucher() {
    if (!this.isRunning) return;
    
    // Random delay between 30-90 seconds (realistic voucher frequency)
    const delay = Math.random() * 60000 + 30000;
    
    this.voucherInterval = setTimeout(() => {
      if (this.isRunning) {
        this.generateVoucherEvent();
        this.scheduleNextVoucher();
      }
    }, delay);
  }

  stop() {
    if (this.voucherInterval) {
      clearTimeout(this.voucherInterval);
      this.voucherInterval = null;
    }
    if (this.summaryInterval) {
      clearInterval(this.summaryInterval);
      this.summaryInterval = null;
    }
    this.isRunning = false;
    console.log('\nMock Mutha Goose stopped');
  }

  getRandomMachine() {
    return this.machines[Math.floor(Math.random() * this.machines.length)];
  }

  // Called by serialMonitor when integrated in development mode
  generateRandomEvent() {
    // 80% vouchers, 20% daily summaries
    if (Math.random() < 0.8) {
      return this.generateVoucherEvent();
    } else {
      // For single event call, return one machine's summary
      const machineNum = this.getRandomMachine();
      const amount = this.dailyTotals[machineNum];
      return `Daily Summary - Machine ${machineNum} - $${amount} in`;
    }
  }

  generateVoucherEvent() {
    const machineNum = this.getRandomMachine();
    const voucherNum = Math.floor(Math.random() * 90000) + 10000;
    
    // Typical voucher amounts in plays (usually 1-50 plays)
    const plays = Math.random() < 0.7 
      ? Math.floor(Math.random() * 10) + 1  // 70% chance: 1-10 plays (small wins)
      : Math.floor(Math.random() * 40) + 10; // 30% chance: 10-50 plays (bigger wins)
    
    const points = plays; // Points typically match plays
    
    // Track for daily summary
    this.dailyTotals[machineNum] += plays;
    
    const event = `Voucher #${voucherNum} - ${plays} plays - ${points} points - Machine ${machineNum}`;
    
    // Only log if running standalone (not integrated with serialMonitor)
    if (require.main === module) {
      const time = new Date().toLocaleTimeString();
      console.log(`${time} - VOUCHER OUT: ${event}`);
    }
    
    return event;
  }

  generateDailySummaries() {
    if (require.main === module) {
      console.log('\n--- DAILY SUMMARY REPORT (Button Pressed) ---');
      const time = new Date().toLocaleTimeString();
      console.log(`${time} - Generating summaries for all machines...\n`);
    }
    
    this.machines.forEach(machineNum => {
      const amount = this.dailyTotals[machineNum];
      const event = `Daily Summary - Machine ${machineNum} - $${amount} in`;
      
      if (require.main === module) {
        console.log(`  ${event}`);
      }
    });
    
    if (require.main === module) {
      console.log('--- End of Daily Summary ---\n');
    }
    
    // Reset daily totals after report
    this.machines.forEach(m => this.dailyTotals[m] = 0);
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