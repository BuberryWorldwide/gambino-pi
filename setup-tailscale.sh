#!/bin/bash

# Generate unique machine ID for this clone
echo "Generating unique machine ID..."
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo systemd-machine-id-setup
sudo systemd-machine-id-setup --commit

# Logout any existing session
echo "Clearing existing Tailscale session..."
sudo tailscale logout 2>/dev/null || true
sudo systemctl stop tailscaled 2>/dev/null || true
sudo rm -rf /var/lib/tailscale/* 2>/dev/null || true
sudo systemctl start tailscaled

# Register as new device
AUTHKEY="tskey-auth-ktB8SpvNi321CNTRL-2ZeGc7bncsTEin4obRnasTb8Nwq3hVe4E"
SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 | tail -c 9)

echo "Registering as gambino-pi-${SERIAL}..."
sudo tailscale up \
  --authkey=${AUTHKEY} \
  --hostname=gambino-pi-${SERIAL} \
  --accept-routes

echo "Tailscale setup complete for gambino-pi-${SERIAL}"
tailscale status
