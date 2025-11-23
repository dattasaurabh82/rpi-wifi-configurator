#!/bin/bash

echo "Setting up WiFi Manager Service..."

# 1. Create systemd user directory
mkdir -p ~/.config/systemd/user/

# 2. Get the script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 3. Replace __INSTALL_DIR__ placeholder with actual path
sed "s|__INSTALL_DIR__|$SCRIPT_DIR|g" "$SCRIPT_DIR/rpi-btn-wifi-manager.service" > ~/.config/systemd/user/rpi-btn-wifi-manager.service

# 4. Reload systemd daemon and enable service
systemctl --user daemon-reload
systemctl --user enable rpi-btn-wifi-manager.service

echo "Service setup complete! You can start it with: systemctl --user start rpi-btn-wifi-manager"
