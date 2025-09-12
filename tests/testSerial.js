#!/usr/bin/env node

const { SerialPort } = require('serialport');

async function testSerial() {
  console.log('🔍 Scanning for serial ports...');
  
  try {
    const ports = await SerialPort.list();
    console.log('\n📋 Available serial ports:');
    
    if (ports.length === 0) {
      console.log('❌ No serial ports found');
      console.log('   This is expected in a VM - real Pi will have USB ports');
      return;
    }
    
    ports.forEach((port, index) => {
      console.log(`  ${index + 1}. ${port.path}`);
      if (port.manufacturer) console.log(`     Manufacturer: ${port.manufacturer}`);
      if (port.vendorId) console.log(`     Vendor ID: ${port.vendorId}`);
      console.log('');
    });
    
    console.log('✅ Serial port scanning working');
    
  } catch (error) {
    console.error('❌ Error testing serial:', error.message);
    process.exit(1);
  }
}

testSerial();
