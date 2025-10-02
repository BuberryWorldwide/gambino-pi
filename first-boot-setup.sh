#!/bin/bash

# First Boot Setup for Cloned Pi
# Run this script on first boot of a cloned Pi device

set -e

echo "🚀 Gambino Pi First Boot Setup"
echo "============================="

# Check if already configured
if [ -f ".env" ]; then
    echo "❌ Pi appears to be already configured."
    echo "Delete .env file to reconfigure, or run:"
    echo "rm .env && ./first-boot-setup.sh"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f ".env.template" ] || [ ! -d "src" ]; then
    echo "❌ Please run this script from the gambino-pi-app directory"
    exit 1
fi

echo ""
echo "📋 Configuration Setup"
echo "---------------------"

# Copy template to active config
cp .env.template .env

echo ""
read -p "Machine ID (e.g., hub-casino1-floor2): " MACHINE_ID
read -p "Store ID: " STORE_ID
echo ""
echo "🔐 Get your machine token from the admin dashboard:"
echo "   1. Login to admin dashboard"
echo "   2. Find or create machine: $MACHINE_ID"
echo "   3. Copy the connection token"
echo ""
read -p "Machine Token: " MACHINE_TOKEN

# Update configuration
sed -i "s/MACHINE_ID=CHANGE_ME/MACHINE_ID=$MACHINE_ID/" .env
sed -i "s/STORE_ID=CHANGE_ME/STORE_ID=$STORE_ID/" .env
sed -i "s/MACHINE_TOKEN=CHANGE_ME/MACHINE_TOKEN=$MACHINE_TOKEN/" .env

echo ""
echo "✅ Configuration saved!"
echo ""
echo "🔧 Installing dependencies..."
npm install

echo ""
echo "🧪 Testing configuration..."
npm run test-api

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Set up WiFi: sudo raspi-config (if needed)"
echo "2. Set up Tailscale: curl -fsSL https://tailscale.com/install.sh | sh"
echo "3. Test serial connection: npm run test-serial"
echo "4. Start service: npm start"
echo ""
echo "For management, use: ./manager.sh"
