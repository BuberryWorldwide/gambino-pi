#!/bin/bash

# Gambino Pi Deployment Package Creator
# Creates a portable package for Pi deployment across multiple mining facilities

set -e

echo "📦 Creating Gambino Pi deployment package..."
echo "============================================="

# Verify we're in the right directory
if [ ! -d "src" ]; then
    echo "❌ Error: Please run this script from your gambino-pi development directory"
    echo "Expected directory structure with 'src' folder"
    exit 1
fi

echo "📂 Working directory: $(pwd)"
echo "✅ Source directory structure confirmed"
echo ""

# Clean and create deployment directory
echo "🧹 Cleaning previous build..."
rm -rf deploy-package
mkdir deploy-package

echo "📁 Copying essential application files..."

# Copy core application files
cp -r src deploy-package/
echo "   ✅ Source code copied"

cp package.json deploy-package/
echo "   ✅ Package dependencies copied"

cp README.md deploy-package/ 2>/dev/null && echo "   ✅ README copied" || echo "   ⚠️  No README found"

# Copy setup and management scripts
echo ""
echo "🔧 Copying setup and management scripts..."
cp setup-pi.sh deploy-package/ 2>/dev/null && echo "   ✅ setup-pi.sh copied" || echo "   ⚠️  No setup-pi.sh found"
cp configure-pi.sh deploy-package/ 2>/dev/null && echo "   ✅ configure-pi.sh copied" || echo "   ⚠️  No configure-pi.sh found"
cp install.sh deploy-package/ 2>/dev/null && echo "   ✅ install.sh copied" || echo "   ⚠️  No install.sh found"
cp gambino-pi-manager.sh deploy-package/ 2>/dev/null && echo "   ✅ Management interface copied" || echo "   ⚠️  No management interface found"
cp unified-manager.sh deploy-package/ 2>/dev/null && echo "   ✅ Unified manager copied" || echo "   ⚠️  No unified manager found"

# Create secure .env template (no real credentials)
echo ""
echo "🔐 Creating configuration template..."
cat > deploy-package/.env.template << 'ENVEOF'
# Gambino Pi Configuration Template
# Copy this to .env and fill in your actual values

# Machine Identity (get from admin dashboard)
MACHINE_ID=hub-mine-facility-rack
STORE_ID=facility_crypto_location
API_ENDPOINT=https://api.gambino.gold
MACHINE_TOKEN=your-jwt-token-from-dashboard

# Hardware Configuration
SERIAL_PORT=/dev/ttyUSB0

# Application Settings
LOG_LEVEL=info
NODE_ENV=production

# Development Override (set to /dev/mock for testing without hardware)
# SERIAL_PORT=/dev/mock
ENVEOF
echo "   ✅ Configuration template created"

# Copy testing and diagnostic tools
echo ""
echo "🧪 Copying testing and diagnostic tools..."
mkdir -p deploy-package/tests
cp tests/testAPI.js deploy-package/tests/ && echo "   ✅ API connectivity test copied" || echo "   ❌ Missing API test"
cp tests/testSerial.js deploy-package/tests/ && echo "   ✅ Serial port test copied" || echo "   ❌ Missing serial test"
cp tests/browseDatabase.js deploy-package/tests/ 2>/dev/null && echo "   ✅ Database browser copied" || echo "   ⚠️  No database browser found"
cp tests/mockMuthaGoose.js deploy-package/tests/ 2>/dev/null && echo "   ✅ Mock data generator copied" || echo "   ⚠️  No mock data generator - RECOMMENDED for testing"

# Create deployment instructions
echo ""
echo "📋 Creating deployment instructions..."
cat > deploy-package/DEPLOYMENT.md << 'DEPLOYEOF'
# Gambino Pi Deployment Instructions

## Quick Start
1. Transfer this package to your Raspberry Pi
2. Extract: `tar -xzf gambino-pi-production.tar.gz`
3. Run setup: `./setup-pi.sh`
4. Configure: Copy `.env.template` to `.env` and edit with your credentials

## Prerequisites
- Raspberry Pi 4 with Raspberry Pi OS Lite
- Network connectivity
- Machine credentials from Gambino admin dashboard

## Files Included
- `src/` - Application source code
- `tests/` - Testing and diagnostic tools
- Setup scripts for automated installation
- Management tools for ongoing operations
- Configuration template

## Support
Run `./gambino-pi-manager.sh` for management interface
DEPLOYEOF
echo "   ✅ Deployment instructions created"

# Create the deployable package
echo ""
echo "📦 Creating deployable archive..."
tar -czf gambino-pi-production.tar.gz -C deploy-package .

# Get package size
package_size=$(du -h gambino-pi-production.tar.gz | cut -f1)

echo ""
echo "🎉 Deployment package created successfully!"
echo "========================================="
echo ""
echo "📊 Package Details:"
echo "   File: gambino-pi-production.tar.gz"
echo "   Size: $package_size"
echo "   Contents: $(tar -tzf gambino-pi-production.tar.gz | wc -l) files"
echo ""
echo "📋 Package Contents Preview:"
tar -tzf gambino-pi-production.tar.gz | head -12
if [ $(tar -tzf gambino-pi-production.tar.gz | wc -l) -gt 12 ]; then
    echo "   ... and $(( $(tar -tzf gambino-pi-production.tar.gz | wc -l) - 12 )) more files"
fi
echo ""
echo "🚀 Deployment Steps:"
echo "   1. Transfer: scp gambino-pi-production.tar.gz pi@your-pi-ip:~/"
echo "   2. SSH to Pi: ssh pi@your-pi-ip"
echo "   3. Extract: tar -xzf gambino-pi-production.tar.gz"
echo "   4. Setup: ./setup-pi.sh"
echo "   5. Configure: cp .env.template .env && nano .env"
echo "   6. Test: npm run test-api"
echo ""
echo "✅ Package ready for deployment to multiple mining facilities!"