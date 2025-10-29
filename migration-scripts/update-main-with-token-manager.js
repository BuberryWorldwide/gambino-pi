const fs = require('fs');

const mainPath = './src/main.js';
let content = fs.readFileSync(mainPath, 'utf8');

// Add TokenManager import at the top (after other requires)
if (!content.includes('TokenManager')) {
  const importLine = "const TokenManager = require('./utils/tokenManager');\n";
  
  // Find a good place to add it (after other requires)
  content = content.replace(
    /(const.*APIClient.*\n)/,
    '$1' + importLine
  );
  
  // Add token manager initialization in the main function
  const tokenManagerInit = `
  // Initialize token manager for auto-refresh
  const tokenManager = new TokenManager(config.apiBaseUrl);
  await tokenManager.init();
  apiClient.setTokenManager(tokenManager);
  console.log('🔑 Token auto-refresh enabled');
  `;
  
  // Add after API client is created
  content = content.replace(
    /(apiClient = new APIClient\(config\);[\s\S]*?console\.log\('API connection verified'\);)/,
    '$1\n' + tokenManagerInit
  );
  
  fs.writeFileSync(mainPath, content);
  console.log('✅ src/main.js updated with TokenManager');
} else {
  console.log('ℹ️  TokenManager already integrated');
}
