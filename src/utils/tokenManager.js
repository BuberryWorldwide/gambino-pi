// src/utils/tokenManager.js
const axios = require('axios');
const fs = require('fs').promises;

class TokenManager {
  constructor(apiBaseUrl, envPath = '.env') {
    this.apiBaseUrl = apiBaseUrl;
    this.envPath = envPath;
    this.hubId = null;
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = null;
    this.refreshCheckInterval = null;
  }

  async init() {
    await this.loadTokens();
    
    // Immediate refresh attempt on init
    console.log('🔄 Running immediate token refresh...');
    await this.refreshAccessToken();
    
    this.startAutoRefresh();
    console.log('🔑 Token manager initialized');
  }

  async loadTokens() {
    try {
      const envContent = await fs.readFile(this.envPath, 'utf8');
      const hubIdMatch = envContent.match(/MACHINE_ID=(.+)/);
      this.hubId = hubIdMatch ? hubIdMatch[1].trim() : null;
      const accessTokenMatch = envContent.match(/MACHINE_TOKEN=(.+)/);
      this.accessToken = accessTokenMatch ? accessTokenMatch[1].trim() : null;
      const refreshTokenMatch = envContent.match(/REFRESH_TOKEN=(.+)/);
      this.refreshToken = refreshTokenMatch ? refreshTokenMatch[1].trim() : null;
      console.log(`✅ Loaded tokens (hubId: ${this.hubId})`);
    } catch (error) {
      console.error('❌ Failed to load tokens:', error.message);
    }
  }

  getAccessToken() {
    return this.accessToken;
  }

  async refreshAccessToken() {
    try {
      if (!this.hubId || !this.refreshToken) {
        console.error('❌ Missing hubId or refreshToken');
        return false;
      }

      console.log('🔄 Refreshing access token...');
      console.log(`   Hub ID: ${this.hubId}`);
      console.log(`   Endpoint: ${this.apiBaseUrl}/api/edge/refresh-token`);
      
      const response = await axios.post(`${this.apiBaseUrl}/api/edge/refresh-token`, {
        hubId: this.hubId,
        refreshToken: this.refreshToken
      });
      
      console.log('📥 Refresh response received');
      
      const { accessToken, accessTokenExpiresAt } = response.data;
      this.accessToken = accessToken;
      this.expiresAt = new Date(accessTokenExpiresAt);
      
      await this.updateEnvFile(accessToken);
      
      console.log(`✅ Token refreshed! Expires: ${this.expiresAt}`);
      return true;
    } catch (error) {
      console.error('❌ Refresh failed:');
      console.error('   Status:', error.response?.status);
      console.error('   Data:', JSON.stringify(error.response?.data, null, 2));
      console.error('   Message:', error.message);
      return false;
    }
  }

  async updateEnvFile(newAccessToken) {
    try {
      let envContent = await fs.readFile(this.envPath, 'utf8');
      envContent = envContent.replace(/MACHINE_TOKEN=.+/, `MACHINE_TOKEN=${newAccessToken}`);
      await fs.writeFile(this.envPath, envContent);
      console.log('✅ Updated .env file');
    } catch (error) {
      console.error('❌ Failed to update .env:', error.message);
    }
  }

  startAutoRefresh() {
    // Check every hour
    this.refreshCheckInterval = setInterval(async () => {
      console.log('⏰ Scheduled refresh...');
      await this.refreshAccessToken();
    }, 60 * 60 * 1000);
  }

  stop() {
    if (this.refreshCheckInterval) {
      clearInterval(this.refreshCheckInterval);
    }
  }
}

module.exports = TokenManager;
