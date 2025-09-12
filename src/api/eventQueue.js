const fs = require('fs').promises;
const path = require('path');
const logger = require('../utils/logger');

class EventQueue {
  constructor() {
    this.queueFile = path.join(__dirname, '../../data/event_queue.json');
    this.queue = [];
    this.maxQueueSize = 10000;
    
    this.loadQueue();
  }

  async loadQueue() {
    try {
      const dataDir = path.dirname(this.queueFile);
      await fs.mkdir(dataDir, { recursive: true });
      
      const data = await fs.readFile(this.queueFile, 'utf8');
      this.queue = JSON.parse(data);
      logger.info(`📥 Loaded ${this.queue.length} events from queue`);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        logger.warn('Failed to load event queue:', error.message);
      }
      this.queue = [];
    }
  }

  async saveQueue() {
    try {
      await fs.writeFile(this.queueFile, JSON.stringify(this.queue, null, 2));
    } catch (error) {
      logger.error('Failed to save event queue:', error);
    }
  }

  add(event) {
    const queuedEvent = {
      ...event,
      queuedAt: new Date().toISOString(),
      attempts: 0,
      status: 'pending'
    };

    this.queue.push(queuedEvent);
    
    if (this.queue.length > this.maxQueueSize) {
      this.queue = this.queue.slice(-this.maxQueueSize);
      logger.warn(`Queue trimmed to ${this.maxQueueSize} events`);
    }

    this.saveQueue();
    logger.debug(`📝 Event added to queue: ${event.eventType}`);
  }

  markComplete(event) {
    const index = this.queue.findIndex(q => 
      q.eventType === event.eventType && 
      q.timestamp === event.timestamp
    );
    
    if (index !== -1) {
      this.queue.splice(index, 1);
      this.saveQueue();
      logger.debug(`✅ Event removed from queue: ${event.eventType}`);
    }
  }

  size() {
    return this.queue.length;
  }
}

module.exports = EventQueue;
