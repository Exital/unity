#!/bin/bash

# External parameters passed to the script
SCRIPT_NAME="$1"
TIMER=${2:-"5min"}

# Check if SCRIPT_NAME is provided
if [ -z "$SCRIPT_NAME" ]; then
  echo "Error: SCRIPT_NAME argument is required."
  echo "Usage: $0 <SCRIPT_NAME> [TIMER]"
  exit 1
fi


# Internal parameters
SCRIPT_PATH="$(readlink -f "$1")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"  # Extract only the filename (e.g., monitor_pci.sh)
SERVICE_NAME="${SCRIPT_NAME%.sh}"  # Remove the .sh extension
LOCAL_SCRIPT_PATH="/usr/local/bin/$SERVICE_NAME.sh"

SYSTEMD_DIR="/etc/systemd/system"

# Display the parameters
echo "SCRIPT_NAME: $SCRIPT_NAME"
echo "SCRIPT_PATH: $SCRIPT_PATH"
echo "SERVICE_NAME: $SERVICE_NAME"
echo "LOCAL_SCRIPT_PATH: $LOCAL_SCRIPT_PATH"

# Remove existing service and timer (if they exist)
echo "Removing existing service and timer if they exist..."
systemctl stop "${SERVICE_NAME}.service" 2>/dev/null
systemctl stop "${SERVICE_NAME}.timer" 2>/dev/null
systemctl disable "${SERVICE_NAME}.service" 2>/dev/null
systemctl disable "${SERVICE_NAME}.timer" 2>/dev/null
rm -f "${SYSTEMD_DIR}/${SERVICE_NAME}.service" "${SYSTEMD_DIR}/${SERVICE_NAME}.timer"

# Copy the script to local path
echo "Copying $SCRIPT_PATH to $LOCAL_SCRIPT_PATH"
sudo cp "$SCRIPT_PATH" "$LOCAL_SCRIPT_PATH"
sudo chmod +x "$LOCAL_SCRIPT_PATH"

# Create systemd service file
cat << EOF > "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
[Unit]
Description=${SERVICE_NAME} service
After=network.target

[Service]
ExecStart=$LOCAL_SCRIPT_PATH
Restart=on-failure
EOF

# Create systemd timer file
cat << EOF > "${SYSTEMD_DIR}/${SERVICE_NAME}.timer"
[Unit]
Description=Run check on ${SERVICE_NAME} status every ${TIMER}

[Timer]
OnBootSec=1min
OnUnitActiveSec=${TIMER}
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=multi-user.target
EOF

echo "Reload systemd, enable and start the timer"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.timer"
systemctl start "${SERVICE_NAME}.timer"
systemctl start "${SERVICE_NAME}.service"
