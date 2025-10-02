#!/bin/bash

echo "Gambino Pi Setup Wizard"
echo "======================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "Please run as regular user (not root)"
  exit 1
fi

# Install system dependencies
echo "Installing system dependencies..."
sudo apt update
sudo apt install -y nodejs npm git vim

# Install PM2 for process management
sudo npm install -g pm2

# Create application directory
sudo mkdir -p /opt/gambino-pi
sudo chown $USER:$USER /opt/gambino-pi

# Extract application if archive exists
if [ -f "gambino-pi-production.tar.gz" ]; then
  echo "Extracting application..."
  tar -xzf gambino-pi-production.tar.gz -C /opt/gambino-pi
  cd /opt/gambino-pi
else
  echo "Please place gambino-pi-production.tar.gz in current directory"
  exit 1
fi

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install

# Interactive configuration
echo ""
echo "Configuration Setup"
echo "=================="
echo ""

read -p "Machine ID (e.g., hub-casino1-floor2): " MACHINE_ID
read -p "Store ID (e.g., store_casino1_downtown): " STORE_ID
read -p "API Endpoint (default: https://api.gambino.gold): " API_ENDPOINT
API_ENDPOINT=${API_ENDPOINT:-https://api.gambino.gold}

echo ""
echo "Machine Token Setup:"
echo "1. Go to your admin dashboard"
echo "2. Find or create machine: $MACHINE_ID"
echo "3. Get connection info and copy the machine token"
echo ""
read -p "Paste machine token here: " MACHINE_TOKEN

echo ""
echo "Serial Port Configuration:"
echo "Available serial devices:"
ls /dev/ttyUSB* /dev/ttyACM* /dev/serial/by-id/* 2>/dev/null || echo "No USB serial devices found"
echo ""
read -p "Serial port path (default: /dev/ttyUSB0): " SERIAL_PORT
SERIAL_PORT=${SERIAL_PORT:-/dev/ttyUSB0}

# Create .env file
cat > .env << EOL
# Gambino Pi Configuration
MACHINE_ID=$MACHINE_ID
STORE_ID=$STORE_ID
API_ENDPOINT=$API_ENDPOINT
MACHINE_TOKEN=$MACHINE_TOKEN

# Serial Configuration
SERIAL_PORT=$SERIAL_PORT

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=production
EOL

echo ""
echo "Configuration saved to .env"

# Set up USB serial permissions
echo "Setting up USB serial permissions..."
sudo usermod -a -G dialout $USER

# Create systemd service
echo "Creating system service..."
sudo tee /etc/systemd/system/gambino-pi.service > /dev/null << EOL
[Unit]
Description=Gambino Pi Edge Device
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/opt/gambino-pi
Environment=NODE_ENV=production
ExecStart=/usr/bin/node src/main.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=gambino-pi

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable gambino-pi

echo ""
echo "Setup Complete!"
echo "=============="
echo ""
echo "Next steps:"
echo "1. Test configuration: npm run test-api"
echo "2. Test serial connection: npm run test-serial"
echo "3. Start service: sudo systemctl start gambino-pi"
echo "4. Check status: sudo systemctl status gambino-pi"
echo "5. View logs: sudo journalctl -u gambino-pi -f"
echo ""
echo "The service will auto-start on boot."
echo ""
