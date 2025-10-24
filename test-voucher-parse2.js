const fs = require('fs');

const rawLog = fs.readFileSync('./data/serial-logs/raw-2025-10-14.jsonl', 'utf8');
const lines = rawLog.split('\n').filter(line => line.trim());

const voucherLines = lines.filter(line => {
  const data = JSON.parse(line);
  return data.timestamp >= '2025-10-14T23:21:10.600Z' && 
         data.timestamp <= '2025-10-14T23:21:11.120Z';
});

const bufferParts = voucherLines.map(line => {
  const data = JSON.parse(line);
  return Buffer.from(data.hex, 'hex');
});

const fullBuffer = Buffer.concat(bufferParts);
const text = fullBuffer.toString('ascii');

console.log('=== RAW HEX around machine number ===');
const machineSection = text.substring(text.indexOf('MACHINE'), text.indexOf('MACHINE') + 50);
console.log('Text:', JSON.stringify(machineSection));
console.log('Hex:', Buffer.from(machineSection).toString('hex'));

console.log('\n=== TESTING PATTERNS ===');
const machineMatch = text.match(/MACHINE\s+NUMBER[\s\r\n]+(\d+)/i);
console.log('Machine pattern result:', machineMatch ? `MATCHED: ${machineMatch[1]}` : 'NO MATCH');

const amountMatch = text.match(/\$(\d+\.\d{2})/);
console.log('Amount pattern result:', amountMatch ? `MATCHED: $${amountMatch[1]}` : 'NO MATCH');
