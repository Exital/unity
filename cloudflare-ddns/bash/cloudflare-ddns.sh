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
