const fs = require('fs');

const tokenManagerPath = './src/utils/tokenManager.js';
let content = fs.readFileSync(tokenManagerPath, 'utf8');

// Fix the token status endpoint to not add /api twice
content = content.replace(
  /\$\{this\.apiBaseUrl\}\/api\/token\/status/g,
  '${this.apiBaseUrl}/token/status'
);

content = content.replace(
  /\$\{this\.apiBaseUrl\}\/api\/token\/refresh/g,
  '${this.apiBaseUrl}/token/refresh'
);

fs.writeFileSync(tokenManagerPath, content);
console.log('✅ TokenManager URLs fixed');
