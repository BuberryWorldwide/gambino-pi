#!/bin/bash

# Gambino Pi Installation Script
# Run this script in your ~/gambino-pi/ directory

set -e  # Exit on any error

echo "🚀 Gambino Pi Installation Script"
echo "================================="
echo ""

# Check if we're in the right directory
if [ ! -d "src" ]; then
    echo "❌ Error: Please run this script from your gambino-pi directory"
    echo "Expected directory structure with 'src' folder"
    exit 1
fi

echo "📂 Current directory: $(pwd)"
echo "✅ Directory structure confirmed"
echo ""

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js 18 LTS if not already installed
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js 18 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "✅ Node.js already installed: $(node --version)"
fi

# Install build tools
echo "🔧 Installing build tools..."
sudo apt-get install -y build-essential python3 git

# Install system tools
echo "🛠️ Installing system tools..."
sudo apt-get install -y htop iotop screen vim curl

# Create additional required directories
echo "📁 Creating additional directories..."
mkdir -p data logs config tests/mock

# Check if package.json exists, if not create it
if [ ! -f "package.json" ]; then
    echo "📄 Creating package.json..."
    cat > package.json << 'EOF'
{
  "name": "gambino-pi",
  "version": "1.0.0",
  "description": "Raspberry Pi edge device for Gambino gaming platform",
  "main": "src/main.js",
  "scripts": {
    "start": "node src/main.js",
    "dev": "node --watch src/main.js",
    "test": "node tests/testRunner.js",
    "test-serial": "node tests/testSerial.js",
    "test-api": "node tests/testAPI.js",
    "mock": "node tests/mockMuthaGoose.js",
    "monitor": "node tests/monitor.js"
  },
  "dependencies": {
    "serialport": "^12.0.0",
    "axios": "^1.6.0",
    "winston": "^3.11.0",
    "dotenv": "^16.3.0",
    "@serialport/parser-readline": "^12.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  },
  "keywords": ["raspberry-pi", "serial", "gaming", "edge-device"],
  "author": "Gambino Team",
  "license": "MIT"
}
EOF
else
    echo "✅ package.json already exists"
fi

# Install npm dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# Create environment file template
if [ ! -f ".env" ]; then
    echo "🔐 Creating .env template..."
    cat > .env << 'EOF'
# Gambino Pi Configuration
MACHINE_ID=dev-pi-001
STORE_ID=store_175593957368
API_ENDPOINT=https://api.gambino.gold
MACHINE_TOKEN=your_jwt_token_here

# Serial Configuration  
SERIAL_PORT=/dev/ttyUSB0

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=development
EOF
    echo "⚠️  Please edit .env file with your actual machine credentials"
else
    echo "✅ .env file already exists"
fi

# Create default config if it doesn't exist
if [ ! -f "src/config/default.json" ]; then
    echo "📋 Creating default configuration..."
    cat > src/config/default.json << 'EOF'
{
  "machineId": "dev-pi-001",
  "storeId": "store_175593957368",
  "apiEndpoint": "https://api.gambino.gold",
  "serialPort": "/dev/ttyUSB0",
  "serialBaud": 9600,
  "heartbeatInterval": 30000,
  "retryAttempts": 3,
  "retryDelay": 1000,
  "logLevel": "info",
  "queueMaxSize": 10000,
  "reconnectDelay": 5000,
  "maxReconnectAttempts": 10
}
EOF
else
    echo "✅ Default config already exists"
fi

# Create missing source files if they don't exist
echo "📝 Checking and creating missing source files..."

# Create main.js if missing
if [ ! -f "src/main.js" ]; then
    echo "Creating src/main.js..."
    cat > src/main.js << 'EOF'
require('dotenv').config();
const SerialMonitor = require('./serial/serialMonitor');
const ApiClient = require('./api/apiClient');
const HealthMonitor = require('./health/healthMonitor');
const ConfigManager = require('./config/configManager');
const logger = require('./utils/logger');

class GambinoPi {
  constructor() {
    this.config = new ConfigManager();
    this.apiClient = new ApiClient(this.config);
    this.serialMonitor = new SerialMonitor(this.config);
    this.healthMonitor = new HealthMonitor(this.config, this.apiClient);
    
    this.isRunning = false;
    this.setupGracefulShutdown();
  }

  async start() {
    try {
      logger.info('🚀 Starting Gambino Pi Edge Device...');
      
      await this.config.load();
      logger.info(`📋 Machine ID: ${this.config.get('machineId')}`);
      
      await this.apiClient.testConnection();
      logger.info('✅ API connection verified');
      
      await this.serialMonitor.start();
      logger.info('📡 Serial monitoring started');
      
      this.healthMonitor.start();
      logger.info('❤️ Health monitoring started');
      
      this.setupEventHandlers();
      
      this.isRunning = true;
      logger.info('🎯 Gambino Pi is ready and monitoring...');
      
    } catch (error) {
      logger.error('💥 Failed to start Gambino Pi:', error);
      process.exit(1);
    }
  }

  setupEventHandlers() {
    this.serialMonitor.on('muthaEvent', async (event) => {
      try {
        await this.apiClient.sendEvent(event);
        logger.info(`📤 Event sent: ${event.eventType} - ${event.amount}`);
      } catch (error) {
        logger.error('Failed to send event:', error);
      }
    });

    this.serialMonitor.on('sessionEvent', async (session) => {
      try {
        await this.apiClient.sendSession(session);
        logger.info(`🎮 Session ${session.action}: ${session.sessionId}`);
      } catch (error) {
        logger.error('Failed to send session:', error);
      }
    });

    this.serialMonitor.on('error', (error) => {
      logger.error('Serial monitor error:', error);
    });
  }

  setupGracefulShutdown() {
    const shutdown = async (signal) => {
      if (!this.isRunning) return;
      
      logger.info(`🛑 Received ${signal}, shutting down gracefully...`);
      this.isRunning = false;
      
      try {
        await this.serialMonitor.stop();
        this.healthMonitor.stop();
        await this.apiClient.shutdown();
        logger.info('✅ Graceful shutdown complete');
        process.exit(0);
      } catch (error) {
        logger.error('Error during shutdown:', error);
        process.exit(1);
      }
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  }
}

if (require.main === module) {
  const gambinoPi = new GambinoPi();
  gambinoPi.start();
}

module.exports = GambinoPi;
EOF
fi

# Create utils directory and logger
mkdir -p src/utils
if [ ! -f "src/utils/logger.js" ]; then
    echo "Creating src/utils/logger.js..."
    cat > src/utils/logger.js << 'EOF'
const winston = require('winston');
const path = require('path');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ timestamp, level, message, stack }) => {
      return `${timestamp} [${level.toUpperCase()}] ${message}${stack ? '\n' + stack : ''}`;
    })
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message }) => {
          return `${timestamp} [${level}] ${message}`;
        })
      )
    }),
    new winston.transports.File({
      filename: path.join(__dirname, '../../logs/error.log'),
      level: 'error',
      maxsize: 5242880,
      maxFiles: 5
    }),
    new winston.transports.File({
      filename: path.join(__dirname, '../../logs/combined.log'),
      maxsize: 5242880,
      maxFiles: 5
    })
  ]
});

module.exports = logger;
EOF
fi

# Create test files
echo "🧪 Creating test files..."

# Test runner
if [ ! -f "tests/testRunner.js" ]; then
    cat > tests/testRunner.js << 'EOF'
#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

console.log('🧪 Gambino Pi Test Suite');
console.log('========================');

const tests = [
  { name: 'Serial Port Test', file: 'testSerial.js' },
  { name: 'API Connection Test', file: 'testAPI.js' },
  { name: 'Configuration Test', file: 'testConfig.js' }
];

async function runTest(testFile) {
  return new Promise((resolve, reject) => {
    const testPath = path.join(__dirname, testFile);
    const child = spawn('node', [testPath], { stdio: 'inherit' });
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Test failed with code ${code}`));
      }
    });
  });
}

async function runAllTests() {
  for (const test of tests) {
    try {
      console.log(`\n🔍 Running ${test.name}...`);
      await runTest(test.file);
      console.log(`✅ ${test.name} passed`);
    } catch (error) {
      console.log(`❌ ${test.name} failed`);
    }
  }
  
  console.log('\n🏁 Test suite complete');
}

runAllTests();
EOF
fi

# API test
if [ ! -f "tests/testAPI.js" ]; then
    cat > tests/testAPI.js << 'EOF'
#!/usr/bin/env node

require('dotenv').config();
const axios = require('axios');

async function testAPI() {
  const apiEndpoint = process.env.API_ENDPOINT || 'https://api.gambino.gold';
  const machineToken = process.env.MACHINE_TOKEN;
  
  console.log('🔍 Testing API Connection...');
  console.log(`Endpoint: ${apiEndpoint}`);
  
  if (!machineToken || machineToken === 'your_jwt_token_here') {
    console.log('⚠️  MACHINE_TOKEN not configured in .env file');
    console.log('   Please get your token from the Gambino admin dashboard');
    return;
  }
  
  const api = axios.create({
    baseURL: apiEndpoint,
    timeout: 10000,
    headers: {
      'Authorization': `Bearer ${machineToken}`,
      'Content-Type': 'application/json'
    }
  });
  
  try {
    console.log('📋 Testing config endpoint...');
    const configResponse = await api.get('/api/edge/config');
    console.log('✅ Config endpoint working');
    
    console.log('💰 Testing events endpoint...');
    const eventResponse = await api.post('/api/edge/events', {
      eventType: 'test',
      amount: '25.50',
      timestamp: new Date().toISOString()
    });
    console.log('✅ Events endpoint working');
    
    console.log('💓 Testing heartbeat endpoint...');
    const heartbeatResponse = await api.post('/api/edge/heartbeat', {
      piVersion: process.version,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
      serialConnected: false,
      lastDataReceived: null
    });
    console.log('✅ Heartbeat endpoint working');
    
    console.log('\n🎉 All API tests passed!');
    
  } catch (error) {
    console.error('❌ API test failed:', error.response?.data || error.message);
    process.exit(1);
  }
}

testAPI();
EOF
fi

# Serial test
if [ ! -f "tests/testSerial.js" ]; then
    cat > tests/testSerial.js << 'EOF'
#!/usr/bin/env node

const { SerialPort } = require('serialport');

async function testSerial() {
  console.log('🔍 Scanning for serial ports...');
  
  try {
    const ports = await SerialPort.list();
    console.log('\n📋 Available serial ports:');
    
    if (ports.length === 0) {
      console.log('❌ No serial ports found');
      console.log('   Make sure USB-to-Serial adapter is connected');
      return;
    }
    
    ports.forEach((port, index) => {
      console.log(`  ${index + 1}. ${port.path}`);
      if (port.manufacturer) console.log(`     Manufacturer: ${port.manufacturer}`);
      if (port.vendorId) console.log(`     Vendor ID: ${port.vendorId}`);
      console.log('');
    });
    
    console.log('✅ Serial port discovery working');
    
  } catch (error) {
    console.error('❌ Error testing serial:', error.message);
    process.exit(1);
  }
}

testSerial();
EOF
fi

# Mock Mutha Goose
if [ ! -f "tests/mockMuthaGoose.js" ]; then
    cat > tests/mockMuthaGoose.js << 'EOF'
#!/usr/bin/env node

const logger = require('../src/utils/logger');

class MockMuthaGoose {
  constructor() {
    this.isRunning = false;
    this.interval = null;
  }

  start() {
    if (this.isRunning) return;
    
    console.log('🎮 Starting Mock Mutha Goose data generator...');
    this.isRunning = true;
    
    this.interval = setInterval(() => {
      this.generateRandomEvent();
    }, Math.random() * 10000 + 5000);
    
    console.log('📡 Generating events every 5-15 seconds...');
    console.log('Press Ctrl+C to stop');
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.isRunning = false;
    console.log('Mock Mutha Goose stopped');
  }

  generateRandomEvent() {
    const events = [
      this.generateVoucherEvent(),
      this.generateMoneyInEvent(), 
      this.generateCollectEvent(),
      this.generateSessionStart(),
      this.generateSessionEnd()
    ];
    
    const event = events[Math.floor(Math.random() * events.length)];
    console.log(`🎲 Mock Event: ${event}`);
    return event;
  }

  generateVoucherEvent() {
    const amount = (Math.random() * 500 + 10).toFixed(2);
    const timestamp = new Date().toISOString();
    return `VOUCHER PRINT: $${amount} - ${timestamp} - MACHINE ${Math.floor(Math.random() * 99) + 1}`;
  }

  generateMoneyInEvent() {
    const amount = (Math.random() * 100 + 5).toFixed(2);
    const timestamp = new Date().toISOString();
    return `MONEY IN: $${amount} - ${timestamp} - MACHINE ${Math.floor(Math.random() * 99) + 1}`;
  }

  generateCollectEvent() {
    const amount = (Math.random() * 200 + 20).toFixed(2);
    const timestamp = new Date().toISOString(); 
    return `COLLECT: $${amount} - ${timestamp} - MACHINE ${Math.floor(Math.random() * 99) + 1}`;
  }

  generateSessionStart() {
    const sessionId = `session_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const timestamp = new Date().toISOString();
    return `SESSION START: ${sessionId} - ${timestamp} - MACHINE ${Math.floor(Math.random() * 99) + 1}`;
  }

  generateSessionEnd() {
    const sessionId = `session_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const timestamp = new Date().toISOString();
    return `SESSION END: ${sessionId} - ${timestamp} - MACHINE ${Math.floor(Math.random() * 99) + 1}`;
  }
}

if (require.main === module) {
  const mock = new MockMuthaGoose();
  mock.start();
  
  process.on('SIGINT', () => {
    console.log('\n🛑 Stopping mock generator...');
    mock.stop();
    process.exit(0);
  });
}

module.exports = MockMuthaGoose;
EOF
fi

# Set up USB serial device rules for when we connect real hardware
echo "🔌 Setting up USB device rules..."
sudo tee /etc/udev/rules.d/99-usb-serial.rules > /dev/null << 'EOF'
# FTDI USB-to-Serial adapter
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="ttyUSB-FTDI"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6015", SYMLINK+="ttyUSB-FTDI"

# Set permissions for serial devices
SUBSYSTEM=="tty", GROUP="dialout", MODE="0664"
EOF

# Add user to dialout group for serial access
echo "👥 Adding user to dialout group..."
sudo usermod -a -G dialout $USER

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Make test files executable
chmod +x tests/*.js

# Create a handy run script
cat > run-gambino.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Gambino Pi..."
echo "========================="

# Check if .env is configured
if grep -q "your_jwt_token_here" .env 2>/dev/null; then
    echo "⚠️  Warning: Please configure your .env file with real credentials"
    echo "   Get your machine token from: https://app.gambino.gold/admin"
    echo ""
fi

# Start the application
npm run dev
EOF

chmod +x run-gambino.sh

echo ""
echo "✅ Installation Complete!"
echo "========================="
echo ""
echo "📋 What was installed:"
echo "  ✅ Node.js $(node --version)"
echo "  ✅ NPM dependencies (serialport, axios, winston, etc.)"
echo "  ✅ Development tools and system utilities"
echo "  ✅ Environment configuration (.env)"
echo "  ✅ Test suite and mock data generator"
echo "  ✅ USB serial device rules"
echo ""
echo "🔧 Next Steps:"
echo "1. Configure your machine token:"
echo "   nano .env"
echo "   # Set MACHINE_TOKEN from your Gambino admin dashboard"
echo ""
echo "2. Test the installation:"
echo "   npm run test-api        # Test API connection"
echo "   npm run test-serial     # Check for serial devices"
echo "   npm run mock           # Run mock data generator"
echo ""
echo "3. Start development:"
echo "   ./run-gambino.sh       # Start the Pi application"
echo "   npm run dev            # Or start with auto-reload"
echo ""
echo "📊 Monitoring commands:"
echo "   tail -f logs/combined.log    # View application logs"
echo "   htop                         # System resources"
echo "   ls -la /dev/ttyUSB*         # Check serial devices"
echo ""
echo "🎯 Your Gambino Pi development environment is ready!"
echo ""
echo "⚠️  Remember to:"
echo "   - Configure .env with your real machine token"
echo "   - Test API connectivity before serial development"
echo "   - Use the mock generator for initial testing"
echo ""
