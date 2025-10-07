// src/serial/dataParser.js
const logger = require('../utils/logger');

class DataParser {
  constructor() {
    // Existing patterns for single-line events
    this.patterns = {
      voucher: /VOUCHER PRINT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      moneyIn: /MONEY IN:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      collect: /COLLECT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      sessionStart: /SESSION START\s*-\s*MACHINE\s+(\d+)/i,
      sessionEnd: /SESSION END\s*-\s*MACHINE\s+(\d+)/i
    };
    
    // State machine for daily report parsing
    this.currentDailyMachine = null;  // Stores machine number from <29> line
    this.lastMachineNumber = null;
  }

  parse(rawData) {
    try {
      const timestamp = new Date().toISOString();
      const trimmedData = rawData.trim();
      
      // Skip empty lines and decorative separator lines
      if (!trimmedData || 
          trimmedData.match(/^[\*_\-]+$/) || 
          trimmedData.match(/^Daily (Books|of|REMOTE|MATCH|Total)/i) ||
          trimmedData.match(/^(DATE|SERIAL|Last Cleared|Dailies|Unit Daily)/i) ||
          trimmedData.match(/^This voucher/i) ||
          trimmedData.match(/by this base unit/i)) {
        return null;
      }
      
      logger.info(`🔍 [PARSE] line: "${trimmedData.substring(0, 60)}..." | last machine: ${this.lastMachineNumber || 'NULL'}`);

      // Try to parse daily summary line
      const dailyEvent = this.parseDailySummaryLine(trimmedData);
      if (dailyEvent) {
        return dailyEvent;
      }

      // Check single-line patterns
      for (const [eventType, pattern] of Object.entries(this.patterns)) {
        const match = trimmedData.match(pattern);
        if (match) {
          let machineNumber, amount, gamingMachineId;
          
          if (eventType === 'sessionStart' || eventType === 'sessionEnd') {
            machineNumber = match[1];
            gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
            
            logger.debug(`🎯 Matched ${eventType}: machine ${machineNumber} -> ${gamingMachineId}`);
            
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
            
            logger.debug(`🎯 Matched ${eventType}: $${amount} from machine ${machineNumber} -> ${gamingMachineId}`);
            
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

      // If no patterns match, log for debugging
      logger.warn(`⚠️ Unrecognized data format: "${trimmedData.substring(0, 60)}"`);
      
      return null;

    } catch (error) {
      logger.error('Error parsing data:', error);
      logger.error('Raw data that caused error:', rawData);
      return null;
    }
  }

  parseDailySummaryLine(line) {
    // Strip control characters that prevent pattern matching
    const cleanLine = line.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim();
    
    // Pattern 1: Machine number line in angle brackets: "<29>"
    const machineMatch = cleanLine.match(/^<(\d+)>$/);
    if (machineMatch) {
      const machineNumber = machineMatch[1];
      logger.info(`📊 Captured machine number: ${machineNumber}`);
      this.currentDailyMachine = machineNumber;
      this.lastMachineNumber = machineNumber;
      return null; // Wait for the Daily In line
    }

    // Pattern 2: Combined format (in case readline doesn't split it)
    // Format: "<29>\n Daily In             ==         0.00"
    const combinedMatch = line.match(/<(\d+)>[\s\n]+Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (combinedMatch) {
      const machineNumber = combinedMatch[1];
      const amount = parseFloat(combinedMatch[2]);
      
      logger.info(`📊 Daily summary (combined): Machine ${machineNumber}, ${amount} in`);
      
      const event = this.buildDailySummaryEvent(machineNumber, amount, new Date().toISOString());
      this.lastMachineNumber = machineNumber;
      this.currentDailyMachine = null;
      
      logger.info(`✅ Daily summary parsed: Machine ${event.machineId}, ${amount} in`);
      return event;
    }

    // Pattern 3: Daily In line (should have machine number from previous line)
    // Format: " Daily  In            ==         0.00"
    const dailyInMatch = line.match(/^Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (dailyInMatch) {
      const amount = parseFloat(dailyInMatch[1]);
      
      // Use the machine number we captured from the previous <29> line
      if (this.currentDailyMachine) {
        logger.info(`💵 Daily In: ${amount} for machine ${this.currentDailyMachine}`);
        
        const event = this.buildDailySummaryEvent(
          this.currentDailyMachine,
          amount,
          new Date().toISOString()
        );
        
        this.currentDailyMachine = null; // Reset for next machine
        
        logger.info(`✅ Daily summary parsed: Machine ${event.machineId}, ${amount} in`);
        return event;
      }
      // Fallback: if no stored machine, try to infer from last machine
      else if (this.lastMachineNumber) {
        const nextMachine = (parseInt(this.lastMachineNumber) + 1).toString();
        logger.info(`💵 Daily In: ${amount} for inferred machine ${nextMachine}`);
        
        const event = this.buildDailySummaryEvent(nextMachine, amount, new Date().toISOString());
        this.lastMachineNumber = nextMachine;
        
        logger.info(`✅ Daily summary parsed (inferred): Machine ${event.machineId}, ${amount} in`);
        return event;
      }
      // Last resort: start at machine 29
      else {
        logger.info(`💵 Daily In: ${amount} for machine 29 (bootstrap)`);
        
        const event = this.buildDailySummaryEvent('29', amount, new Date().toISOString());
        this.lastMachineNumber = '29';
        
        logger.info(`✅ Daily summary parsed: Machine ${event.machineId}, ${amount} in`);
        return event;
      }
    }

    // Pattern 4: Standalone "Out" line (for unit totals at the end)
    // Format: " Out                  ==         0"
    const outMatch = line.match(/^Out\s+==\s+\d+/i);
    if (outMatch) {
      logger.info(`📊 Unit total Out line detected`);
      return null; // We skip this - it's the final unit total
    }

    return null;
  }

  buildDailySummaryEvent(machineNumber, amount, timestamp) {
    const gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
    const reportDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    
    return {
      eventType: 'money_in',
      action: 'daily_summary',
      amount: amount,
      machineId: gamingMachineId,
      gamingMachineId: gamingMachineId,
      timestamp: timestamp,
      idempotencyKey: `daily_${gamingMachineId}_${reportDate}`,
      rawData: `Daily Summary - Machine ${machineNumber} - $${amount} in`,
      metadata: {
        source: 'daily_report',
        reportDate: reportDate
      }
    };
  }

  generateSessionId(machineNumber) {
    return `session_${machineNumber}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  extractMachineId(rawData) {
    const machineMatch = rawData.match(/MACHINE\s+(\d+)/i);
    if (machineMatch) {
      const machineNumber = machineMatch[1].padStart(2, '0');
      return `machine_${machineNumber}`;
    }
    return null;
  }

  validateEvent(event) {
    if (!event) return false;
    
    const requiredFields = ['eventType', 'timestamp', 'rawData', 'machineId'];
    const hasRequired = requiredFields.every(field => event[field]);
    
    if (!hasRequired) {
      logger.warn('Event missing required fields:', event);
      return false;
    }

    // Validate amount for monetary events
    if (['voucher', 'money_in', 'collect'].includes(event.eventType)) {
      if (event.amount === undefined || isNaN(parseFloat(event.amount))) {
        logger.warn('Monetary event missing valid amount:', event);
        return false;
      }
    }

    return true;
  }

  // Reset state (useful for testing or error recovery)
  resetState() {
    this.currentDailyMachine = null;
    this.lastMachineNumber = null;
    logger.info('Parser state reset');
  }
}

module.exports = DataParser;