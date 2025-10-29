// debug-serial-reader.js
// Place in /home/gambino/gambino-pi-app/debug-serial-reader.js
// Run with: node debug-serial-reader.js

const { SerialPort } = require('serialport');
const { ReadlineParser } = require('@serialport/parser-readline');

console.log('🔍 Debug Serial Reader - Capturing ALL data from Mutha Goose');
console.log('Press Daily Report button on the Mutha Goose...\n');

const port = new SerialPort({
  path: '/dev/ttyUSB0',
  baudRate: 9600,
  dataBits: 8,
  stopBits: 1,
  parity: 'none'
});

const parser = port.pipe(new ReadlineParser({ delimiter: '\r\n' }));

let lineCount = 0;

parser.on('data', (data) => {
  lineCount++;
  const trimmed = data.toString().trim();
  const byteLength = Buffer.byteLength(data, 'utf8');
  
  console.log(`\n[Line ${lineCount}] (${byteLength} bytes)`);
  console.log(`Raw: "${data}"`);
  console.log(`Trimmed: "${trimmed}"`);
  
  // Show hex dump for debugging
  const hex = Buffer.from(data, 'utf8').toString('hex');
  console.log(`Hex: ${hex}`);
  
  // Check for specific patterns
  if (trimmed.match(/^MACHINE\s+\d+$/i)) {
    console.log('✅ MATCHED: Machine header');
  } else if (trimmed.match(/^Out\s+==\s+\d+$/i)) {
    console.log('✅ MATCHED: Out line');
  } else if (trimmed.match(/^Daily\s+In\s+==\s+\d+\.\d{2}$/i)) {
    console.log('✅ MATCHED: Daily In line');
  }
});

port.on('error', (err) => {
  console.error('Serial port error:', err);
});

console.log('Listening for data... (Press Ctrl+C to exit)\n');
