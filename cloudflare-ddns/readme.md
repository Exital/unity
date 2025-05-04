# Cloudflare Dynamic DNS (DDNS)

## Table of Contents
- [Overview](#overview)
- [Why DDNS with Cloudflare?](#why-ddns-with-cloudflare)
- [Option 1: Kubernetes CronJob](#option-1-kubernetes-cronjob)
  - [Kubernetes Objects Used](#kubernetes-objects-used)
  - [Steps](#steps)
- [Option 2: Standalone Bash Service (Systemd)](#option-2-standalone-bash-service-systemd)
  - [Steps](#steps-1)

## Overview

This project sets up a Kubernetes CronJob to automatically update Cloudflare DNS records with the current public IP address of your Kubernetes cluster. 
Dynamic DNS (DDNS) is essential for scenarios where your external IP address changes frequently, such as home internet connections or dynamic cloud environments.

## Why DDNS with Cloudflare?
Automation: Automatically update DNS records when your IP address changes, eliminating manual updates.
High Availability: Ensure your services remain accessible with up-to-date DNS records.
Security: Use secrets to securely store sensitive Cloudflare credentials.

## Option 1: Kubernetes CronJob

### Kubernetes Objects Used
1. **Secrets:** Kubernetes secrets are used to store sensitive information such as Cloudflare credentials (auth_email, auth_key, etc.) securely.

2. **ConfigMap:** A ConfigMap is used to store the bash script (ddns-update.py) that interacts with Cloudflare API and performs DNS updates.

3. **CronJob:** The CronJob object is configured to run the ddns-update.sh script at specified intervals (schedule: "*/5 * * * *" in this example) to ensure DNS records are regularly updated.

### steps:
1. **Create cloudflare-ddns namespace**
```bash
kubectl create namespace cloudflare-ddns
```  

2. **Create Kubernetes Secrets**
Create and apply Kubernetes secrets to store Cloudflare API credentials and other sensitive data - **make sure to use base64 and sealed secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-ddns-secrets
  namespace: cloudflare-ddns
type: Opaque
data:
  auth_email: <The email used to login 'https://dash.cloudflare.com'>
  auth_method: <Set to "global" for Global API Key or "token" for Scoped API Token >
  auth_key: <Your API Token or Global API Key>
  zone_identifier: <Can be found in the "Overview" tab of your domain>
  record_name: <Which record you want to be synced>
  ttl: <Set the DNS TTL (seconds)> # for example "3600"
  proxy: <Set the proxy to true or false> # use true
```

3. **Create and apply Kubernetes configMap for the ddns python script**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ddns-update-script
  namespace: cloudflare-ddns
data:
  ddns-update.py: |
    import os
    import re
    import requests
    import json
    import logging

    # Load environment variables
    auth_email = os.getenv('auth_email')
    auth_method = os.getenv('auth_method')
    auth_key = os.getenv('auth_key')
    zone_identifier = os.getenv('zone_identifier')
    record_name = os.getenv('record_name')
    ttl = int(os.getenv('ttl'))
    proxy = os.getenv('proxy')

    # Define regex pattern for IPv4 validation
    ipv4_regex = r'([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'

    # Function to get public IP
    def get_public_ip():
        ip = None
        try:
            # Attempt to get IP from Cloudflare
            response = requests.get('https://cloudflare.com/cdn-cgi/trace')
            if response.status_code == 200:
                ip_match = re.search(r'^ip=(\d+\.\d+\.\d+\.\d+)', response.text, flags=re.MULTILINE)
                if ip_match:
                    ip = ip_match.group(1)
        except Exception as e:
            logging.error(f"Failed to retrieve IP from Cloudflare: {str(e)}")

        if not ip:
            # If Cloudflare fails, try other services
            try:
                response = requests.get('https://api.ipify.org')
                if response.status_code == 200:
                    ip = response.text.strip()
                else:
                    response = requests.get('https://ipv4.icanhazip.com')
                    if response.status_code == 200:
                        ip = response.text.strip()
            except Exception as e:
                logging.error(f"Failed to retrieve IP from alternative services: {str(e)}")

        return ip

    # Function to update Cloudflare record
    def update_cloudflare_record(ip):
        if not re.match(ipv4_regex, ip):
            logging.error(f"Invalid IP format: {ip}")
            return False

        auth_header = "X-Auth-Key" if auth_method == "global" else "Authorization"
        headers = {
            "X-Auth-Email": auth_email,
            auth_header: auth_key,
            "Content-Type": "application/json"
        }

        try:
            # Fetch DNS record
            response = requests.get(f"https://api.cloudflare.com/client/v4/zones/{zone_identifier}/dns_records?type=A&name={record_name}", headers=headers)
            if response.status_code != 200:
                logging.error(f"Failed to fetch DNS record: {response.text}")
                return False

            record_data = response.json()
            if record_data['result_info']['count'] == 0:
                logging.error(f"Record does not exist: {record_name}")
                return False

            # Extract existing IP
            old_ip = record_data['result'][0]['content']

            # Compare IPs
            if ip == old_ip:
                logging.info(f"IP ({ip}) for {record_name} has not changed.")
                return True

            # Update IP
            record_id = record_data['result'][0]['id']
            update_data = {
                "type": "A",
                "name": record_name,
                "content": ip,
                "ttl": ttl,
                "proxied": bool(proxy)
            }
            response = requests.put(f"https://api.cloudflare.com/client/v4/zones/{zone_identifier}/dns_records/{record_id}", headers=headers, json=update_data)
            if response.status_code != 200:
                logging.error(f"Failed to update DNS record: {response.text}")
                return False

            logging.info(f"Updated IP for {record_name} from {old_ip} to {ip}")
            return True

        except Exception as e:
            logging.error(f"Exception occurred: {str(e)}")
            return False

    # Main script execution
    if __name__ == "__main__":
        logging.basicConfig(level=logging.INFO)

        # Get public IP
        public_ip = get_public_ip()
        if not public_ip:
            logging.error("Failed to retrieve public IP.")
            exit(1)

        # Update Cloudflare record
        if not update_cloudflare_record(public_ip):
            exit(1)
```

4. **Create and apply Kubernetes cronJob for scheduling the job**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cloudflare-ddns-cronjob
  namespace: cloudflare-ddns
spec:
  schedule: "*/5 * * * *"  # Cron schedule (runs every 5 minutes in this example)
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cloudflare-ddns-container
            image: python:3-slim
            command:
              - sh
              - -c
              - |
                cp /bin/ddns-update.py /tmp/ddns-update.py && \
                chmod +x /tmp/ddns-update.py && \
                pip install requests && \
                python /tmp/ddns-update.py
            volumeMounts:
            - name: script-volume
              mountPath: /bin/ddns-update.py
              subPath: ddns-update.py
              readOnly: true
            envFrom:
            - secretRef:
                name: cloudflare-ddns-secrets
          restartPolicy: OnFailure
          volumes:
          - name: script-volume
            configMap:
              name: ddns-update-script
```

## Option 2: Standalone Bash Service (Systemd)

### steps:
1. **Create a secrets file (restricted access):**

```bash
sudo mkdir -p /etc/cloudflare-ddns
sudo nano /etc/cloudflare-ddns/secret.env
```

Contents:
```bash
auth_email=<The email used to login 'https://dash.cloudflare.com'>
auth_method=<Set to "global" for Global API Key or "token" for Scoped API Token>
auth_key=<Your API Token or Global API Key>
zone_identifier=<Can be found in the "Overview" tab of your domain>
record_name=<Which record you want to be synced>
ttl=<Set the DNS TTL (seconds)> # for example "3600"
proxy=<Set the proxy to true or false> # use true
```
Set strict permissions:
```bash
sudo chmod 600 /etc/cloudflare-ddns/secret.env
sudo chown root:root /etc/cloudflare-ddns/secret.env
```
2. **Create the cloudflare-ddns script:**
```bash
sudo nano /etc/cloudflare-ddns/cloudflare-ddns.sh
```
contents:
```bash
#!/bin/bash
set -e

# Load secrets
source /etc/cloudflare-ddns/secret.env

# Get public IP
public_ip=$(curl -s https://cloudflare.com/cdn-cgi/trace | grep '^ip=' | cut -d= -f2)

if [[ -z "$public_ip" ]]; then
  public_ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
fi

# Check IP validity
if [[ ! "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Invalid IP: $public_ip"
  exit 1
fi

# Auth header
if [[ "$auth_method" == "global" ]]; then
  auth_header="X-Auth-Key: $auth_key"
else
  auth_header="Authorization: Bearer $auth_key"
fi

# Get current record
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
  -H "X-Auth-Email: $auth_email" \
  -H "$auth_header" \
  -H "Content-Type: application/json")

old_ip=$(echo "$response" | jq -r '.result[0].content')
record_id=$(echo "$response" | jq -r '.result[0].id')

if [[ "$old_ip" == "$public_ip" ]]; then
  echo "IP unchanged: $public_ip"
  exit 0
fi

# Update IP
update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_id" \
  -H "X-Auth-Email: $auth_email" \
  -H "$auth_header" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$public_ip\",\"ttl\":$ttl,\"proxied\":$proxy}")

echo "Updated IP from $old_ip to $public_ip"
```
3. **Copy the install script:**
```bash
nano /tmp/install_with_timer.sh
```
contents:
```bash
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
```
Install the cloudflare-ddns service:
```bash
chmod +x /tmp/install_with_timer.sh
sudo /tmp/install_with_timer.sh /etc/cloudflare-ddns/cloudflare-ddns.sh 1min
```


