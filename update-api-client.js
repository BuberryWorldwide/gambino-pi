const fs = require('fs');

const apiClientPath = './src/api/apiClient.js';
let content = fs.readFileSync(apiClientPath, 'utf8');

// Add tokenManager property and methods
const tokenManagerCode = `
  setTokenManager(tokenManager) {
    this.tokenManager = tokenManager;
  }

  getAuthHeader() {
    if (this.tokenManager) {
      return \`Bearer \${this.tokenManager.getAccessToken()}\`;
    }
    return \`Bearer \${this.machineToken}\`;
  }
`;

// Add before the existing methods
if (!content.includes('setTokenManager')) {
  content = content.replace(
    /(async testConnection\(\))/,
    tokenManagerCode + '\n  $1'
  );
  
  // Update all Authorization headers to use getAuthHeader()
  content = content.replace(
    /'Authorization': `Bearer \${this\.machineToken}`/g,
    "'Authorization': this.getAuthHeader()"
  );
  
  fs.writeFileSync(apiClientPath, content);
  console.log('✅ API client updated to use TokenManager');
} else {
  console.log('ℹ️  API client already uses TokenManager');
}
