// fix_mappings.js - Fix the machine mapping format for CLI tools
const fs = require('fs');
const path = require('path');
const sqlite3 = require('better-sqlite3');

const DB_PATH = './data/gambino-pi.db';
const MAPPING_PATH = './data/machine-mappings.json';

function fixMappings() {
    console.log('🔧 Fixing machine mapping format...');
    
    try {
        // 1. Read from SQLite database
        const db = sqlite3(DB_PATH);
        const machines = db.prepare('SELECT * FROM machines ORDER BY machine_id').all();
        db.close();
        
        console.log(`📥 Found ${machines.length} machines in SQLite database`);
        
        // 2. Create proper mapping format for CLI tools
        const mappings = {};
        
        // Map first few machines to physical IDs 1, 3, 5, etc.
        const physicalIds = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19];
        
        machines.forEach((machine, index) => {
            if (index < physicalIds.length) {
                const physicalId = physicalIds[index];
                
                mappings[physicalId] = {
                    physicalId: physicalId,
                    logicalId: machine.machine_id,
                    name: machine.name || machine.machine_id,
                    gameType: machine.game_type || 'slot',
                    location: machine.location || 'Floor',
                    storeId: machine.store_id,
                    status: machine.status || 'active',
                    addedAt: machine.created_at || new Date().toISOString(),
                    lastSeen: machine.updated_at || null
                };
                
                console.log(`✅ Mapped Physical ${physicalId} -> ${machine.machine_id}`);
            }
        });
        
        // 3. Save the mappings in the correct format
        fs.writeFileSync(MAPPING_PATH, JSON.stringify(mappings, null, 2));
        console.log(`✅ Saved ${Object.keys(mappings).length} mappings to ${MAPPING_PATH}`);
        
        // 4. Also create the simple mapping format for Pi app
        const simpleMappings = {};
        Object.values(mappings).forEach(m => {
            simpleMappings[m.physicalId] = m.logicalId;
        });
        
        // Update both formats
        fs.writeFileSync('./data/machine-mappings-simple.json', JSON.stringify(simpleMappings, null, 2));
        
        console.log('\n📋 Created mappings:');
        Object.values(mappings).forEach(m => {
            console.log(`  Physical ${m.physicalId}: ${m.logicalId} (${m.name})`);
        });
        
        console.log('\n✅ Machine mapping format fixed!');
        console.log('Now run your CLI tools again to see the proper machine list.');
        
    } catch (error) {
        console.error('❌ Failed to fix mappings:', error.message);
    }
}

// Also create a function to verify the fix worked
function verifyMappings() {
    console.log('\n🔍 Verifying mappings...');
    
    try {
        if (fs.existsSync(MAPPING_PATH)) {
            const mappings = JSON.parse(fs.readFileSync(MAPPING_PATH, 'utf8'));
            console.log(`✅ Mapping file exists with ${Object.keys(mappings).length} entries`);
            
            // Show first few entries
            Object.values(mappings).slice(0, 3).forEach(m => {
                console.log(`  ✓ Physical ${m.physicalId}: ${m.logicalId} - ${m.name}`);
            });
        } else {
            console.log('❌ Mapping file not found');
        }
    } catch (error) {
        console.error('❌ Error reading mappings:', error.message);
    }
}

// Run the fix
fixMappings();
verifyMappings();