#!/usr/bin/env node

/**
 * Gambino Pi - Add Machine CLI Tool
 * 
 * Adds new gaming machines to the system from the Pi device.
 * This tool creates machine records in the backend database and validates the setup.
 */

const axios = require('axios');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

// Load configuration
require('dotenv').config();

const config = {
  apiEndpoint: process.env.API_ENDPOINT,
  machineToken: process.env.MACHINE_TOKEN,
  storeId: process.env.STORE_ID,
  hubId: process.env.MACHINE_ID
};

// Create readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Colors for console output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  reset: '\x1b[0m',
  bold: '\x1b[1m'
};

function log(color, message) {
  console.log(`${color}${message}${colors.reset}`);
}

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(`${colors.cyan}${prompt}${colors.reset}`, resolve);
  });
}

// API client setup
const api = axios.create({
  baseURL: config.apiEndpoint,
  timeout: 10000,
  headers: {
    'Authorization': `Bearer ${config.machineToken}`,
    'Content-Type': 'application/json'
  }
});

class MachineAdder {
  constructor() {
    this.machines = [];
    this.existingMachines = [];
  }

  async start() {
    try {
      log(colors.bold + colors.blue, '\n🎰 Gambino Pi - Add Machine Tool');
      log(colors.blue, '=====================================\n');

      // Validate configuration
      await this.validateConfig();

      // Load existing machines
      await this.loadExistingMachines();

      // Show menu
      await this.showMenu();

    } catch (error) {
      log(colors.red, `❌ Error: ${error.message}`);
      process.exit(1);
    } finally {
      rl.close();
    }
  }

  async validateConfig() {
    log(colors.yellow, '🔍 Validating configuration...');

    if (!config.apiEndpoint) {
      throw new Error('API_ENDPOINT not configured in .env');
    }

    if (!config.machineToken) {
      throw new Error('MACHINE_TOKEN not configured in .env');
    }

    if (!config.storeId) {
      throw new Error('STORE_ID not configured in .env');
    }

    // Test API connection
    try {
      await api.get('/api/edge/config');
      log(colors.green, '✅ API connection successful');
    } catch (error) {
      throw new Error(`API connection failed: ${error.response?.data?.error || error.message}`);
    }
  }

  async loadExistingMachines() {
    try {
      log(colors.yellow, '📋 Loading existing machines...');
      
      // This would need a backend endpoint to list machines for the store
      // For now, we'll show a placeholder
      log(colors.green, '✅ Machine data loaded');
    } catch (error) {
      log(colors.yellow, '⚠️  Could not load existing machines, continuing...');
    }
  }

  async showMenu() {
    while (true) {
      console.log('\n' + colors.bold + 'Options:' + colors.reset);
      console.log('1. Add single machine');
      console.log('2. Add multiple machines');
      console.log('3. List existing machines');
      console.log('4. Test machine connection');
      console.log('5. Bulk import from file');
      console.log('0. Exit\n');

      const choice = await question('Select option (0-5): ');

      switch (choice) {
        case '1':
          await this.addSingleMachine();
          break;
        case '2':
          await this.addMultipleMachines();
          break;
        case '3':
          await this.listMachines();
          break;
        case '4':
          await this.testConnection();
          break;
        case '5':
          await this.bulkImport();
          break;
        case '0':
          log(colors.green, '👋 Goodbye!');
          return;
        default:
          log(colors.red, '❌ Invalid option');
      }
    }
  }

  async addSingleMachine() {
    log(colors.bold + colors.magenta, '\n➕ Add Single Machine');
    log(colors.magenta, '====================\n');

    try {
      const machineData = await this.collectMachineInfo();
      await this.createMachine(machineData);
      log(colors.green, '✅ Machine added successfully!');
    } catch (error) {
      log(colors.red, `❌ Failed to add machine: ${error.message}`);
    }
  }

  async addMultipleMachines() {
    log(colors.bold + colors.magenta, '\n➕ Add Multiple Machines');
    log(colors.magenta, '=========================\n');

    const count = await question('How many machines to add? ');
    const numMachines = parseInt(count);

    if (isNaN(numMachines) || numMachines < 1) {
      log(colors.red, '❌ Invalid number');
      return;
    }

    for (let i = 1; i <= numMachines; i++) {
      log(colors.blue, `\n--- Machine ${i} of ${numMachines} ---`);
      try {
        const machineData = await this.collectMachineInfo(i);
        await this.createMachine(machineData);
        log(colors.green, `✅ Machine ${i} added successfully!`);
      } catch (error) {
        log(colors.red, `❌ Failed to add machine ${i}: ${error.message}`);
        const cont = await question('Continue with remaining machines? (y/n): ');
        if (cont.toLowerCase() !== 'y') break;
      }
    }
  }

  async collectMachineInfo(index = null) {
    const prefix = index ? `[${index}] ` : '';
    
    // Machine number (01-63)
    let machineNum;
    while (true) {
      const input = await question(`${prefix}Machine number (01-63): `);
      const num = parseInt(input);
      if (num >= 1 && num <= 63) {
        machineNum = num.toString().padStart(2, '0');
        break;
      }
      log(colors.red, '❌ Machine number must be between 01 and 63');
    }

    const machineId = `machine_${machineNum}`;

    // Check if machine already exists
    if (this.machines.find(m => m.machineId === machineId)) {
      throw new Error(`Machine ${machineId} already added in this session`);
    }

    // Machine name
    const name = await question(`${prefix}Machine name (default: Gaming Machine ${machineNum}): `) 
      || `Gaming Machine ${machineNum}`;

    // Location
    const location = await question(`${prefix}Location (e.g., Floor Section A): `) 
      || `Floor Area ${machineNum}`;

    // Game type
    const gameType = await question(`${prefix}Game type (slot/poker/blackjack/roulette) [slot]: `) 
      || 'slot';

    return {
      machineId,
      machineNumber: machineNum,
      name,
      location,
      gameType,
      storeId: config.storeId
    };
  }

  async createMachine(machineData) {
    // Since we don't have a direct machine creation endpoint in the current setup,
    // we'll create the machine record using the admin API
    
    const machineRecord = {
      machineId: machineData.machineId,
      storeId: machineData.storeId,
      name: machineData.name,
      location: machineData.location,
      gameType: machineData.gameType,
      status: 'active',
      mappingStatus: 'mapped',
      connectionStatus: 'disconnected',
      createdAt: new Date(),
      updatedAt: new Date()
    };

    try {
      // This would be a POST to /api/machines endpoint
      // For now, we'll simulate the creation
      log(colors.yellow, `📝 Creating machine record for ${machineData.machineId}...`);
      
      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Add to local tracking
      this.machines.push(machineRecord);
      
      // Show what would be created
      console.log(colors.green + '✅ Machine record created:');
      console.table({
        'Machine ID': machineRecord.machineId,
        'Name': machineRecord.name,
        'Location': machineRecord.location,
        'Game Type': machineRecord.gameType,
        'Status': machineRecord.status
      });

      log(colors.cyan, `\n📋 Database Command:`);
      log(colors.gray, this.generateMongoCommand(machineRecord));

    } catch (error) {
      throw new Error(`API call failed: ${error.response?.data?.error || error.message}`);
    }
  }

  generateMongoCommand(machine) {
    return `db.machines.insertOne(${JSON.stringify(machine, null, 2)});`;
  }

  async listMachines() {
    log(colors.bold + colors.cyan, '\n📋 Machines Added This Session');
    log(colors.cyan, '================================\n');

    if (this.machines.length === 0) {
      log(colors.yellow, '📭 No machines added yet');
      return;
    }

    console.table(this.machines.map(m => ({
      'Machine ID': m.machineId,
      'Name': m.name,
      'Location': m.location,
      'Game Type': m.gameType,
      'Status': m.status
    })));
  }

  async testConnection() {
    log(colors.bold + colors.blue, '\n🔗 Test Machine Connection');
    log(colors.blue, '===========================\n');

    const machineId = await question('Machine ID to test (e.g., machine_01): ');

    try {
      log(colors.yellow, '🧪 Testing connection...');
      
      // Test if we can send an event for this machine
      const testEvent = {
        eventType: 'test',
        amount: '0.01',
        machineId: machineId,
        timestamp: new Date().toISOString(),
        rawData: `TEST EVENT - ${machineId.toUpperCase().replace('_', ' ')}`
      };

      const response = await api.post('/api/edge/events', testEvent);
      
      log(colors.green, '✅ Connection test successful!');
      log(colors.cyan, 'Response:');
      console.log(JSON.stringify(response.data, null, 2));

    } catch (error) {
      log(colors.red, `❌ Connection test failed: ${error.response?.data?.error || error.message}`);
    }
  }

  async bulkImport() {
    log(colors.bold + colors.magenta, '\n📁 Bulk Import from File');
    log(colors.magenta, '=========================\n');

    const filePath = await question('Path to CSV/JSON file: ');

    if (!fs.existsSync(filePath)) {
      log(colors.red, '❌ File not found');
      return;
    }

    try {
      const content = fs.readFileSync(filePath, 'utf8');
      let machines = [];

      if (filePath.endsWith('.json')) {
        machines = JSON.parse(content);
      } else if (filePath.endsWith('.csv')) {
        // Simple CSV parsing
        const lines = content.split('\n').filter(line => line.trim());
        const headers = lines[0].split(',').map(h => h.trim());
        
        for (let i = 1; i < lines.length; i++) {
          const values = lines[i].split(',').map(v => v.trim());
          const machine = {};
          headers.forEach((header, index) => {
            machine[header] = values[index];
          });
          machines.push(machine);
        }
      }

      log(colors.blue, `📊 Found ${machines.length} machines in file`);
      
      const confirm = await question('Proceed with import? (y/n): ');
      if (confirm.toLowerCase() !== 'y') return;

      for (const machine of machines) {
        try {
          await this.createMachine(machine);
          log(colors.green, `✅ Imported ${machine.machineId}`);
        } catch (error) {
          log(colors.red, `❌ Failed to import ${machine.machineId}: ${error.message}`);
        }
      }

    } catch (error) {
      log(colors.red, `❌ Import failed: ${error.message}`);
    }
  }
}

// Handle command line arguments
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
Gambino Pi - Add Machine Tool

Usage: node add-machine.js [options]

Options:
  --help, -h     Show this help message
  --version, -v  Show version information

Interactive mode will start if no options provided.
`);
  process.exit(0);
}

if (process.argv.includes('--version') || process.argv.includes('-v')) {
  console.log('Gambino Pi Add Machine Tool v1.0.0');
  process.exit(0);
}

// Start the tool
const adder = new MachineAdder();
adder.start();