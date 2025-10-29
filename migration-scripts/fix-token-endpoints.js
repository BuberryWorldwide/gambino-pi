const fs = require('fs');

const tokenManagerPath = './src/utils/tokenManager.js';
let content = fs.readFileSync(tokenManagerPath, 'utf8');

// Fix the token status endpoint - add /api
content = content.replace(
  /\$\{this\.apiBaseUrl\}\/token\/status/g,
  '${this.apiBaseUrl}/api/token/status'
);

content = content.replace(
  /\$\{this\.apiBaseUrl\}\/token\/refresh/g,
  '${this.apiBaseUrl}/api/token/refresh'
);

fs.writeFileSync(tokenManagerPath, content);
console.log('✅ Token endpoints fixed to include /api');
