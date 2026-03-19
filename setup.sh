#!/bin/bash
# ~/pruner4n8n/setup.sh

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SERVICE_NAME="n8n-pruner"

echo "Configuring Systemd units for user $USER in $SCRIPT_DIR..."

# 1. Update paths and User in the .service file
sed -i "s|ExecStart=.*|ExecStart=$SCRIPT_DIR/run_prune.sh|g" "$SCRIPT_DIR/$SERVICE_NAME.service"
sed -i "s|User=.*|User=$USER|g" "$SCRIPT_DIR/$SERVICE_NAME.service"
sed -i "s|Group=.*|Group=docker|g" "$SCRIPT_DIR/$SERVICE_NAME.service"

# 2. Symlink to system directory
sudo ln -sf "$SCRIPT_DIR/$SERVICE_NAME.service" "/etc/systemd/system/$SERVICE_NAME.service"
sudo ln -sf "$SCRIPT_DIR/$SERVICE_NAME.timer" "/etc/systemd/system/$SERVICE_NAME.timer"

# 3. Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME.timer"

echo "------------------------------------------------"
echo "Setup complete. The pruner will run daily at 03:00."
systemctl status "$SERVICE_NAME.timer"

