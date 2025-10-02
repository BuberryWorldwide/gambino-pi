// src/serial/dataParser.js
const logger = require('../utils/logger');

class DataParser {
  constructor() {
    // State tracking for multi-line voucher parsing
    this.currentVoucher = null;
    this.voucherBuffer = [];
    
    // State tracking for daily summary parsing
    this.currentDailySummary = null;
    this.dailySummaryBuffer = [];
    
    // Single-line patterns (legacy support)
    this.patterns = {
      // NEW: Richmond Hot Streak format (single line with plays/points)
      voucherRichmond: /Voucher\s*#(\d+)\s*-\s*(\d+)\s+plays?\s*-\s*(\d+)\s+points?\s*-\s*Machine\s+(\d+)/i,
      dailySummary: /Daily\s+Summary\s*-\s*Machine\s+(\d+)\s*-\s*\$(\d+)\s+in/i,
      
      // Legacy patterns
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
      
      logger.info(`🔍 [PARSE] line: "${trimmedData}" | voucher state: ${this.currentVoucher ? 'EXISTS' : 'NULL'}`);

      // Try multi-line voucher parsing first
      const voucherEvent = this.parseVoucherLine(trimmedData, timestamp);
      
      logger.info(`  → parseVoucherLine returned: ${voucherEvent ? 'EVENT' : 'null'} | voucher state after: ${this.currentVoucher ? 'EXISTS' : 'NULL'}`);
      
      if (voucherEvent) {
        return voucherEvent;
      }

      // Try daily summary parsing
      const summaryEvent = this.parseDailySummaryLine(trimmedData, timestamp);
      if (summaryEvent) {
        return summaryEvent;
      }
      
      // If we're currently building a voucher, don't check other patterns
      if (this.currentVoucher) {
        return null;
      }

      // Ignore header/boot messages from Mutha Goose (only if NOT building voucher)
      if (this.isHeaderMessage(trimmedData)) {
        logger.debug('Skipping header/boot message');
        return null;
      }

      // Try single-line patterns (legacy format)
      for (const [eventType, pattern] of Object.entries(this.patterns)) {
        const match = trimmedData.match(pattern);
        if (match) {
          return this.buildEventFromPattern(eventType, match, trimmedData, timestamp);
        }
      }

      // No match found
      logger.warn(`⚠️ Unrecognized data format: "${trimmedData}"`);
      return null;

    } catch (error) {
      logger.error('Parse error:', error);
      return null;
    }
  }

  parseVoucherLine(line, timestamp) {
    // State machine for multi-line voucher parsing
    
    logger.info(`[VOUCHER STATE] currentVoucher: ${this.currentVoucher ? 'EXISTS' : 'NULL'}, line: "${line}"`);
    
    // Start of voucher: "MACHINE NUMBER"
    if (/MACHINE\s+NUMBER/i.test(line)) {
      this.voucherBuffer = [];
      this.currentVoucher = { timestamp };
      logger.info('📋 Starting new voucher parse');
      return null;
    }

    // Machine number line (just digits, may have spaces)
    if (this.currentVoucher && !this.currentVoucher.machineNumber) {
      // Debug: show the exact bytes/characters
      const bytes = Array.from(line).map(c => c.charCodeAt(0));
      logger.info(`Checking if machine number: "${line}" | bytes: [${bytes.join(', ')}] | test result: ${/^\s*\d+\s*$/.test(line)}`);
      
      // More flexible: extract any digits from the line
      const digitMatch = line.match(/(\d+)/);
      if (digitMatch) {
        this.currentVoucher.machineNumber = digitMatch[1];
        logger.info(`🎰 Machine number: ${this.currentVoucher.machineNumber}`);
        return null;
      }
    }

    // Voucher number
    if (this.currentVoucher && /Voucher\s*#\s*(\d+)/i.test(line)) {
      const match = line.match(/Voucher\s*#\s*(\d+)/i);
      this.currentVoucher.voucherNumber = match[1];
      logger.info(`🎫 Voucher #: ${this.currentVoucher.voucherNumber}`);
      return null;
    }

    // Plays collected line
    if (this.currentVoucher && /(\d+)\s+plays?\s+collected/i.test(line)) {
      const match = line.match(/(\d+)\s+plays?\s+collected/i);
      this.currentVoucher.plays = parseInt(match[1]);
      logger.info(`🎮 Plays: ${this.currentVoucher.plays}`);
      return null;
    }

    // Points value
    if (this.currentVoucher && /(\d+)\s+POINTS?/i.test(line)) {
      const match = line.match(/(\d+)\s+POINTS?/i);
      this.currentVoucher.points = parseInt(match[1]);
      logger.info(`💰 Points: ${this.currentVoucher.points}`);
      return null;
    }

    // Confidence number (end of voucher)
    if (this.currentVoucher && /Confidence\s+Number\s*:\s*(.+)/i.test(line)) {
      const match = line.match(/Confidence\s+Number\s*:\s*(.+)/i);
      this.currentVoucher.confidenceNumber = match[1].trim();
      logger.info(`🔐 Confidence #: ${this.currentVoucher.confidenceNumber}`);
      
      // Check if we have all required fields
      if (!this.currentVoucher.machineNumber) {
        logger.error('❌ Voucher missing machine number!');
        this.currentVoucher = null;
        return null;
      }
      
      // Voucher is complete - build event
      const event = this.buildVoucherEvent(this.currentVoucher);
      this.currentVoucher = null;
      this.voucherBuffer = [];
      
      return event;
    }

    // Collect buffer
    if (this.currentVoucher) {
      this.voucherBuffer.push(line);
    }

    return null;
  }

  parseDailySummaryLine(line, timestamp) {
    // Parse daily summary reports from Mutha Goose
    // Format: <MACHINE_NUMBER> followed by "Daily In == AMOUNT"
    
    // Detect start of machine summary: <35>, <36>, etc.
    const machineMatch = line.match(/<(\d+)>/);
  if (machineMatch) {
    this.currentDailySummary = {
      machineNumber: machineMatch[1],
      timestamp
    };
    logger.info(`📊 Starting daily summary for machine ${this.currentDailySummary.machineNumber}`);
    
    // Check if "Daily In" is on the same line (after newline)
    const sameLine = line.match(/Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (sameLine) {
      this.currentDailySummary.amount = parseFloat(sameLine[1]);
      logger.info(`💵 Daily In amount (same line): $${this.currentDailySummary.amount} for machine ${this.currentDailySummary.machineNumber}`);
      
      const event = this.buildDailySummaryEvent(this.currentDailySummary);
      this.currentDailySummary = null;
      return event;
    }
    
    return null;
  }

  // If we're tracking a summary, look for "Daily In" on next line
  if (this.currentDailySummary && !this.currentDailySummary.amount) {
    const dailyInMatch = line.match(/Daily\s+In\s+==\s+(\d+\.\d{2})/i);
    if (dailyInMatch) {
      this.currentDailySummary.amount = parseFloat(dailyInMatch[1]);
      logger.info(`💵 Daily In amount: $${this.currentDailySummary.amount} for machine ${this.currentDailySummary.machineNumber}`);
      
      const event = this.buildDailySummaryEvent(this.currentDailySummary);
      this.currentDailySummary = null;
      return event;
    }
  }

  return null;
}

  buildVoucherEvent(voucher) {
    const machineNumber = voucher.machineNumber;
    const gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
    
    // Convert points to dollar amount (assuming 1 point = $1, adjust if needed)
    const amount = voucher.points || 0;
    
    logger.info(`✅ Voucher parsed: Machine ${machineNumber}, ${voucher.plays} play(s), ${voucher.points} points`);
    
    return {
      eventType: 'voucher_print',
      action: 'print',
      amount: amount,
      machineId: gamingMachineId,
      gamingMachineId,
      voucherNumber: voucher.voucherNumber,
      plays: voucher.plays,
      points: voucher.points,
      confidenceNumber: voucher.confidenceNumber,
      timestamp: voucher.timestamp,
      rawData: `Voucher #${voucher.voucherNumber} - ${voucher.plays} plays - ${voucher.points} points - Machine ${machineNumber}`
    };
  }

  buildDailySummaryEvent(summary) {
  const machineNumber = summary.machineNumber;
  const gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
  const amount = summary.amount;
  const reportDate = new Date(summary.timestamp).toISOString().split('T')[0];
  
  // ⭐ Generate idempotency key: storeId will be added by backend
  const idempotencyKey = `daily_${gamingMachineId}_${reportDate}`;
  
  logger.info(`✅ Daily summary parsed: Machine ${machineNumber}, $${amount} in`);
  
  return {
    eventType: 'money_in',
    action: 'daily_summary',
    amount: amount,
    machineId: gamingMachineId,
    gamingMachineId,
    timestamp: summary.timestamp,
    idempotencyKey: idempotencyKey,  // ⭐ Add this
    rawData: `Daily Summary - Machine ${machineNumber} - $${amount} in`,
    metadata: {
      source: 'daily_report',
      reportDate: reportDate
    }
  };
}

  buildEventFromPattern(eventType, match, trimmedData, timestamp) {
    let machineNumber, amount, gamingMachineId;
    
    // Handle Richmond voucher format: Voucher #16310 - 10 plays - 10 points - Machine 35
    if (eventType === 'voucherRichmond') {
      const voucherNum = match[1];
      const plays = match[2];
      const points = match[3];
      machineNumber = match[4];
      gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
      
      logger.info(`✅ Richmond voucher: #${voucherNum}, ${plays} plays, ${points} points, Machine ${machineNumber}`);
      
      return {
        eventType: 'voucher_print',
        action: 'print',
        amount: parseInt(points),
        machineId: gamingMachineId,
        gamingMachineId,
        voucherNumber: voucherNum,
        plays: parseInt(plays),
        points: parseInt(points),
        timestamp,
        rawData: trimmedData
      };
    }
    
    // Handle Daily Summary format: Daily Summary - Machine 35 - $30 in
    if (eventType === 'dailySummary') {
      machineNumber = match[1];
      amount = match[2];
      gamingMachineId = `machine_${machineNumber.padStart(2, '0')}`;
      const reportDate = new Date(timestamp).toISOString().split('T')[0];
      
      logger.info(`✅ Daily summary: Machine ${machineNumber}, $${amount} in`);
      
      return {
        eventType: 'money_in',
        action: 'daily_summary',
        amount: parseInt(amount),
        machineId: gamingMachineId,
        gamingMachineId,
        timestamp,
        idempotencyKey: `daily_${gamingMachineId}_${reportDate}`,
        rawData: trimmedData,
        metadata: {
          source: 'daily_report',
          reportDate
        }
      };
    }
    
    
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
        eventType: eventType === 'moneyIn' ? 'money_in' : 
                   eventType === 'voucher' ? 'voucher_print' : 
                   'collect',
        action: eventType === 'moneyIn' ? 'cash_in' : 
               eventType === 'voucher' ? 'print' : 
               'collect',
        amount: parseFloat(amount),
        machineId: gamingMachineId,
        gamingMachineId,
        timestamp,
        rawData: trimmedData
      };
    }
  }

  generateSessionId(machineNumber) {
    return `session_${machineNumber}_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  }

  isHeaderMessage(data) {
    // Ignore Mutha Goose boot/header/voucher formatting messages
    const headerPatterns = [
      /SERIAL\s*#/i,
      /^V\d+\.\d+/i,  // Version strings
      /DATE\s*:/i,
      /TIME\s*:/i,
      /^\s*$/,  // Empty lines
      /^_{20,}$/,  // Underscores (separator lines)
      /This voucher is good for/i,
      /Redeemable at this location/i
    ];
    
    return headerPatterns.some(pattern => pattern.test(data));
  }
}

module.exports = DataParser;