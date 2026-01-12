#!/bin/bash
#
# Initial server setup for multi-host deployment
# Run this ONCE on a fresh Ubuntu 24.04 server
#
# Usage: ./setup-server.sh
#

set -e

SERVER_IP="45.32.214.247"
SERVER_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
BASE_DOMAIN="crkid.com"

SSH_CMD="ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP}"

echo "========================================"
echo "   Multi-Host Server Setup"
echo "========================================"
echo "  Server: $SERVER_IP"
echo "  Domain: *.${BASE_DOMAIN}"
echo "========================================"
echo ""

read -p "This will configure the server. Continue? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Setup cancelled"
    exit 0
fi

echo "Connecting to server and running setup..."

$SSH_CMD << 'ENDSSH'
set -e

echo "=== Updating system ==="
apt update && apt upgrade -y

echo "=== Installing Node.js 20.x ==="
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
fi
node --version
npm --version

echo "=== Installing nginx ==="
apt install -y nginx

echo "=== Installing Certbot ==="
apt install -y certbot python3-certbot-nginx

echo "=== Creating sites directory ==="
mkdir -p /var/www/sites

echo "=== Creating nginx multi-host config ==="
cat > /etc/nginx/sites-available/crkid-multihost << 'NGINXCONF'
# Multi-host configuration for *.crkid.com
# Each subdomain maps to /var/www/sites/{subdomain}/dist/

server {
    listen 80;
    listen [::]:80;
    server_name ~^(?<subdomain>.+)\.crkid\.com$;

    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ~^(?<subdomain>.+)\.crkid\.com$;

    # SSL will be managed by certbot per-site
    # These are placeholder paths - certbot will update them
    ssl_certificate /etc/letsencrypt/live/crkid.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/crkid.com/privkey.pem;

    root /var/www/sites/$subdomain/dist;
    index index.html;

    # Demo sites: discourage search engine indexing
    add_header X-Robots-Tag "noindex, nofollow" always;

    location / {
        try_files $uri $uri/ $uri.html /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # PHP support (optional, for contact forms)
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}

# Default server for unmatched requests
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        return 200 'crkid.com Multi-Host Server';
        add_header Content-Type text/plain;
    }
}
NGINXCONF

echo "=== Enabling nginx config ==="
ln -sf /etc/nginx/sites-available/crkid-multihost /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "=== Testing nginx config ==="
nginx -t

echo "=== Restarting nginx ==="
systemctl restart nginx
systemctl enable nginx

echo "=== Setting up firewall ==="
ufw allow 'Nginx Full'
ufw allow OpenSSH
ufw --force enable

echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "1. Configure wildcard DNS: *.crkid.com -> $SERVER_IP"
echo "2. Get wildcard SSL: certbot certonly --nginx -d crkid.com -d *.crkid.com"
echo "   (Note: Wildcard requires DNS challenge)"
echo "3. Or get per-site SSL: certbot --nginx -d subdomain.crkid.com"
echo ""
ENDSSH

echo ""
echo "========================================"
echo "Server setup complete!"
echo "========================================"
