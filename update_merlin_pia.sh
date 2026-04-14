#!/bin/bash
# Enable strict error handling: exit on error, undefined vars, or pipe failures
set -euo pipefail

echo "Activating virtual environment and generating config..."
source ./venv/bin/activate
python generate-config.py

# Find the generated .conf file safely
CONFIG_FILE=$(find . -maxdepth 1 -name "*.conf" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -f2- -d" ")

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Error: No .conf file found. Exiting."
    exit 1
fi

echo "CONFIG_FILE: $CONFIG_FILE"

# Parse the generated configuration file cleanly using awk
# Parse the generated configuration file cleanly using awk
# sub(/^[^=]+=[ \t]*/, "") strips everything before and including the first '=', plus leading spaces
# sub(/[ \t]+$/, "") strips any trailing spaces at the end of the line
ADDRESS=$(awk 'tolower($0) ~ /^address[ \t]*=/ {sub(/^[^=]+=[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit}' "$CONFIG_FILE")
PRIVATE_KEY=$(awk 'tolower($0) ~ /^privatekey[ \t]*=/ {sub(/^[^=]+=[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit}' "$CONFIG_FILE")
DNS=$(awk 'tolower($0) ~ /^dns[ \t]*=/ {sub(/^[^=]+=[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit}' "$CONFIG_FILE")
PUB_KEY=$(awk 'tolower($0) ~ /^publickey[ \t]*=/ {sub(/^[^=]+=[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit}' "$CONFIG_FILE")
ENDPOINT=$(awk 'tolower($0) ~ /^endpoint[ \t]*=/ {sub(/^[^=]+=[ \t]*/, ""); sub(/[ \t]+$/, ""); print; exit}' "$CONFIG_FILE")

ENDPOINT_ADDR=${ENDPOINT%:*}
ENDPOINT_PORT=${ENDPOINT##*:}

echo "Parsed values:"
echo "  Address:           $ADDRESS"
echo "  PrivateKey:        $PRIVATE_KEY"
echo "  DNS:               $DNS"
echo "  PublicKey:         $PUB_KEY"
echo "  Endpoint:          $ENDPOINT"
echo "  Endpoint Address:  $ENDPOINT_ADDR"
echo "  Endpoint Port:     $ENDPOINT_PORT"

# Read router credentials from the YAML file
ROUTER_IP=$(awk '/^ *ip:/ {print $2}' router.yaml)
ROUTER_USERNAME=$(awk '/^ *username:/ {print $2}' router.yaml)
ROUTER_PASSWORD=$(awk '/^ *password:/ {print $2}' router.yaml)

echo "Router credentials:"
echo "  IP:       $ROUTER_IP"
echo "  Username: $ROUTER_USERNAME"

# Build the SSH command with strict quoting for Base64 keys
SSH_CMD="
nvram set wgc1_desc='PIA-WG'; nvram set wgc_desc='PIA-WG'; \
nvram set wgc1_addr='${ADDRESS}'; nvram set wgc_addr='${ADDRESS}'; \
nvram set wgc1_priv='${PRIVATE_KEY}'; nvram set wgc_priv='${PRIVATE_KEY}'; \
nvram set wgc1_dns='${DNS}'; nvram set wgc_dns='${DNS}'; \
nvram set wgc1_ppub='${PUB_KEY}'; nvram set wgc_ppub='${PUB_KEY}'; \
nvram set wgc1_ep_addr='${ENDPOINT_ADDR}'; nvram set wgc1_ep_addr_r='${ENDPOINT_ADDR}'; nvram set wgc_ep_addr='${ENDPOINT_ADDR}'; \
nvram set wgc1_ep_port='${ENDPOINT_PORT}'; nvram set wgc_ep_port='${ENDPOINT_PORT}'; \
nvram set wgc_aips='0.0.0.0/0'; nvram set wgc1_aips='0.0.0.0/0'; \
nvram commit
"

echo "Updating nvram on router..."
sshpass -p "${ROUTER_PASSWORD}" ssh -o StrictHostKeyChecking=no "${ROUTER_USERNAME}@${ROUTER_IP}" "${SSH_CMD}"

echo "nvram update complete."

# Target only the file we actually processed
rm "$CONFIG_FILE"
echo "Cleaned up $CONFIG_FILE."