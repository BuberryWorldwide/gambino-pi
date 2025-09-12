#!/usr/bin/env node

const LocalDatabase = require('../src/database/localDb');
const logger = require('../src/utils/logger');

async function testDatabase() {
  console.log('🔍 Testing Local Database...\n');
  
  try {
    const db = new LocalDatabase();
    
    // Test storing an event
    console.log('1. Testing event storage...');
    const testEvent = {
      eventType: 'test_voucher',
      machineId: 'machine_01',
      amount: '50.00',
      timestamp: new Date().toISOString(),
      rawData: 'TEST VOUCHER PRINT: $50.00 - MACHINE 01'
    };
    
    const eventId = db.storeEvent(testEvent);
    console.log(`   ✅ Event stored with ID: ${eventId}`);
    
    // Test storing a session
    console.log('\n2. Testing session storage...');
    const testSession = {
      sessionId: 'test_session_123',
      machineId: 'machine_01',
      action: 'start',
      timestamp: new Date().toISOString(),
      rawData: 'TEST SESSION START - MACHINE 01'
    };
    
    const sessionId = db.storeSession(testSession);
    console.log(`   ✅ Session stored with ID: ${sessionId}`);
    
    // Check unsynced data
    console.log('\n3. Checking unsynced data...');
    const unsyncedEvents = db.getUnsyncedEvents();
    const unsyncedSessions = db.getUnsyncedSessions();
    
    console.log(`   📊 Unsynced events: ${unsyncedEvents.length}`);
    console.log(`   📊 Unsynced sessions: ${unsyncedSessions.length}`);
    
    if (unsyncedEvents.length > 0) {
      console.log('\n   Recent unsynced events:');
      unsyncedEvents.slice(0, 3).forEach(event => {
        console.log(`   - ${event.event_type} | ${event.machine_id} | $${event.amount || 'N/A'} | ${event.created_at}`);
      });
    }
    
    // Get sync statistics
    console.log('\n4. Database statistics...');
    const stats = db.getSyncStats();
    console.log(`   📈 Total events: ${stats.totalEvents}`);
    console.log(`   📈 Total sessions: ${stats.totalSessions}`);
    console.log(`   ⏳ Pending events: ${stats.pendingEvents}`);
    console.log(`   ⏳ Pending sessions: ${stats.pendingSessions}`);
    
    // Test marking as synced
    console.log('\n5. Testing sync marking...');
    db.markEventSynced(eventId);
    db.markSessionSynced(sessionId);
    console.log('   ✅ Test records marked as synced');
    
    // Final stats
    const finalStats = db.getSyncStats();
    console.log(`   📈 Pending events after sync: ${finalStats.pendingEvents}`);
    console.log(`   📈 Pending sessions after sync: ${finalStats.pendingSessions}`);
    
    db.close();
    console.log('\n🎉 Database test completed successfully!');
    
  } catch (error) {
    console.error('❌ Database test failed:', error);
    process.exit(1);
  }
}

testDatabase();
