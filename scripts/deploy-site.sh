#!/bin/bash
#
# Multi-Host Site Deployment Script
# Usage: ./deploy-site.sh <subdomain> <repo_url> [branch]
#
# Example: ./deploy-site.sh mcivor https://github.com/stooky/mcivor.git main
#
# This will deploy the site to:
#   - Server: /var/www/sites/mcivor/
#   - URL: https://mcivor.crkid.com
#

set -e

# Server configuration
SERVER_IP="45.32.214.247"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
BASE_DOMAIN="crkid.com"
SITES_DIR="/var/www/sites"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
SUBDOMAIN="$1"
REPO_URL="$2"
BRANCH="${3:-main}"

if [[ -z "$SUBDOMAIN" || -z "$REPO_URL" ]]; then
    echo "Usage: $0 <subdomain> <repo_url> [branch]"
    echo ""
    echo "Arguments:"
    echo "  subdomain  - The subdomain name (e.g., 'mcivor' for mcivor.crkid.com)"
    echo "  repo_url   - GitHub repository URL"
    echo "  branch     - Git branch (default: main)"
    echo ""
    echo "Example:"
    echo "  $0 mcivor https://github.com/stooky/mcivor.git main"
    exit 1
fi

# Ensure .git suffix
if [[ ! "$REPO_URL" =~ \.git$ ]]; then
    REPO_URL="${REPO_URL}.git"
fi

INSTALL_DIR="${SITES_DIR}/${SUBDOMAIN}"
FULL_DOMAIN="${SUBDOMAIN}.${BASE_DOMAIN}"

echo ""
echo "========================================"
echo "   Multi-Host Site Deployment"
echo "========================================"
echo "  Subdomain:  $SUBDOMAIN"
echo "  Full URL:   https://${FULL_DOMAIN}"
echo "  Repository: $REPO_URL"
echo "  Branch:     $BRANCH"
echo "  Server:     $SERVER_IP"
echo "  Directory:  $INSTALL_DIR"
echo "========================================"
echo ""

read -p "Proceed with deployment? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    log_info "Deployment cancelled"
    exit 0
fi

SSH_CMD="ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP}"

log_info "Connecting to server..."

# Clone or update repository
$SSH_CMD << ENDSSH
set -e

echo "Setting up site directory..."
if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo "Repository exists, pulling latest changes..."
    cd "${INSTALL_DIR}"
    git fetch origin
    git checkout "${BRANCH}"
    git pull origin "${BRANCH}"
else
    echo "Cloning repository..."
    mkdir -p "${INSTALL_DIR}"
    git clone -b "${BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi

echo "Installing npm dependencies..."
cd "${INSTALL_DIR}"
npm ci --production=false

echo "Building static site..."
npm run build

echo "Setting permissions..."
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"

echo "Reloading nginx..."
systemctl reload nginx

echo ""
echo "========================================"
echo "Deployment complete!"
echo "========================================"
echo "Site deployed to: ${INSTALL_DIR}/dist"
echo "URL: https://${FULL_DOMAIN}"
echo ""
echo "To add SSL, run on server:"
echo "  certbot --nginx -d ${FULL_DOMAIN}"
echo "========================================"
ENDSSH

log_info "Deployment finished!"
echo ""
echo "Your site should be available at:"
echo "  https://${FULL_DOMAIN}"
echo ""
echo "Note: DNS must be configured to point ${FULL_DOMAIN} to ${SERVER_IP}"
