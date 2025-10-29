// src/utils/tokenManager.js
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');

class TokenManager {
  constructor(apiBaseUrl, envPath = '.env') {
    this.apiBaseUrl = apiBaseUrl;
    this.envPath = envPath;
    this.accessToken = null;
    this.refreshToken = null;
    this.expiresAt = null;
    this.refreshCheckInterval = null;
  }

  async init() {
    // Load tokens from .env
    await this.loadTokens();
    
    // Start auto-refresh checker (every hour)
    this.startAutoRefresh();
    
    console.log('🔑 Token manager initialized');
  }

  async loadTokens() {
    try {
      const envContent = await fs.readFile(this.envPath, 'utf8');
      
      const accessTokenMatch = envContent.match(/MACHINE_TOKEN=(.+)/);
      const refreshTokenMatch = envContent.match(/REFRESH_TOKEN=(.+)/);
      
      this.accessToken = accessTokenMatch ? accessTokenMatch[1].trim() : null;
      this.refreshToken = refreshTokenMatch ? refreshTokenMatch[1].trim() : null;
      
      console.log('✅ Loaded tokens from .env');
    } catch (error) {
      console.error('❌ Failed to load tokens:', error.message);
    }
  }

  getAccessToken() {
    return this.accessToken;
  }

  async checkAndRefresh() {
    try {
      if (!this.refreshToken) {
        console.warn('⚠️  No refresh token available');
        return false;
      }

      // Check token status
      const statusResponse = await axios.get(`${this.apiBaseUrl}/api/token/status`, {
        headers: { 'Authorization': `Bearer ${this.accessToken}` }
      });

      const { needsRefresh, expiresIn } = statusResponse.data;
      
      console.log(`🔍 Token status: expires in ${Math.floor(expiresIn / 3600)}h`);

      if (needsRefresh) {
        console.log('🔄 Token needs refresh, refreshing now...');
        return await this.refreshAccessToken();
      }

      return true;
    } catch (error) {
      console.error('❌ Token status check failed:', error.message);
      
      // If 401, try to refresh
      if (error.response?.status === 401) {
        return await this.refreshAccessToken();
      }
      
      return false;
    }
  }

  async refreshAccessToken() {
    try {
      console.log('🔄 Refreshing access token...');

      const response = await axios.post(`${this.apiBaseUrl}/api/token/refresh`, {
        refreshToken: this.refreshToken
      });

      const { accessToken, expiresAt } = response.data;

      // Update in-memory token
      this.accessToken = accessToken;
      this.expiresAt = new Date(expiresAt);

      // Update .env file
      await this.updateEnvFile(accessToken);

      console.log(`✅ Token refreshed successfully! Expires: ${this.expiresAt}`);
      return true;

    } catch (error) {
      console.error('❌ Token refresh failed:', error.response?.data || error.message);
      
      if (error.response?.data?.code === 'REFRESH_TOKEN_EXPIRED') {
        console.error('🚨 REFRESH TOKEN EXPIRED - Manual re-registration required!');
      }
      
      return false;
    }
  }

  async updateEnvFile(newAccessToken) {
    try {
      let envContent = await fs.readFile(this.envPath, 'utf8');
      
      // Replace access token
      envContent = envContent.replace(
        /MACHINE_TOKEN=.+/,
        `MACHINE_TOKEN=${newAccessToken}`
      );
      
      await fs.writeFile(this.envPath, envContent);
      console.log('✅ Updated .env file with new token');
    } catch (error) {
      console.error('❌ Failed to update .env:', error.message);
    }
  }

  startAutoRefresh() {
    // Check every hour
    this.refreshCheckInterval = setInterval(async () => {
      console.log('⏰ Running scheduled token refresh check...');
      await this.checkAndRefresh();
    }, 60 * 60 * 1000); // 1 hour

    // Also check on startup
    setTimeout(() => this.checkAndRefresh(), 5000);
  }

  stop() {
    if (this.refreshCheckInterval) {
      clearInterval(this.refreshCheckInterval);
    }
  }
}

module.exports = TokenManager;
