// src/serial/dataParser.js
const logger = require('../utils/logger');

class DataParser {
  constructor() {
    // Legacy patterns for single-line events
    this.patterns = {
      voucher: /VOUCHER PRINT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      moneyIn: /MONEY IN:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      collect: /COLLECT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      sessionStart: /SESSION START\s*-\s*MACHINE\s+(\d+)/i,
      sessionEnd: /SESSION END\s*-\s*MACHINE\s+(\d+)/i
    };
    
    // Buffer-based voucher parsing
    this.voucherBuffer = Buffer.alloc(0);
    this.isCollectingVoucher = false;
    this.voucherStartTime = null;
    
    // State for daily report parsing
    this.currentDailyMachine = null;
    this.lastMachineNumber = null;
    
    // State for voucher machine number tracking
    this.waitingForVoucherMachineNumber = false;
    this.currentVoucherMachine = null;
  }

  parseBuffer(data) {
    const machineHex = Buffer.from('MACHINE', 'ascii');
    const voucherHex = Buffer.from('Voucher', 'ascii');
    const text = data.toString('ascii');
    
    // Detect voucher start - either "MACHINE NUMBER" or "Voucher #"
    if ((data.includes(machineHex) && text.includes('NUMBER')) ||
        (data.includes(voucherHex) && text.includes('#'))) {
      if (!this.isCollectingVoucher) {
        this.isCollectingVoucher = true;
        this.voucherBuffer = Buffer.alloc(0);
        this.voucherStartTime = Date.now();
        logger.debug('🎫 Voucher start detected, buffering...');
      }
    }
    
    if (this.isCollectingVoucher) {
      this.voucherBuffer = Buffer.concat([this.voucherBuffer, data]);
      
      if (data.includes(Buffer.from([0x1B, 0x50, 0x00])) || 
          (Date.now() - this.voucherStartTime > 2000)) {
        
        const voucherEvent = this.parseCompleteVoucher(this.voucherBuffer);
        
        this.isCollectingVoucher = false;
        this.voucherBuffer = Buffer.alloc(0);
        this.voucherStartTime = null;
        
        return voucherEvent;
      }
    }
    
    return null;
  }

  parseCompleteVoucher(buffer) {
    try {
      const text = buffer.toString('ascii');
      const cleaned = text.replace(/[\x00-\x1F\x7F-\x9F]/g, ' ').trim();
      
      logger.debug(`📄 Parsing voucher (${buffer.length} bytes)`);
      
      // Use the machine number we captured from the line parser
      let machineNumber = this.currentVoucherMachine;
      
      // Fallback: try to extract from buffer if we missed it
      if (!machineNumber) {
        const machineMatch = text.match(/MACHINE\s+NUMBER[\s\r\n]+(\d+)/i);
        machineNumber = machineMatch ? machineMatch[1] : null;
      }
      
      const voucherMatch = text.match(/Voucher\s*#\s*(\d+)/i);
      const voucherNumber = voucherMatch ? voucherMatch[1] : null;
      
      const amountMatch = text.match(/\$(\d+\.\d{2})/);
      const amount = amountMatch ? parseFloat(amountMatch[1]) : null;
      
      const serialMatch = text.match(/SERIAL\s*#\s*([\w\-]+)/i);
      const serialNumber = serialMatch ? serialMatch[1] : null;
      
      const confidenceMatch = text.match(/Confidence\s+Number\s*:\s*([\d\-]+)/i);
      const confidenceNumber = confidenceMatch ? confidenceMatch[1] : null;
      
      if (!machineNumber || !amount) {
        logger.warn('⚠️ Voucher missing critical fields', {
          machineNumber,
          amount,
          voucherNumber
        });
        return null;
      }
      
      const machineId = `machine_${machineNumber.padStart(2, '0')}`;
      
      logger.info(`🎫 Voucher #${voucherNumber}: $${amount} from machine ${machineNumber}`);
      
      // Clear the machine number after use
      this.currentVoucherMachine = null;
      
      return {
        eventType: 'voucher_print',
        amount: amount,
        machineId: machineId,
        gamingMachineId: machineId,
        timestamp: new Date().toISOString(),
        rawData: `Voucher #${voucherNumber} - $${amount} from Machine ${machineNumber}`,
        metadata: {
          voucherNumber: voucherNumber,
          serialNumber: serialNumber,
          confidenceNumber: confidenceNumber,
          source: 'buffer_parser'
        }
      };
      
    } catch (error) {
      logger.error('Error parsing voucher buffer:', error);
      return null;
    }
  }

  parse(rawData) {
    try {
      const timestamp = new Date().toISOString();
      const trimmedData = rawData.trim();
      
      // CRITICAL: Strip ALL control characters first for pattern matching
      const cleanData = trimmedData.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim();
      
      // CRITICAL: Reset machine context when Unit Daily appears (grand totals, not per-machine)
      if (cleanData.match(/Unit Daily/i)) {
        logger.debug('🚫 Unit Daily detected - resetting machine context');
        this.currentDailyMachine = null;
        this.lastMachineNumber = null;
        return null;
      }
      
      // Skip empty lines and decorative lines
      if (!cleanData || 
          cleanData.match(/^[\*_\-]+$/) || 
          cleanData.match(/^Daily (Books printed|Books cleared|of Vouchers|REMOTE|MATCH)\b/i) ||
          cleanData.match(/^(DATE|SERIAL|Last Cleared|Dailies)/i) ||
          cleanData.match(/by this base unit/i) ||
          cleanData.match(/Redeemable at/i) ||
          cleanData.match(/plays collected/i) ||
          cleanData.match(/Confidence Number/i) ||
          cleanData.match(/Voucher #/i) ||
          cleanData.match(/This voucher is good for/i)) {
        return null;
      }
      
      logger.debug(`🔍 [LINE] "${cleanData.substring(0, 60)}..."`);

      // VOUCHER MACHINE NUMBER DETECTION
      // Check for MACHINE NUMBER header (appears before each voucher)
      if (cleanData.match(/MACHINE\s+NUMBER/i)) {
        this.waitingForVoucherMachineNumber = true;
        logger.debug('🎰 Detected voucher MACHINE NUMBER header');
        return null;
      }
      
      // Capture the machine number (next line after MACHINE NUMBER header)
      if (this.waitingForVoucherMachineNumber) {
        const machineMatch = cleanData.match(/^\s*(\d+)\s*$/);
        if (machineMatch) {
          this.currentVoucherMachine = machineMatch[1];
          this.waitingForVoucherMachineNumber = false;
          logger.info(`🎰 Captured voucher machine number: ${this.currentVoucherMachine}`);
          return null;
        }
      }

      // Try to parse daily summary line
      const dailyEvent = this.parseDailySummaryLine(trimmedData);
      if (dailyEvent) {
        return dailyEvent;
      }

      // Check single-line patterns
      for (const [eventType, pattern] of Object.entries(this.patterns)) {
        const match = cleanData.match(pattern);
        if (match) {
          let machineNumber, amount, gamingMachineId;
          
          if (eventType === 'sessionStart' || eventType === 'sessionEnd') {
            machineNumber = match[1];
            gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
            
            return {
              eventType: eventType === 'sessionStart' ? 'session_start' : 'session_end',
              action: eventType === 'sessionStart' ? 'start' : 'end',
              sessionId: this.generateSessionId(machineNumber),
              machineId: gamingMachineId,
              gamingMachineId,
              timestamp,
              rawData: trimmedData
            };
          } else {
            amount = match[1];
            machineNumber = match[2];
            gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
            
            return {
              eventType: eventType === 'moneyIn' ? 'money_in' : eventType,
              amount: parseFloat(amount),
              machineId: gamingMachineId,
              gamingMachineId,
              timestamp,
              rawData: trimmedData
            };
          }
        }
      }

      return null;

    } catch (error) {
      logger.error('Error parsing line:', error);
      return null;
    }
  }

  parseDailySummaryLine(line) {
    const cleanLine = line.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim();
    
    // Check for machine number line: < 1>
    const machineMatch = cleanLine.match(/^<\s*(\d+)\s*>$/);
    if (machineMatch) {
      const machineNumber = machineMatch[1];
      logger.info(`📊 Captured machine number: ${machineNumber}`);
      this.currentDailyMachine = machineNumber;
      this.lastMachineNumber = machineNumber;
      return null;
    }

    // Check for combined format: < 1>\n Daily In == 897.00
    const combinedMatch = cleanLine.match(/<\s*(\d+)\s*>[\s\n]+Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (combinedMatch) {
  const machineNumber = combinedMatch[1];
  const amount = parseFloat(combinedMatch[2]);
  
  const event = this.buildDailySummaryEvent(machineNumber, amount, 'money_in', new Date().toISOString());
  this.currentDailyMachine = machineNumber;  // ADD THIS LINE
  this.lastMachineNumber = machineNumber;
  
  logger.info(`✅ Daily summary: Machine ${event.machineId}, ${amount} in`);
  return event;
}

    // Handle "Daily Total Paid" (money out for individual machines)
    const paidMatch = cleanLine.match(/Daily\s+Total\s+Paid\s+==\s+(\d+\.\d{2})/i);

    if (paidMatch) {
      if (this.currentDailyMachine) {
        const amount = parseFloat(paidMatch[1]);
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          'money_out',
          new Date().toISOString()
        );
        
        logger.info(`✅ Daily Total Paid: Machine ${event.machineId}, $${amount} out`);
        this.currentDailyMachine = null;
        return event;
      } else {
        logger.debug(`⏭️  Skipping grand total: Daily Total Paid ${paidMatch[1]}`);
        return null;
      }
    }

    // Process "Daily In" if we have a current machine from previous line
    const dailyInMatch = cleanLine.match(/Daily\s+In\s+==\s+(\d+\.\d{2})/i);

    if (dailyInMatch) {
      if (this.currentDailyMachine) {
        const amount = parseFloat(dailyInMatch[1]);
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          'money_in',
          new Date().toISOString()
        );
        
        logger.info(`✅ Daily In summary: Machine ${event.machineId}, ${amount} in`);
        return event;
      } else {
        logger.debug(`⏭️  Skipping grand total: Daily In ${dailyInMatch[1]}`);
        return null;
      }
    }

    // Process "Daily Out"
    const dailyOutMatch = cleanLine.match(/Daily\s+Total\s+Paid\s+==\s+(\d+\.\d{2})/i);

    if (dailyOutMatch) {
      if (this.currentDailyMachine) {
        const amount = parseFloat(dailyOutMatch[1]);
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          'money_out',
          new Date().toISOString()
        );
        
        logger.info(`✅ Daily Total Paid: Machine ${event.machineId}, ${amount} out`);
        this.currentDailyMachine = null;
        return event;
      } else {
        logger.debug(`⏭️  Skipping grand total: Daily Out ${dailyOutMatch[1]}`);
        return null;
      }
    }

    return null;
  }

  buildDailySummaryEvent(machineNumber, amount, eventType, timestamp) {
    const gamingMachineId = `machine_${String(machineNumber).padStart(2, '0')}`;
    const reportDate = new Date().toISOString().split('T')[0];
    
    return {
      eventType: eventType,
      action: 'daily_summary',
      amount: amount,
      machineId: gamingMachineId,
      gamingMachineId: gamingMachineId,
      timestamp: timestamp,
      idempotencyKey: `daily_${eventType}_${gamingMachineId}_${reportDate}_${timestamp}`,
      rawData: `Daily Summary ${eventType === 'money_in' ? 'In' : 'Out'} - Machine ${machineNumber} - $${amount}`,
      metadata: {
        source: 'daily_report',
        reportDate: reportDate,
        isDailyReport: true
      }
    };
  }

  generateSessionId(machineNumber) {
    return `session_${machineNumber}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  resetState() {
    this.currentDailyMachine = null;
    this.lastMachineNumber = null;
    this.isCollectingVoucher = false;
    this.voucherBuffer = Buffer.alloc(0);
    this.voucherStartTime = null;
    this.waitingForVoucherMachineNumber = false;
    this.currentVoucherMachine = null;
    logger.info('Parser state reset');
  }
}

module.exports = DataParser;