const { SerialPort } = require('serialport');

const port = new SerialPort({
  path: '/dev/ttyUSB0',
  baudRate: 9600,
  dataBits: 8,
  stopBits: 1,
  parity: 'none'
});

port.on('data', (data) => {
  console.log('=== RAW BYTES ===');
  console.log(data);
  console.log('=== HEX ===');
  console.log(data.toString('hex'));
  console.log('=== ASCII ===');
  console.log(data.toString('ascii'));
  console.log('=== CLEAN ===');
  console.log(data.toString('ascii').replace(/[\x00-\x1F\x7F-\x9F]/g, ''));
  console.log('================\n');
});

port.on('error', (err) => {
  console.error('Error:', err);
});

console.log('Listening to /dev/ttyUSB0... Press Ctrl+C to exit');
