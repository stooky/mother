# Mother

A multi-tenant static site deployment system. One server, many sites, zero complexity.

```
request → *.crkid.com → nginx → /var/www/sites/{subdomain}/dist/
```

## Why This Exists

Deploying static sites should be boring. This system makes it boring:

- **One command deploys a site.** No CI/CD pipelines to configure, no containers to orchestrate.
- **Sites are isolated by subdomain.** Each site gets its own directory, its own SSL cert, its own deployment history.
- **The server does the building.** Ship source code, not artifacts. The server runs `npm ci && npm run build`.

This is not a platform. It's a collection of shell scripts that do one thing well.

---

## Quick Start

Deploy a site in 60 seconds:

```bash
# 1. Deploy
./scripts/deploy-local.sh mysite /path/to/astro-project

# 2. Add SSL (on server)
ssh root@45.32.214.247 "certbot --nginx -d mysite.crkid.com"

# 3. Done
curl https://mysite.crkid.com
```

---

## Table of Contents

- [Architecture](#architecture)
- [Deploying Sites](#deploying-sites)
- [Creating New Sites](#creating-new-sites)
- [Operations Runbook](#operations-runbook)
- [Troubleshooting](#troubleshooting)
- [Design Decisions](#design-decisions)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  crkid.com  ·  45.32.214.247  ·  Ubuntu 24.04 LTS              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   nginx                                                         │
│   ├── crkid.com         → /var/www/crkid.com/dist/             │
│   ├── mcivor.crkid.com  → /var/www/sites/mcivor/dist/          │
│   ├── site2.crkid.com   → /var/www/sites/site2/dist/           │
│   └── *.crkid.com       → /var/www/sites/$subdomain/dist/      │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│   Node.js 20.x  ·  Certbot (auto-renewal)  ·  UFW (22,80,443)  │
└─────────────────────────────────────────────────────────────────┘
```

### How Requests Flow

1. DNS resolves `*.crkid.com` to `45.32.214.247`
2. nginx matches the subdomain using a regex server block
3. Request is served from `/var/www/sites/{subdomain}/dist/`
4. If no matching directory exists, nginx returns the default page

### Directory Structure

```
/var/www/
├── crkid.com/              # Main domain
│   └── dist/
├── sites/                  # All subdomains live here
│   ├── mcivor/
│   │   ├── src/            # Source code
│   │   ├── dist/           # Built output (nginx serves this)
│   │   ├── node_modules/
│   │   └── package.json
│   └── anothersite/
│       └── ...
```

---

## Deploying Sites

### From Local Directory

Best for active development. Syncs your local files to the server and rebuilds.

```bash
./scripts/deploy-local.sh <subdomain> <local_path>
```

**Example:**
```bash
./scripts/deploy-local.sh mcivor ../websites/mcivor
```

**What happens:**
1. Files are synced via tar+ssh (excludes `node_modules`, `.git`, `dist`)
2. Server runs `npm ci && npm run build`
3. Permissions are set to `www-data`
4. nginx is reloaded

### From GitHub Repository

Best for production deployments. Clones or pulls from a repo.

```bash
./scripts/deploy-site.sh <subdomain> <repo_url> [branch]
```

**Example:**
```bash
./scripts/deploy-site.sh blog https://github.com/stooky/blog.git main
```

### Listing Deployed Sites

```bash
./scripts/list-sites.sh
```

**Output:**
```
Deployed sites on 45.32.214.247:
================================
  mcivor.crkid.com  [✓ Built]
  blog.crkid.com    [✓ Built]
  test.crkid.com    [✗ No dist/]
```

---

## Creating New Sites

### Option A: Use the Template

The `template/` directory contains a complete Astro site with Tailwind CSS.

```bash
# Copy template
cp -r template /path/to/mysite
cd /path/to/mysite

# Configure
vim src/config/config.yaml    # Site name, contact info, etc.

# Test locally
npm install
npm run dev

# Deploy
cd /path/to/mother/scripts
./deploy-local.sh mysite /path/to/mysite
```

### Option B: Bring Your Own Site

Any static site generator works. Requirements:

| Requirement | Why |
|-------------|-----|
| `package.json` with `build` script | Server runs `npm run build` |
| Output to `dist/` directory | nginx serves from `dist/` |
| `package-lock.json` | Server runs `npm ci` (not `npm install`) |

### DNS Configuration

Add an A record pointing your subdomain to the server:

```
mysite.crkid.com.  A  45.32.214.247
```

Or use a wildcard if you control the zone:

```
*.crkid.com.  A  45.32.214.247
```

### SSL Certificates

After deploying, add SSL:

```bash
ssh root@45.32.214.247
certbot --nginx -d mysite.crkid.com
```

Certificates auto-renew via cron. Check status with:

```bash
certbot certificates
```

---

## Operations Runbook

### View Deployed Sites

```bash
./scripts/list-sites.sh
```

### SSH to Server

```bash
ssh -i ~/.ssh/id_rsa root@45.32.214.247
```

### View nginx Configuration

```bash
# All enabled sites
ls -la /etc/nginx/sites-enabled/

# Multi-host config
cat /etc/nginx/sites-available/crkid-multihost

# Test config syntax
nginx -t
```

### Rebuild a Site Manually

```bash
cd /var/www/sites/mysite
npm run build
chown -R www-data:www-data .
systemctl reload nginx
```

### View Logs

```bash
# nginx access log
tail -f /var/log/nginx/access.log

# nginx error log
tail -f /var/log/nginx/error.log

# Filter by subdomain
grep "mcivor" /var/log/nginx/access.log | tail -50
```

### Check SSL Certificate Expiry

```bash
certbot certificates
```

### Force SSL Renewal

```bash
certbot renew --force-renewal
```

### Restart nginx

```bash
systemctl reload nginx   # Graceful reload
systemctl restart nginx  # Full restart
```

---

## Troubleshooting

### Site returns 404

**Check if the dist directory exists:**
```bash
ls -la /var/www/sites/mysite/dist/
```

**If missing, rebuild:**
```bash
cd /var/www/sites/mysite && npm run build
```

### Site returns "crkid.com Multi-Host Server"

The request is hitting the default nginx block. This means:

1. **DNS isn't pointing to the server** — verify with `dig mysite.crkid.com`
2. **The site directory doesn't exist** — check `/var/www/sites/mysite/`
3. **nginx config is wrong** — run `nginx -t` and check server_name

### Build fails on server

**Check Node.js version:**
```bash
node --version  # Should be 20.x
```

**Check for missing dependencies:**
```bash
cd /var/www/sites/mysite
rm -rf node_modules
npm ci
npm run build
```

**Check disk space:**
```bash
df -h
```

### Permission denied errors

```bash
chown -R www-data:www-data /var/www/sites/mysite
chmod -R 755 /var/www/sites/mysite
```

### SSL certificate errors

**Certificate doesn't exist:**
```bash
certbot --nginx -d mysite.crkid.com
```

**Certificate expired:**
```bash
certbot renew
```

**Wrong certificate being served:**
Check that the site has its own nginx config in `/etc/nginx/sites-enabled/` with the correct `ssl_certificate` paths.

---

## Design Decisions

### Why build on the server?

Shipping source code instead of build artifacts means:

- **No build environment parity issues.** The server that runs the site builds the site.
- **Smaller transfers.** Source code is smaller than `node_modules` + `dist`.
- **Simpler CI/CD.** Push code, run deploy script. No artifact storage.

The trade-off is build time on deploy (~10-30 seconds). For static sites updated infrequently, this is acceptable.

### Why not Docker/Kubernetes?

This system optimizes for:

- **Simplicity.** Shell scripts are debuggable by anyone.
- **Cost.** One $6/month VPS hosts dozens of sites.
- **Speed.** Deploy in seconds, not minutes.

Docker adds complexity without proportional benefit for static sites. Kubernetes is overkill by an order of magnitude.

### Why subdomains instead of paths?

`blog.crkid.com` vs `crkid.com/blog`:

- **Isolation.** Each site has independent cookies, localStorage, service workers.
- **SSL.** Per-site certificates via Let's Encrypt (free, automatic).
- **Simplicity.** nginx config is one regex, not N location blocks.

### Why nginx regex matching?

The core of the system is one nginx directive:

```nginx
server_name ~^(?<subdomain>.+)\.crkid\.com$;
root /var/www/sites/$subdomain/dist;
```

This means:
- **Zero config per site.** Add a directory, it works.
- **No nginx reload needed** for new sites (unless adding SSL).
- **Predictable behavior.** The subdomain *is* the directory name.

### Why noindex by default?

Demo/staging sites shouldn't appear in search results. All sites include:

1. `<meta name="robots" content="noindex, nofollow">`
2. `robots.txt` with `Disallow: /`
3. `X-Robots-Tag: noindex, nofollow` header from nginx

Production sites should override these in their source code.

---

## File Reference

```
mother/
├── scripts/
│   ├── deploy-local.sh     # Deploy from local directory
│   ├── deploy-site.sh      # Deploy from GitHub repo
│   ├── list-sites.sh       # List all deployed sites
│   └── setup-server.sh     # Initial server configuration
├── template/               # Astro + Tailwind starter
│   ├── src/
│   │   ├── config/
│   │   │   └── config.yaml # Site configuration
│   │   ├── pages/          # Routes
│   │   ├── layouts/        # Page templates
│   │   └── components/     # Reusable UI
│   ├── public/             # Static assets
│   ├── package.json
│   └── astro.config.mjs
├── sites/                  # Local development (gitignored)
└── README.md
```

---

## Requirements

| Requirement | Version | Notes |
|-------------|---------|-------|
| SSH key | — | `~/.ssh/id_rsa` with server access |
| Bash | 4.0+ | Git Bash or WSL on Windows |
| Server OS | Ubuntu 24.04 | Other Debian-based distros may work |
| Node.js | 20.x | Installed on server |
| nginx | 1.18+ | Installed on server |
| Certbot | 1.0+ | For SSL certificates |

---

## License

MIT
