#!/bin/bash

echo "Gambino Pi Configuration Manager"
echo "==============================="
echo ""

# Show current configuration
echo "Current Configuration:"
echo "NODE_ENV: $(grep NODE_ENV .env | cut -d'=' -f2)"
echo "SERIAL_PORT: $(grep SERIAL_PORT .env | cut -d'=' -f2)"
echo "MACHINE_ID: $(grep MACHINE_ID .env | cut -d'=' -f2)"
echo ""

echo "Select Configuration Mode:"
echo "1. Development/Testing (mock data)"
echo "2. Production (real serial hardware)"
echo "3. Edit configuration manually"
echo "4. Exit"
echo ""

read -p "Select option (1-4): " choice

case $choice in
    1)
        sed -i 's/NODE_ENV=.*/NODE_ENV=development/' .env
        sed -i 's/SERIAL_PORT=.*/SERIAL_PORT=\/dev\/mock/' .env
        echo "✅ Switched to development mode (mock data)"
        ;;
    2)
        echo "Available serial devices:"
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No USB serial devices found"
        read -p "Serial port (default: /dev/ttyUSB0): " port
        port=${port:-/dev/ttyUSB0}
        sed -i 's/NODE_ENV=.*/NODE_ENV=production/' .env
        sed -i "s|SERIAL_PORT=.*|SERIAL_PORT=$port|" .env
        echo "✅ Switched to production mode ($port)"
        ;;
    3)
        nano .env
        echo "✅ Configuration file edited"
        ;;
    4)
        echo "No changes made"
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "Restart the service to apply changes:"
echo "sudo systemctl restart gambino-pi"
