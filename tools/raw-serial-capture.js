// raw-serial-capture.js
// Purpose: Capture EVERY byte from Mutha Goose without any parsing/filtering
// Place in: ~/gambino-pi-app/tools/raw-serial-capture.js
// Run: node tools/raw-serial-capture.js

const { SerialPort } = require('serialport');
const fs = require('fs');
const path = require('path');

// Create output directory
const outputDir = path.join(__dirname, '..', 'data', 'raw-captures');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Create timestamped output file
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const outputFile = path.join(outputDir, `capture-${timestamp}.txt`);
const hexFile = path.join(outputDir, `capture-${timestamp}.hex`);

console.log('═══════════════════════════════════════════════════════════');
console.log('🎯 RAW SERIAL CAPTURE - NO FILTERING, NO PARSING');
console.log('═══════════════════════════════════════════════════════════');
console.log(`📁 Text output: ${outputFile}`);
console.log(`📁 Hex output: ${hexFile}`);
console.log('');
console.log('💡 Instructions:');
console.log('   1. Press the DAILY REPORT button on the Mutha Goose');
console.log('   2. Let it print the entire report (all pages)');
console.log('   3. Press Ctrl+C when done');
console.log('');
console.log('Starting capture in 3 seconds...');
console.log('═══════════════════════════════════════════════════════════\n');

setTimeout(() => {
  const port = new SerialPort({
    path: '/dev/ttyUSB0',
    baudRate: 9600,
    dataBits: 8,
    stopBits: 1,
    parity: 'none'
  });

  let byteCount = 0;
  let lineCount = 0;
  const textStream = fs.createWriteStream(outputFile);
  const hexStream = fs.createWriteStream(hexFile);

  // Write headers
  textStream.write(`Raw Serial Capture - ${new Date().toISOString()}\n`);
  textStream.write(`Port: /dev/ttyUSB0, Baud: 9600\n`);
  textStream.write('═══════════════════════════════════════════════════════════\n\n');

  hexStream.write(`Hex Dump - ${new Date().toISOString()}\n`);
  hexStream.write('═══════════════════════════════════════════════════════════\n\n');

  port.on('data', (data) => {
    byteCount += data.length;
    
    // Write raw bytes as text
    const text = data.toString('utf8');
    textStream.write(text);
    
    // Write hex dump
    const hex = data.toString('hex').match(/.{1,2}/g).join(' ');
    hexStream.write(`[${byteCount}] ${hex}\n`);
    
    // Count lines (CR or LF)
    lineCount += (text.match(/[\r\n]/g) || []).length;
    
    // Live console output
    process.stdout.write('.');
    if (byteCount % 100 === 0) {
      process.stdout.write(` ${byteCount} bytes, ${lineCount} lines\n`);
    }
  });

  port.on('error', (err) => {
    console.error('\n❌ Serial port error:', err.message);
    cleanup();
  });

  // Graceful shutdown
  function cleanup() {
    console.log('\n\n═══════════════════════════════════════════════════════════');
    console.log('📊 CAPTURE COMPLETE');
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`Total bytes captured: ${byteCount}`);
    console.log(`Total lines: ${lineCount}`);
    console.log(`\n📁 Files saved:`);
    console.log(`   ${outputFile}`);
    console.log(`   ${hexFile}`);
    console.log('\n💡 Next steps:');
    console.log('   1. Review the text file for readable content');
    console.log('   2. Check hex file for control characters');
    console.log('   3. Use this data to build accurate parser patterns');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    textStream.end();
    hexStream.end();
    port.close();
    process.exit(0);
  }

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);

}, 3000);
