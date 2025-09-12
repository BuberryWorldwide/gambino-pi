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
