#!/bin/bash
#
# List all deployed sites on the multi-host server
#

SERVER_IP="45.32.214.247"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
BASE_DOMAIN="crkid.com"

SSH_CMD="ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP}"

echo "Deployed sites on ${SERVER_IP}:"
echo "================================"

$SSH_CMD << 'ENDSSH'
if [[ -d /var/www/sites ]]; then
    for site in /var/www/sites/*/; do
        if [[ -d "$site" ]]; then
            name=$(basename "$site")
            if [[ -d "${site}dist" ]]; then
                status="✓ Built"
            else
                status="✗ No dist/"
            fi
            echo "  ${name}.crkid.com  [${status}]"
        fi
    done
else
    echo "  No sites deployed yet"
fi
ENDSSH
