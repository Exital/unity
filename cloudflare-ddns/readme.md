# Cloudflare Dynamic DNS (DDNS) with Kubernetes CronJob

## Overview

This project sets up a Kubernetes CronJob to automatically update Cloudflare DNS records with the current public IP address of your Kubernetes cluster. 
Dynamic DNS (DDNS) is essential for scenarios where your external IP address changes frequently, such as home internet connections or dynamic cloud environments.

## Why DDNS with Cloudflare?
Automation: Automatically update DNS records when your IP address changes, eliminating manual updates.
High Availability: Ensure your services remain accessible with up-to-date DNS records.
Security: Use Kubernetes secrets to securely store sensitive Cloudflare credentials.
## Kubernetes Objects Used
1. **Secrets:** Kubernetes secrets are used to store sensitive information such as Cloudflare credentials (auth_email, auth_key, etc.) securely.

2. **ConfigMap:** A ConfigMap is used to store the bash script (ddns-update.py) that interacts with Cloudflare API and performs DNS updates.

3. **CronJob:** The CronJob object is configured to run the ddns-update.sh script at specified intervals (schedule: "*/5 * * * *" in this example) to ensure DNS records are regularly updated.

## steps:

1. Create Kubernetes Secrets
Create Kubernetes secrets to store Cloudflare API credentials and other sensitive data:
