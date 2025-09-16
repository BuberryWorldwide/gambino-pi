const sqlite3 = require('sqlite3').verbose();
const fetch = require('node-fetch');
const fs = require('fs');

// Configuration
const LOCAL_DB = './data/gambino-pi.db';
const API_URL = process.env.API_URL || 'http://localhost:3000';
const MACHINE_TOKEN = process.env.MACHINE_TOKEN;

if (!MACHINE_TOKEN) {
    console.log('❌ MACHINE_TOKEN not found in environment');
    process.exit(1);
}

async function syncMachines() {
    console.log('🔄 Starting machine sync...');
    
    try {
        // 1. Get machines from MongoDB via API
        const response = await fetch(`${API_URL}/api/edge/config`, {
            headers: { 'Authorization': `Bearer ${MACHINE_TOKEN}` }
        });
        
        if (!response.ok) {
            throw new Error(`API error: ${response.status}`);
        }
        
        const config = await response.json();
        console.log('✅ Connected to API, store:', config.config?.storeName);
        
        // 2. Get store machines
        const machinesResponse = await fetch(`${API_URL}/api/machines/stores/${config.config.storeId}`, {
            headers: { 'Authorization': `Bearer ${MACHINE_TOKEN}` }
        });
        
        if (!machinesResponse.ok) {
            throw new Error(`Machines API error: ${machinesResponse.status}`);
        }
        
        const machinesData = await machinesResponse.json();
        const remoteMachines = machinesData.machines || [];
        
        console.log(`📥 Found ${remoteMachines.length} machines in MongoDB`);
        
        // 3. Open local database
        const db = new sqlite3.Database(LOCAL_DB);
        
        // Create machines table if it doesn't exist
        db.run(`
            CREATE TABLE IF NOT EXISTS machines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                machine_id TEXT UNIQUE NOT NULL,
                store_id TEXT NOT NULL,
                name TEXT,
                game_type TEXT DEFAULT 'slot',
                status TEXT DEFAULT 'active',
                created_by TEXT DEFAULT 'admin',
                sync_status TEXT DEFAULT 'synced',
                mongodb_id TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        `);
        
        // 4. Sync each machine
        for (const machine of remoteMachines) {
            console.log(`🔄 Syncing machine: ${machine.machineId}`);
            
            db.run(`
                INSERT OR REPLACE INTO machines (
                    machine_id, store_id, name, game_type, status,
                    created_by, sync_status, mongodb_id, updated_at
                ) VALUES (?, ?, ?, ?, ?, 'admin', 'synced', ?, CURRENT_TIMESTAMP)
            `, [
                machine.machineId,
                machine.storeId,
                machine.name || machine.machineId,
                machine.gameType || 'slot',
                machine.status || 'active',
                machine._id
            ]);
        }
        
        // 5. Update machine mappings file
        const mappings = {};
        let fledglingNum = 1;
        
        for (const machine of remoteMachines) {
            mappings[fledglingNum] = machine.machineId;
            fledglingNum += 2; // Use 1, 3, 5, etc.
        }
        
        // Create data directory if it doesn't exist
        if (!fs.existsSync('./data')) {
            fs.mkdirSync('./data', { recursive: true });
        }
        
        fs.writeFileSync('./data/machine-mappings.json', JSON.stringify(mappings, null, 2));
        console.log('✅ Updated machine mappings:', mappings);
        
        // 6. Close database
        db.close();
        
        console.log('✅ Machine sync complete!');
        
    } catch (error) {
        console.error('❌ Sync failed:', error.message);
        process.exit(1);
    }
}

syncMachines();
