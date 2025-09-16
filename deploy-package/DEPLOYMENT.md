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
