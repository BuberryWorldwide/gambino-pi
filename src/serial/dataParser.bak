// src/serial/dataParser.js
const logger = require('../utils/logger');

class DataParser {
  constructor() {
    // Fixed patterns to match your exact mock data format
    this.patterns = {
      voucher: /VOUCHER PRINT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      moneyIn: /MONEY IN:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      collect: /COLLECT:\s*\$(\d+\.\d{2})\s*-\s*MACHINE\s+(\d+)/i,
      sessionStart: /SESSION START\s*-\s*MACHINE\s+(\d+)/i,
      sessionEnd: /SESSION END\s*-\s*MACHINE\s+(\d+)/i
    };
  }

  parse(rawData) {
    try {
      const timestamp = new Date().toISOString();
      const trimmedData = rawData.trim();
      
      logger.debug(`🔍 Parsing raw data: "${trimmedData}"`);

      // Check each pattern type
      for (const [eventType, pattern] of Object.entries(this.patterns)) {
        const match = trimmedData.match(pattern);
        if (match) {
          let machineNumber, amount, gamingMachineId;
          
          if (eventType === 'sessionStart' || eventType === 'sessionEnd') {
            // Session events: match[1] is machine number
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
            // Money events: match[1] is amount, match[2] is machine number
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

      // If no patterns match, log the data for debugging
      logger.warn(`🚫 No pattern matched for: "${trimmedData}"`);
      logger.debug('Available patterns:', Object.keys(this.patterns));
      
      return null;

    } catch (error) {
      logger.error('Error parsing data:', error);
      logger.error('Raw data that caused error:', rawData);
      return null;
    }
  }

  generateSessionId(machineNumber) {
    return `session_${machineNumber}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Extract machine ID from any raw data string (fallback method)
  extractMachineId(rawData) {
    const machineMatch = rawData.match(/MACHINE\s+(\d+)/i);
    if (machineMatch) {
      const machineNumber = machineMatch[1].padStart(2, '0');
      return `machine_${machineNumber}`;
    }
    return null;
  }

  // Validate parsed event data
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
      if (!event.amount || isNaN(parseFloat(event.amount))) {
        logger.warn('Monetary event missing valid amount:', event);
        return false;
      }
    }

    return true;
  }
}

module.exports = DataParser;