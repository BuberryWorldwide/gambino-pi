#!/bin/bash
echo "📦 Creating Gambino Pi deployment package..."

# Create clean deployment directory
rm -rf deploy-package
mkdir deploy-package

# Copy essential application files
cp -r src deploy-package/
cp package.json deploy-package/
cp README.md deploy-package/ 2>/dev/null || echo "No README found"

# Copy setup and configuration scripts
cp setup-pi.sh deploy-package/ 2>/dev/null || echo "No setup-pi.sh found"
cp configure-pi.sh deploy-package/ 2>/dev/null || echo "No configure-pi.sh found"
cp install.sh deploy-package/ 2>/dev/null || echo "No install.sh found"

# Create .env template instead of copying real .env
cat > deploy-package/.env.template << 'ENVEOF'
# Gambino Pi Configuration
MACHINE_ID=your-machine-id-here
STORE_ID=your-store-id-here
API_ENDPOINT=https://api.gambino.gold
MACHINE_TOKEN=your-jwt-token-here

# Serial Configuration
SERIAL_PORT=/dev/mock

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=development
ENVEOF

# Copy ALL essential test files
mkdir deploy-package/tests
cp tests/testAPI.js deploy-package/tests/
cp tests/testSerial.js deploy-package/tests/
cp tests/browseDatabase.js deploy-package/tests/ 2>/dev/null || echo "No browseDatabase.js found"
cp tests/mockMuthaGoose.js deploy-package/tests/ 2>/dev/null || echo "No mockMuthaGoose.js found - REQUIRED for testing"

# Create production package
tar -czf gambino-pi-production.tar.gz -C deploy-package .

echo "✅ Production package created: gambino-pi-production.tar.gz"
echo "📋 Contents:"
tar -tzf gambino-pi-production.tar.gz | head -10
echo "..."
echo ""
echo "📋 To deploy:"
echo "1. Transfer: scp gambino-pi-production.tar.gz pi@your-pi-ip:~/"
echo "2. Extract: tar -xzf gambino-pi-production.tar.gz"
echo "3. Setup: ./setup-pi.sh"
echo "4. Configure: ./configure-pi.sh (to switch dev/prod modes)"
