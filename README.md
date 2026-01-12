# Mother

Multi-host static site deployment system for crkid.com.

```
*.crkid.com → 45.32.214.247 → /var/www/sites/{subdomain}/dist/
```

## Quick Reference

```bash
# Deploy from local directory
./scripts/deploy-local.sh <subdomain> <local_path>

# Deploy from GitHub repo
./scripts/deploy-site.sh <subdomain> <repo_url> [branch]

# List deployed sites
./scripts/list-sites.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Ubuntu 24.04 LTS                         │
│                    45.32.214.247                            │
├─────────────────────────────────────────────────────────────┤
│  nginx (SSL via Let's Encrypt)                              │
│  ├── mcivor.crkid.com   → /var/www/sites/mcivor/dist/      │
│  └── *.crkid.com        → /var/www/sites/*/dist/           │
├─────────────────────────────────────────────────────────────┤
│  Node.js 20.x  │  Certbot (auto-renewal)  │  UFW Firewall  │
└─────────────────────────────────────────────────────────────┘
```

## Creating a New Site

### 1. Copy the template

```bash
cp -r template sites/mysite
cd sites/mysite
```

### 2. Customize config.yaml

Edit `src/config/config.yaml` with your site details.

### 3. Add DNS Record

Point subdomain to server:
```
mysite.crkid.com  A  45.32.214.247
```

### 4. Deploy

```bash
cd scripts
./deploy-local.sh mysite ../sites/mysite
```

### 5. Add SSL

```bash
ssh -i ~/.ssh/id_rsa root@45.32.214.247
certbot --nginx -d mysite.crkid.com
```

## Server Setup (One-time)

```bash
./scripts/setup-server.sh
```

## Files

| File | Purpose |
|------|---------|
| `scripts/deploy-local.sh` | Deploy from local directory |
| `scripts/deploy-site.sh` | Deploy from GitHub repo |
| `scripts/list-sites.sh` | List all deployed sites |
| `scripts/setup-server.sh` | Initial server configuration |
| `template/` | Astro site starter template |

## Requirements

- SSH key: `~/.ssh/id_rsa`
- Git Bash or WSL (for Windows)
- Server: Ubuntu 24.04, Node.js 20.x, nginx, certbot
