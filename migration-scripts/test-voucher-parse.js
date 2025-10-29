const fs = require('fs');

// Read the raw log and reconstruct the voucher
const rawLog = fs.readFileSync('./data/serial-logs/raw-2025-10-14.jsonl', 'utf8');
const lines = rawLog.split('\n').filter(line => line.trim());

// Find the voucher session (23:21:10)
const voucherLines = lines.filter(line => {
  const data = JSON.parse(line);
  return data.timestamp >= '2025-10-14T23:21:10.600Z' && 
         data.timestamp <= '2025-10-14T23:21:11.120Z';
});

// Reconstruct the full buffer
const bufferParts = voucherLines.map(line => {
  const data = JSON.parse(line);
  return Buffer.from(data.hex, 'hex');
});

const fullBuffer = Buffer.concat(bufferParts);
const text = fullBuffer.toString('ascii');

console.log('=== FULL VOUCHER BUFFER ===');
console.log(text);
console.log('\n=== HEX DUMP ===');
console.log(fullBuffer.toString('hex'));
console.log('\n=== TESTING REGEX PATTERNS ===');

// Test machine number pattern
const machineMatch = text.match(/MACHINE\s+NUMBER[\s\r\n]+(\d+)/i);
console.log('Machine match:', machineMatch);

// Test amount pattern
const amountMatch = text.match(/\$(\d+\.\d{2})/);
console.log('Amount match:', amountMatch);

// Test voucher number
const voucherMatch = text.match(/Voucher\s*#\s*(\d+)/i);
console.log('Voucher match:', voucherMatch);
