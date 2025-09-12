# Gambino Pi Edge Device

A Raspberry Pi application that captures real-time machine data from Mutha Goose hubs and transmits it to the Gambino backend for analytics and user attribution.

## System Overview

```
Machines → Mutha Goose Hub → Pi (Serial) → Backend API → Database
    (1-99)           (Port B)       (USB)       (HTTPS)      (MongoDB)
```

The Pi monitors all machine transactions via serial connection and provides:
- Real-time transaction capture (vouchers, money in, collect, sessions)
- Offline data buffering with automatic sync when connectivity returns
- User attribution for bound sessions
- Health monitoring and error recovery

## Hardware Requirements

- Raspberry Pi 4 Model B (4GB RAM recommended)
- MicroSD card (32GB minimum, Class 10)
- USB-to-Serial adapter (FTDI chipset recommended)
- Ethernet connection or WiFi
- Power supply (USB-C, 3A)

## Software Prerequisites

- Ubuntu Server 22.04 LTS (recommended)
- Node.js 18+ LTS
- Internet connection for initial setup

## Installation

### 1. Prepare Raspberry Pi
- Flash Ubuntu Server 22.04 to SD card
- Enable SSH and configure network
- Update system: `sudo apt update && sudo apt upgrade -y`

### 2. Deploy Application
```bash
# Transfer deployment package to Pi
scp gambino-pi-production.tar.gz pi@your-pi-ip:~/

# SSH into Pi
ssh pi@your-pi-ip

# Extract application
tar -xzf gambino-pi-production.tar.gz
cd gambino-pi

# Run interactive setup
./setup-pi.sh
```

### 3. Configuration
The setup wizard will prompt for:
- **Machine ID**: Unique identifier for this Pi/hub (e.g., `hub-casino1-floor2`)
- **Store ID**: Location identifier from admin dashboard
- **API Endpoint**: Backend URL (default: `https://api.gambino.gold`)
- **Machine Token**: JWT token from admin dashboard
- **Serial Port**: USB-to-Serial device path (default: `/dev/ttyUSB0`)

### 4. Hardware Connection
- Connect USB-to-Serial adapter to Pi
- Connect adapter to Mutha Goose **Port B** (DB-9 connection)
- Verify connection: `ls -la /dev/ttyUSB*`

## Machine ID Naming Standard

Machine IDs must follow this format for consistency across all installations:

### Format
{type}-{location}-{identifier}

### Examples
- `hub-casino1-floor1` - First floor hub at Casino 1
- `hub-downtown-main` - Main hub at downtown location
- `hub-riverboat-deck2` - Second deck hub on riverboat
- `hub-slots-section-a` - Section A hub in slots area
- `hub-mgm-vegas-north` - North wing hub at MGM Las Vegas

### Rules
- **Type**: Always use "hub" (represents the Pi/Mutha Goose hub)
- **Location**: Business or venue identifier (no spaces)
- **Identifier**: Floor, section, or area designation
- Use lowercase letters and numbers only
- Separate components with hyphens (-)
- No spaces or special characters (@, #, _, etc.)
- Maximum 30 characters
- Must be globally unique across all installations

### Store ID Coordination
Ensure your Machine ID corresponds to the correct Store ID in the admin dashboard:
- Machine ID: `hub-casino1-floor1`
- Store ID: `store_casino1_downtown`
- Both should reference the same physical location

## Management

Use the management script for ongoing operations:
```bash
./manage-pi.sh
```

### Manual Commands
```bash
# Check service status
sudo systemctl status gambino-pi

# View live logs
sudo journalctl -u gambino-pi -f

# Restart service
sudo systemctl restart gambino-pi

# Test API connection
npm run test-api

# Browse local database
npm run browse-db
```

## Testing

### API Connectivity
```bash
npm run test-api
```
Should show successful connection to backend and proper authentication.

### Serial Port Detection
```bash
npm run test-serial
```
Lists available serial devices. USB-to-Serial adapter should appear as `/dev/ttyUSB0` or similar.

### Local Database
```bash
npm run browse-db
```
Interactive browser to view captured events and sync status.

## Data Flow

### Event Types Captured
- **Voucher**: Player winnings printed (`VOUCHER PRINT: $50.00 - MACHINE 03`)
- **Money In**: Credits added (`MONEY IN: $25.00 - MACHINE 03`)
- **Collect**: Player cashouts (`COLLECT: $75.00 - MACHINE 03`)
- **Sessions**: Session start/end tracking

### User Attribution
When players bind their accounts to machines via QR codes:
- **Bound sessions**: Events attributed to user accounts
- **Unbound sessions**: Anonymous analytics only
- **Backend determines attribution** based on active machine bindings

### Offline Resilience
- All events stored locally in SQLite database
- Automatic sync when internet connectivity returns
- No data lost during network outages
- Queue management with retry logic

## Troubleshooting

### Common Issues

**Serial Connection Problems**
```bash
# Check USB devices
lsusb

# Check serial permissions
groups $USER  # Should include 'dialout'

# Add user to dialout group if missing
sudo usermod -a -G dialout $USER
# Logout and login again
```

**API Connection Failures**
```bash
# Test internet connectivity
ping api.gambino.gold

# Check machine token validity
# Go to admin dashboard and regenerate if needed

# Verify .env configuration
cat /opt/gambino-pi/.env
```

**Service Won't Start**
```bash
# Check service logs
sudo journalctl -u gambino-pi -n 50

# Check file permissions
sudo chown -R $USER:$USER /opt/gambino-pi

# Reinstall dependencies
cd /opt/gambino-pi && npm install
```

### Log Locations
- **System logs**: `sudo journalctl -u gambino-pi`
- **Application logs**: `/opt/gambino-pi/logs/`
- **Database**: `/opt/gambino-pi/data/gambino-pi.db`

## File Structure
```
/opt/gambino-pi/
├── src/
│   ├── api/          # Backend communication
│   ├── database/     # Local SQLite management
│   ├── serial/       # Mutha Goose data parsing
│   ├── sync/         # Offline sync management
│   ├── health/       # System monitoring
│   └── main.js       # Application entry point
├── tests/            # Testing utilities
├── data/             # Local database storage
├── logs/             # Application logs
├── .env              # Configuration
└── package.json      # Dependencies
```

## Security

- Machine tokens expire after 1 year
- All API communication uses HTTPS
- Local database contains no sensitive user information
- Serial communication is read-only from Mutha Goose

## Maintenance

### Regular Tasks
- Monitor disk space: `df -h`
- Check log rotation: `ls -la /opt/gambino-pi/logs/`
- Verify sync status: `npm run browse-db`
- Update system: `sudo apt update && sudo apt upgrade`

### Token Renewal
When machine tokens expire:
1. Generate new token in admin dashboard
2. Update `/opt/gambino-pi/.env`
3. Restart service: `sudo systemctl restart gambino-pi`

## Support

For technical issues:
1. Check logs: `sudo journalctl -u gambino-pi -f`
2. Run diagnostics: `./manage-pi.sh` → option 7
3. Verify configuration: Check `.env` file
4. Test components: API, serial, database tests

## Version Info

- Application: Gambino Pi Edge Device v1.0
- Node.js: 18+ LTS required
- Database: SQLite with WAL mode
- Communication: RS-232 serial, HTTPS API
```

Run `./deploy-to-pi.sh` again to include new files in your deployment package.