const axios = require('axios');
const EventQueue = require('./eventQueue');
const logger = require('../utils/logger');

class ApiClient {
  constructor(config) {
    this.config = config;
    this.eventQueue = new EventQueue();
    this.baseURL = config.get('apiEndpoint');
    this.machineToken = config.get('machineToken');
    
    // Configure axios instance
    this.api = axios.create({
      baseURL: this.baseURL,
      timeout: 10000,
      headers: {
        'Authorization': `Bearer ${this.machineToken}`,
        'Content-Type': 'application/json'
      }
    });

    // Add response interceptor for error handling
    this.api.interceptors.response.use(
      (response) => response,
      (error) => this.handleApiError(error)
    );
  }

  async testConnection() {
    try {
      const response = await this.api.get('/api/edge/config');
      logger.info('✅ API connection test successful');
      return response.data;
    } catch (error) {
      logger.error('❌ API connection test failed:', error.message);
      throw error;
    }
  }

  // Enhanced sendEvent method with detailed logging
async sendEvent(event) {
  try {
    // Add to queue first for reliability
    this.eventQueue.add(event);
    
    // ✅ ADD DETAILED LOGGING
    console.log('🔍 Sending event to backend:', {
      eventType: event.eventType,
      machineId: event.machineId,  // This should be machine_01, machine_03, etc.
      amount: event.amount,
      timestamp: event.timestamp
    });
    
    const payload = {
      eventType: event.eventType,
      amount: event.amount,
      timestamp: event.timestamp,
      machineId: event.machineId,  // ✅ Make sure this is included
      rawData: event.rawData,  // ✅ Move rawData to top level for backend parsing
      metadata: {
        // Additional metadata can go here
        piVersion: process.version,
        hubId: this.config.get('machineId')
      }
    };
    
    // ✅ LOG THE EXACT PAYLOAD BEING SENT
    console.log('📤 Payload being sent to /api/edge/events:', JSON.stringify(payload, null, 2));
    
    const response = await this.api.post('/api/edge/events', payload);

    // Remove from queue on success
    this.eventQueue.markComplete(event);
    
    // ✅ LOG SUCCESSFUL RESPONSE
    console.log(`✅ Event sent successfully: ${event.eventType} from ${event.machineId}`);
    console.log('📥 Backend response:', response.data);
    
    return response.data;

  } catch (error) {
    // ✅ ENHANCED ERROR LOGGING
    console.error(`❌ Failed to send event ${event.eventType} from ${event.machineId}:`, {
      error: error.message,
      status: error.response?.status,
      data: error.response?.data,
      payload: {
        eventType: event.eventType,
        machineId: event.machineId,
        amount: event.amount
      }
    });
    
    // Event remains in queue for retry
    throw error;
  }
}

  async sendSession(session) {
    try {
      const response = await this.api.post('/api/edge/sessions', {
        action: session.action,
        sessionId: session.sessionId,
        timestamp: session.timestamp,
        machineId: session.machineId,
        metadata: {
          rawData: session.rawData
        }
      });

      logger.info(`🎮 Session sent successfully: ${session.action}`);
      return response.data;

    } catch (error) {
      logger.error(`Failed to send session ${session.action}:`, error.message);
      throw error;
    }
  }

  async sendHeartbeat(healthData) {
    try {
      const response = await this.api.post('/api/edge/heartbeat', {
        piVersion: process.version,
        uptime: process.uptime(),
        memoryUsage: process.memoryUsage(),
        serialConnected: healthData.serialConnected,
        lastDataReceived: healthData.lastDataReceived,
        queueSize: this.eventQueue.size()
      });

      logger.debug('💓 Heartbeat sent successfully');
      return response.data;

    } catch (error) {
      logger.error('Failed to send heartbeat:', error.message);
      throw error;
    }
  }

  handleApiError(error) {
    if (error.response) {
      logger.error(`API Error ${error.response.status}: ${error.response.data?.error || 'Unknown error'}`);
    } else if (error.request) {
      logger.error('Network error - no response received');
    } else {
      logger.error('Request error:', error.message);
    }
    
    return Promise.reject(error);
  }

  async shutdown() {
    try {
      await this.api.post('/api/edge/heartbeat', {
        piVersion: process.version,
        uptime: process.uptime(),
        status: 'shutting_down',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.warn('Failed to send shutdown heartbeat:', error.message);
    }
  }
}

module.exports = ApiClient;
