const fs = require('fs');

const indexPath = './index.js';
let content = fs.readFileSync(indexPath, 'utf8');

// Add TokenManager import at the top (after other requires)
if (!content.includes('TokenManager')) {
  const importLine = "const TokenManager = require('./src/utils/tokenManager');\n";
  content = content.replace(
    /(const.*require.*apiClient.*\n)/,
    '$1' + importLine
  );
  
  // Add token manager initialization in main function
  const tokenManagerInit = `
  // Initialize token manager for auto-refresh
  const tokenManager = new TokenManager(API_BASE_URL);
  await tokenManager.init();
  apiClient.setTokenManager(tokenManager);
  console.log('🔑 Token auto-refresh enabled');
  `;
  
  content = content.replace(
    /(apiClient\.testConnection\(\);)/,
    '$1\n' + tokenManagerInit
  );
  
  fs.writeFileSync(indexPath, content);
  console.log('✅ index.js updated with TokenManager');
} else {
  console.log('ℹ️  TokenManager already integrated');
}
