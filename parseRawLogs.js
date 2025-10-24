const fs = require('fs');
const readline = require('readline');

class MothaGooseRawLogParser {
  constructor() {
    this.buffer = '';
    this.events = [];
  }

  // Parse a single JSONL log entry
  parseLogEntry(jsonLine) {
    try {
      const entry = JSON.parse(jsonLine);
      // Convert hex to ASCII for easier parsing
      const text = Buffer.from(entry.hex, 'hex').toString('ascii');
      this.buffer += text;
      
      // Check if we have a complete message (ends with ESC P or multiple newlines)
      if (this.buffer.includes('\x1bP') || this.buffer.match(/\r\n\r\n\r\n/)) {
        const event = this.parseBuffer(this.buffer, entry.timestamp);
        if (event) {
          this.events.push(event);
        }
        this.buffer = ''; // Reset buffer after parsing
      }
    } catch (err) {
      console.error('Error parsing log entry:', err.message);
    }
  }

  // Parse the accumulated buffer for specific report types
  parseBuffer(text, timestamp) {
    // Clean up text for parsing
    const cleanText = text.replace(/[\x00-\x1F\x7F-\x9F]/g, (char) => {
      return char === '\r' || char === '\n' ? char : ' ';
    });

    // Try to detect what type of report this is
    if (cleanText.includes('Unit Daily')) {
      return this.parseUnitDaily(cleanText, timestamp);
    } else if (cleanText.includes('VOUCHER') || cleanText.includes('Confidence Number')) {
      return this.parseVoucher(cleanText, timestamp);
    }

    return null;
  }

  // Parse Unit Daily Report
  parseUnitDaily(text, timestamp) {
    const event = {
      type: 'unit_daily',
      timestamp: timestamp,
      raw: text
    };

    // Extract machine number if present
    const machineMatch = text.match(/MACHINE\s+(?:NUMBER\s+)?(\d+)/i) ||
                         text.match(/MACHINE[:\s]+(\d+)/i);
    if (machineMatch) {
      event.machineNumber = parseInt(machineMatch[1]);
    }

    // Extract Serial Number from daily report
    const serialMatch = text.match(/SERIAL\s+#?\s*([\w-]+)/i);
    if (serialMatch) {
      event.serialNumber = serialMatch[1].trim();
    }

    // Extract Date
    const dateMatch = text.match(/DATE\s*:?\s*([\d-]+)/i);
    if (dateMatch) {
      event.date = dateMatch[1].trim();
    }

    // Extract Time
    const timeMatch = text.match(/TIME\s*:?\s*([\d:APM\s]+)/i);
    if (timeMatch) {
      event.time = timeMatch[1].trim();
    }

    // Extract Daily Out
    const outMatch = text.match(/Daily\s+Out\s+==\s+([\d,.]+)/i);
    if (outMatch) {
      event.dailyOut = parseFloat(outMatch[1].replace(/,/g, ''));
    }

    // Extract Daily In (look for the FIRST occurrence to get machine 1's data)
    const inMatch = text.match(/Daily\s+In\s+==\s+([\d,.]+)/i);
    if (inMatch) {
      event.dailyIn = parseFloat(inMatch[1].replace(/,/g, ''));
    }

    // Extract Daily Total Paid (first occurrence)
    const paidMatch = text.match(/Daily\s+Total\s+Paid\s+==\s+([\d,.]+)/i);
    if (paidMatch) {
      event.totalPaid = parseFloat(paidMatch[1].replace(/,/g, ''));
    }

    // Extract individual machine data
    event.machines = this.extractMachineData(text);

    return event;
  }

  // Extract individual machine data from daily report
  extractMachineData(text) {
    const machines = [];
    const machinePattern = /<\s*(\d+)\s*>[\s\S]*?Daily\s+In\s+==\s+([\d,.]+)[\s\S]*?Daily\s+Total\s+Paid\s+==\s+([\d,.]+)/gi;
    
    let match;
    while ((match = machinePattern.exec(text)) !== null) {
      machines.push({
        machineNumber: parseInt(match[1]),
        dailyIn: parseFloat(match[2].replace(/,/g, '')),
        totalPaid: parseFloat(match[3].replace(/,/g, ''))
      });
    }
    
    return machines.length > 0 ? machines : null;
  }

  // Parse Voucher
  parseVoucher(text, timestamp) {
    const event = {
      type: 'voucher',
      timestamp: timestamp,
      raw: text
    };

    // Extract Machine Number (more flexible patterns)
    const machineMatch = text.match(/MACHINE\s+(?:NUMBER\s+)?(\d+)/i) ||
                         text.match(/MACHINE[:\s]+(\d+)/i);
    if (machineMatch) {
      event.machineNumber = parseInt(machineMatch[1]);
    }

    // Extract Serial Number (more flexible)
    const serialMatch = text.match(/SERIAL\s+#?\s*([\w-]+)/i);
    if (serialMatch) {
      event.serialNumber = serialMatch[1].trim();
    }

    // Extract Voucher Number (more flexible)
    const voucherMatch = text.match(/Voucher\s+#?\s*(\d+)/i);
    if (voucherMatch) {
      event.voucherNumber = parseInt(voucherMatch[1]);
    }

    // Extract Amount (look for "good for" or just $)
    const amountMatch = text.match(/good\s+for\s*:?\s*\$?\s*([\d,.]+)/i) ||
                        text.match(/\$\s*([\d,.]+)/);
    if (amountMatch) {
      event.amount = parseFloat(amountMatch[1].replace(/,/g, ''));
    }

    // Extract Confidence Number
    const confidenceMatch = text.match(/Confidence\s+Number\s*:?\s*([\d-]+)/i);
    if (confidenceMatch) {
      event.confidenceNumber = confidenceMatch[1].trim();
    }

    // Extract Date
    const dateMatch = text.match(/DATE\s*:?\s*([\d-]+)/i);
    if (dateMatch) {
      event.date = dateMatch[1].trim();
    }

    // Extract Time
    const timeMatch = text.match(/TIME\s*:?\s*([\d:APM\s]+)/i);
    if (timeMatch) {
      event.time = timeMatch[1].trim();
    }

    // Extract plays collected (handle various formats)
    const playsMatch = text.match(/(\d+)\s+plays?\s+collected/i);
    if (playsMatch) {
      event.playsCollected = parseInt(playsMatch[1]);
    }

    return event;
  }

  // Process an entire log file
  async processLogFile(filename) {
    const fileStream = fs.createReadStream(filename);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    for await (const line of rl) {
      if (line.trim()) {
        this.parseLogEntry(line);
      }
    }

    return this.events;
  }
}

// Example usage:
async function main() {
  const parser = new MothaGooseRawLogParser();
  
  // Parse the log file
  const logFile = process.argv[2] || './data/serial-logs/raw-2025-10-17.jsonl';
  
  console.log(`📖 Parsing log file: ${logFile}\n`);
  
  const events = await parser.processLogFile(logFile);
  
  console.log(`✅ Found ${events.length} events:\n`);
  
  // Display parsed events
  events.forEach((event, index) => {
    console.log(`\n━━━ Event ${index + 1}: ${event.type.toUpperCase()} ━━━`);
    
    if (event.type === 'unit_daily') {
      console.log(`Serial: ${event.serialNumber || 'N/A'}`);
      console.log(`Date/Time: ${event.date || 'N/A'} ${event.time || ''}`);
      console.log(`Daily Out: $${event.dailyOut?.toFixed(2) || 'N/A'}`);
      console.log(`Daily In: $${event.dailyIn?.toFixed(2) || 'N/A'}`);
      console.log(`Total Paid: $${event.totalPaid?.toFixed(2) || 'N/A'}`);
      
      if (event.machines && event.machines.length > 0) {
        console.log(`\n  Individual Machines (${event.machines.length}):`);
        event.machines.forEach(m => {
          console.log(`    Machine ${m.machineNumber}: In=$${m.dailyIn.toFixed(2)}, Paid=$${m.totalPaid.toFixed(2)}`);
        });
      }
    } else if (event.type === 'voucher') {
      console.log(`Machine: #${event.machineNumber || 'N/A'}`);
      console.log(`Serial: ${event.serialNumber || 'N/A'}`);
      console.log(`Voucher #: ${event.voucherNumber || 'N/A'}`);
      console.log(`Amount: $${event.amount?.toFixed(2) || 'N/A'}`);
      console.log(`Confidence #: ${event.confidenceNumber || 'N/A'}`);
      console.log(`Date/Time: ${event.date || 'N/A'} ${event.time || ''}`);
      console.log(`Plays: ${event.playsCollected || 'N/A'}`);
    }
    
    console.log(`Timestamp: ${event.timestamp}`);
  });
  
  // Calculate totals
  const voucherTotal = events
    .filter(e => e.type === 'voucher')
    .reduce((sum, e) => sum + (e.amount || 0), 0);
  
  const voucherCount = events.filter(e => e.type === 'voucher').length;
  const dailyReportCount = events.filter(e => e.type === 'unit_daily').length;

  console.log('\n\n' + '═'.repeat(60));
  console.log('📊 SUMMARY');
  console.log('═'.repeat(60));
  console.log(`Total Vouchers: ${voucherCount} = $${voucherTotal.toFixed(2)}`);
  console.log(`Total Daily Reports: ${dailyReportCount}`);
  console.log('═'.repeat(60));
  
  // Output JSON for database import
  console.log('\n\n📦 JSON Output (for DB import):');
  console.log(JSON.stringify(events, null, 2));
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = MothaGooseRawLogParser;