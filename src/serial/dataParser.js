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
  }

  parseBuffer(data) {
    const machineHex = Buffer.from('MACHINE', 'ascii');
    const voucherHex = Buffer.from('Voucher', 'ascii');
    const text = data.toString('ascii');
    
    // Detect voucher start - either "MACHINE NUMBER" or "Voucher #"
    if ((data.includes(machineHex) && text.includes('NUMBER')) ||
        (data.includes(voucherHex) && text.includes('#'))) {
      if (!this.isCollectingVoucher) {              // ← ADD THIS LINE
        this.isCollectingVoucher = true;
        this.voucherBuffer = Buffer.alloc(0);
        this.voucherStartTime = Date.now();
        logger.debug('🎫 Voucher start detected, buffering...');
      }                                              // ← ADD THIS LINE
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
      
      const machineMatch = text.match(/MACHINE\s+NUMBER[\s\r\n]+(\d+)/i);
      const machineNumber = machineMatch ? machineMatch[1] : null;
      
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
      
      return {
        eventType: 'voucher',
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
      
      if (!trimmedData || 
          trimmedData.match(/^[\*_\-]+$/) || 
          trimmedData.match(/^Daily (Books|of|REMOTE|MATCH|Total)/i) ||
          trimmedData.match(/^(DATE|SERIAL|Last Cleared|Dailies|Unit Daily)/i) ||
          trimmedData.match(/by this base unit/i) ||
          trimmedData.match(/Redeemable at/i) ||
          trimmedData.match(/plays collected/i) ||
          trimmedData.match(/Confidence Number/i) ||
          trimmedData.match(/MACHINE NUMBER/i) ||
          trimmedData.match(/Voucher #/i) ||
          trimmedData.match(/This voucher is good for/i)) {
        return null;
      }
      
      logger.debug(`🔍 [LINE] "${trimmedData.substring(0, 60)}..."`);

      const dailyEvent = this.parseDailySummaryLine(trimmedData);
      if (dailyEvent) {
        return dailyEvent;
      }

      for (const [eventType, pattern] of Object.entries(this.patterns)) {
        const match = trimmedData.match(pattern);
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
    
    const machineMatch = cleanLine.match(/^<\s*(\d+)\s*>$/);
    if (machineMatch) {
      const machineNumber = machineMatch[1];
      logger.info(`📊 Captured machine number: ${machineNumber}`);
      this.currentDailyMachine = machineNumber;
      this.lastMachineNumber = machineNumber;
      return null;
    }

    const combinedMatch = line.match(/<\s*(\d+)\s*>[\s\n]+Daily\s+In\s+==\s+(\d+\.\d{2})/i);    if (combinedMatch) {
      const machineNumber = combinedMatch[1];
      const amount = parseFloat(combinedMatch[2]);
      
      const event = this.buildDailySummaryEvent(machineNumber, amount, 'money_in', new Date().toISOString());
      this.lastMachineNumber = machineNumber;
      this.currentDailyMachine = null;
      
      logger.info(`✅ Daily summary: Machine ${event.machineId}, ${amount} in`);
      return event;
    }

    // NEW: Daily Out line - must come BEFORE Daily In check
    const dailyOutMatch = line.match(/^Daily\s+Out\s+==\s+(\d+\.\d{2})/i);
    if (dailyOutMatch) {
      const amount = parseFloat(dailyOutMatch[1]);
      
      if (this.currentDailyMachine) {
        logger.info(`💸 Daily Out: ${amount} for machine ${this.currentDailyMachine}`);
        
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          'money_out',
          new Date().toISOString()
        );
        
        // Don't reset currentDailyMachine - we still need it for "Daily In"
        
        logger.info(`✅ Daily Out summary: Machine ${event.machineId}, ${amount} out`);
        return event;
      }
      else if (this.lastMachineNumber) {
        const nextMachine = (parseInt(this.lastMachineNumber) + 1).toString();
        logger.info(`💸 Daily Out: ${amount} for inferred machine ${nextMachine}`);
        
        const event = this.buildDailySummaryEvent(nextMachine, amount, 'money_out', new Date().toISOString());
        
        logger.info(`✅ Daily Out summary (inferred): Machine ${event.machineId}, ${amount} out`);
        return event;
      }
    }

    const dailyInMatch = line.match(/^Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (dailyInMatch) {
      const amount = parseFloat(dailyInMatch[1]);
      
      if (this.currentDailyMachine) {
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          'money_in',
          new Date().toISOString()
        );
        this.currentDailyMachine = null;
        logger.info(`✅ Daily In summary: Machine ${event.machineId}, ${amount} in`);
        return event;
      }
      else if (this.lastMachineNumber) {
        const nextMachine = (parseInt(this.lastMachineNumber) + 1).toString();
        const event = this.buildDailySummaryEvent(nextMachine, amount, 'money_in', new Date().toISOString());
        this.lastMachineNumber = nextMachine;
        logger.info(`✅ Daily In summary (inferred): Machine ${event.machineId}, ${amount} in`);
        return event;
      }
      else {
        const event = this.buildDailySummaryEvent('29', amount, 'money_in', new Date().toISOString());
        this.lastMachineNumber = '29';
        logger.info(`✅ Daily In summary: Machine ${event.machineId}, ${amount} in`);
        return event;
      }
    }

    // Unit total Out line (skip this - it's the grand total)
    const outMatch = line.match(/^Out\s+==\s+\d+/i);
    if (outMatch) {
      logger.info(`📊 Unit total Out line detected (skipping grand total)`);
      return null;
    }

    return null;
  }

  buildDailySummaryEvent(machineNumber, amount, eventType, timestamp) {
    const gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
    const reportDate = new Date().toISOString().split('T')[0];
    
    return {
      eventType: eventType,
      action: 'daily_summary',
      amount: amount,
      machineId: gamingMachineId,
      gamingMachineId: gamingMachineId,
      timestamp: timestamp,
      idempotencyKey: `daily_${eventType}_${gamingMachineId}_${reportDate}`,
      rawData: `Daily Summary ${eventType === 'money_in' ? 'In' : 'Out'} - Machine ${machineNumber} - $${amount}`,
      metadata: {
        source: 'daily_report',
        reportDate: reportDate
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
    logger.info('Parser state reset');
  }
}

module.exports = DataParser;