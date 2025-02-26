#!/bin/bash
# Activate the virtual environment and run the config generator
source venv/bin/activate
python generate-config.py

# Find the generated .conf file (assumes only one exists in the current directory or subdirectories)
CONFIG_FILE=$(ls -t *.conf | head -n 1)
echo "CONFIG_FILE: $CONFIG_FILE"

# Parse the generated configuration file.
# Remove leading/trailing spaces from the extracted values.
ADDRESS=$(grep -i "^Address" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[ \t]*//')
PRIVATE_KEY=$(grep -i "^PrivateKey" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[ \t]*//')
DNS=$(grep -i "^DNS" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[ \t]*//')

PUB_KEY=$(grep -i "^PublicKey" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[ \t]*//')
ENDPOINT=$(grep -i "^Endpoint" "$CONFIG_FILE" | cut -d'=' -f2- | sed 's/^[ \t]*//')
ENDPOINT_ADDR=${ENDPOINT%:*}
ENDPOINT_PORT=${ENDPOINT##*:}



echo "Parsed values:"
echo "  Address:      $ADDRESS"
echo "  PrivateKey:   $PRIVATE_KEY"
echo "  DNS:          $DNS"
echo "  PublicKey:    $PUB_KEY"
echo "  Endpoint:     $ENDPOINT"
echo "  Endpoint Addresss:     $ENDPOINT_ADDR"
echo "  Endpoint Port:     $ENDPOINT_PORT"

# Read router credentials from the YAML file (router.yaml)
# Expected format:
# router:
#     ip: 192.168.50.1
#     username: USERNAME
#     password: PASSWORD
ROUTER_IP=$(grep 'ip:' router.yaml | awk '{print $2}')
ROUTER_USERNAME=$(grep 'username:' router.yaml | awk '{print $2}')
ROUTER_PASSWORD=$(grep 'password:' router.yaml | awk '{print $2}')

echo "Router credentials:"
echo "  IP:       $ROUTER_IP"
echo "  Username: $ROUTER_USERNAME"

# Use sshpass to log into the router and update the nvram variables.
# These nvram variables will be set as follows:
#   - wgc1_addr and wgc_addr: set to ADDRESS
#   - wgc1_priv and wgc_priv: set to PRIVATE_KEY
#   - wgc1_dns and wgc_dns: set to DNS
#   - wgc1_ppub and wgc_ppub: set to PUB_KEY
#   - wgc1_ep_addr, wgc1_ep_addr_r, and wgc_ep_addr: set to ENDPOINT
#   - wgc_aips and wgc1_aips: set to 0.0.0.0/0
SSH_CMD="
nvram set wgc1_desc=PIA-WG; wgc_desc=PIA-WG; \
nvram set wgc1_addr=${ADDRESS}; nvram set wgc_addr=${ADDRESS}; \
nvram set wgc1_priv=${PRIVATE_KEY}; nvram set wgc_priv=${PRIVATE_KEY}; \
nvram set wgc1_dns='${DNS}'; nvram set wgc_dns='${DNS}'; \
nvram set wgc1_ppub=${PUB_KEY}; nvram set wgc_ppub=${PUB_KEY}; \
nvram set wgc1_ep_addr=${ENDPOINT_ADDR}; nvram set wgc1_ep_addr_r=${ENDPOINT_ADDR}; nvram set wgc_ep_addr=${ENDPOINT_ADDR}; \
nvram set wgc1_ep_port=${ENDPOINT_PORT}; nvram set wgc_ep_port=${ENDPOINT_PORT}; \
nvram set wgc_aips='0.0.0.0/0'; nvram set wgc1_aips='0.0.0.0/0'; nvram commit"

echo "Updating nvram on router..."
sshpass -p "${ROUTER_PASSWORD}" ssh -o StrictHostKeyChecking=no ${ROUTER_USERNAME}@${ROUTER_IP} "${SSH_CMD}"

echo "nvram update complete."
