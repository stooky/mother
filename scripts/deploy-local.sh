#!/bin/bash
#
# Deploy Local Site to Multi-Host Server
# Usage: ./deploy-local.sh <subdomain> <local_path>
#
# Example: ./deploy-local.sh mcivor ../sites/mcivor
#

set -e

# Server configuration
SERVER_IP="45.32.214.247"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
BASE_DOMAIN="crkid.com"
SITES_DIR="/var/www/sites"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
SUBDOMAIN="$1"
LOCAL_PATH="$2"

if [[ -z "$SUBDOMAIN" || -z "$LOCAL_PATH" ]]; then
    echo "Usage: $0 <subdomain> <local_path>"
    echo ""
    echo "Example: $0 mcivor ../sites/mcivor"
    exit 1
fi

# Resolve to absolute path
LOCAL_PATH=$(cd "$LOCAL_PATH" 2>/dev/null && pwd)
if [[ ! -d "$LOCAL_PATH" ]]; then
    log_error "Local path does not exist: $LOCAL_PATH"
    exit 1
fi

if [[ ! -f "$LOCAL_PATH/package.json" ]]; then
    log_error "No package.json found in $LOCAL_PATH"
    exit 1
fi

INSTALL_DIR="${SITES_DIR}/${SUBDOMAIN}"
FULL_DOMAIN="${SUBDOMAIN}.${BASE_DOMAIN}"

echo ""
echo "========================================"
echo "   Local Site Deployment"
echo "========================================"
echo "  Subdomain:   $SUBDOMAIN"
echo "  Full URL:    https://${FULL_DOMAIN}"
echo "  Local path:  $LOCAL_PATH"
echo "  Server:      $SERVER_IP"
echo "  Remote dir:  $INSTALL_DIR"
echo "========================================"
echo ""

# ============================================
# Check SSH key exists
# ============================================
if [[ ! -f "$SSH_KEY" ]]; then
    log_error "SSH key not found: $SSH_KEY"
    exit 1
fi
log_info "SSH key found: $SSH_KEY"

# ============================================
# Test SSH connectivity
# ============================================
log_info "Testing SSH connection..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o BatchMode=yes "${SERVER_USER}@${SERVER_IP}" "echo 'SSH OK'" 2>/dev/null; then
    log_error "Cannot connect to server via SSH"
    log_error "Check: ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP}"
    exit 1
fi
log_info "SSH connection successful"

# ============================================
# Check if rsync is available locally
# ============================================
if ! command -v rsync &> /dev/null; then
    log_warn "rsync not found, will use scp instead"
    USE_SCP=1
else
    log_info "rsync found"
    USE_SCP=0
fi

# ============================================
# Create remote directory if needed
# ============================================
log_info "Ensuring remote directory exists..."
ssh -i "$SSH_KEY" "${SERVER_USER}@${SERVER_IP}" "mkdir -p ${INSTALL_DIR}"

# ============================================
# Sync files to server
# ============================================
log_info "Syncing files to server..."

if [[ "$USE_SCP" -eq 0 ]]; then
    # Use rsync (faster, incremental)
    rsync -avz --delete \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude 'dist' \
        --exclude '.astro' \
        -e "ssh -i $SSH_KEY" \
        "$LOCAL_PATH/" \
        "${SERVER_USER}@${SERVER_IP}:${INSTALL_DIR}/"
else
    # Fallback to scp
    log_warn "Using scp (slower than rsync)..."
    # Create tarball excluding unwanted dirs
    TMPTAR=$(mktemp).tar.gz
    tar -czf "$TMPTAR" -C "$LOCAL_PATH" \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='.astro' \
        .
    scp -i "$SSH_KEY" "$TMPTAR" "${SERVER_USER}@${SERVER_IP}:/tmp/site.tar.gz"
    ssh -i "$SSH_KEY" "${SERVER_USER}@${SERVER_IP}" "cd ${INSTALL_DIR} && tar -xzf /tmp/site.tar.gz && rm /tmp/site.tar.gz"
    rm "$TMPTAR"
fi

log_info "Files synced successfully"

# ============================================
# Build on server
# ============================================
log_info "Installing dependencies and building on server..."

ssh -i "$SSH_KEY" "${SERVER_USER}@${SERVER_IP}" << ENDSSH
set -e
cd "${INSTALL_DIR}"

echo "Installing npm dependencies..."
npm ci --production=false

echo "Building site..."
npm run build

echo "Setting permissions..."
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"

echo "Reloading nginx..."
systemctl reload nginx
ENDSSH

# ============================================
# Done
# ============================================
echo ""
echo "========================================"
log_info "Deployment complete!"
echo "========================================"
echo ""
echo "  Site: https://${FULL_DOMAIN}"
echo ""
echo "  To add SSL:"
echo "    ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP}"
echo "    certbot --nginx -d ${FULL_DOMAIN}"
echo ""
