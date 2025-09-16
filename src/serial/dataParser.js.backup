const logger = require('../utils/logger');

class DataParser {
  constructor() {
    // Patterns for Mutha Goose printer output based on your mock data
    this.patterns = {
      voucher: /VOUCHER PRINT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s*(\d+)/i,
      moneyIn: /MONEY IN:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s*(\d+)/i,
      collect: /COLLECT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s*(\d+)/i,
      sessionStart: /SESSION START\s*-\s*MACHINE\s*(\d+)/i,
      sessionEnd: /SESSION END\s*-\s*MACHINE\s*(\d+)/i
    };
  }

  parse(rawData) {
    try {
      const timestamp = new Date().toISOString();
      const trimmedData = rawData.trim();
      
      logger.debug(`🔍 Parsing: ${trimmedData}`);

      // Extract machine number for all event types
      const machineMatch = trimmedData.match(/MACHINE\s*(\d+)/i);
      const machineNumber = machineMatch ? machineMatch[1] : '00';
      const gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;

      // Check for voucher events
      const voucherMatch = trimmedData.match(this.patterns.voucher);
      if (voucherMatch) {
        return {
          eventType: 'voucher',
          amount: voucherMatch[1],
          machineId: gamingMachineId,
          gamingMachineId,
          timestamp,
          rawData: trimmedData
        };
      }

      // Check for money in events  
      const moneyInMatch = trimmedData.match(this.patterns.moneyIn);
      if (moneyInMatch) {
        return {
          eventType: 'money_in',
          amount: moneyInMatch[1],
          machineId: gamingMachineId,
          gamingMachineId,
          timestamp,
          rawData: trimmedData
        };
      }

      // Check for collect events
      const collectMatch = trimmedData.match(this.patterns.collect);
      if (collectMatch) {
        return {
          eventType: 'collect',
          amount: collectMatch[1],
          machineId: gamingMachineId,
          gamingMachineId,
          timestamp,
          rawData: trimmedData
        };
      }

      // Check for session start
      const sessionStartMatch = trimmedData.match(this.patterns.sessionStart);
      if (sessionStartMatch) {
        return {
          eventType: 'session_start',
          action: 'start',
          sessionId: this.generateSessionId(sessionStartMatch[1]),
          machineId: gamingMachineId,
          gamingMachineId,
          timestamp,
          rawData: trimmedData
        };
      }

      // Check for session end
      const sessionEndMatch = trimmedData.match(this.patterns.sessionEnd);
      if (sessionEndMatch) {
        return {
          eventType: 'session_end',
          action: 'end', 
          sessionId: this.generateSessionId(sessionEndMatch[1]),
          machineId: gamingMachineId,
          gamingMachineId,
          timestamp,
          rawData: trimmedData
        };
      }

      // If no patterns match, log for analysis
      logger.debug(`🔍 Unrecognized data pattern: ${trimmedData}`);
      return null;

    } catch (error) {
      logger.error('Error parsing data:', error);
      return null;
    }
  }

  generateSessionId(machineNumber) {
    return `session_${machineNumber}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Method to add new parsing patterns for different Mutha Goose formats
  addPattern(name, regex) {
    this.patterns[name] = regex;
    logger.info(`Added new parsing pattern: ${name}`);
  }

  // Extract machine ID from any raw data string
  extractMachineId(rawData) {
    const machineMatch = rawData.match(/MACHINE\s*(\d+)/i);
    return machineMatch ? `machine_${machineMatch[1].padStart(2, '0')}` : null;
  }

  // Validate parsed event data
  validateEvent(event) {
    if (!event) return false;
    
    const requiredFields = ['eventType', 'timestamp', 'rawData'];
    const hasRequired = requiredFields.every(field => event[field]);
    
    if (!hasRequired) {
      logger.warn('Event missing required fields:', event);
      return false;
    }

    // Validate amount for monetary events
    if (['voucher', 'money_in', 'collect'].includes(event.eventType)) {
      if (!event.amount || isNaN(parseFloat(event.amount))) {
        logger.warn('Monetary event missing valid amount:', event);
        return false;
      }
    }

    return true;
  }
}

module.exports = DataParser;