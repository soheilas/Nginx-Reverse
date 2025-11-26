# Nginx Reverse Proxy with Auto SSL

Automated script to set up Nginx reverse proxy with Let's Encrypt SSL certificate on custom ports using Cloudflare DNS challenge.

## Features

- ✅ Automated Nginx installation and configuration
- ✅ SSL certificate via Let's Encrypt (Cloudflare DNS challenge)
- ✅ Custom port support (no need for 80/443)
- ✅ Automatic SSL renewal (twice daily checks)
- ✅ Secure credential storage
- ✅ Firewall configuration
- ✅ Works even when port 80/443 are occupied

## Requirements

- Ubuntu/Debian server with root access
- Domain managed by Cloudflare
- Cloudflare API token with DNS edit permissions

## Installation

 Download and Run :
```bash
wget https://raw.githubusercontent.com/soheilas/Nginx-Reverse/main/setup-reverse-proxy.sh
chmod +x setup-reverse-proxy.sh && ./setup-reverse-proxy.sh
```

## Usage

The script will prompt you for:

1. **Domain name** - Your domain (e.g., `api.example.com`)
2. **Port number** - Custom port for HTTPS (e.g., `2054`)
3. **Target URL** - Destination URL to proxy (e.g., `https://target-site.com`)
4. **Cloudflare API Token** - Your Cloudflare DNS API token
5. **Email** - Email for Let's Encrypt notifications

### Example
```
Enter domain name: api.example.com
Enter port number: 2054
Enter target URL: https://backend-service.com
Enter Cloudflare API Token: [hidden]
Enter your email: admin@example.com
```

Result: `https://api.example.com:2054` → proxies to → `https://backend-service.com`

## Getting Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Select your domain in Zone Resources
5. Copy the generated token

## How It Works

1. Installs Nginx and Certbot with Cloudflare DNS plugin
2. Removes default Nginx configuration (prevents port 80 conflicts)
3. Creates secure credential file for Cloudflare API token
4. Obtains SSL certificate using DNS challenge (no port 80/443 needed)
5. Configures Nginx reverse proxy on your custom port
6. Sets up automatic SSL renewal with Nginx reload hook
7. Opens firewall port

## SSL Auto-Renewal

Certificates automatically renew 30 days before expiration via systemd timer.

Check renewal status:
```bash
systemctl status certbot.timer
```

Test renewal manually:
```bash
certbot renew --dry-run
```

View renewal logs:
```bash
journalctl -u certbot.timer
```

## File Locations

- **Nginx config**: `/etc/nginx/sites-available/[domain]`
- **SSL certificates**: `/etc/letsencrypt/live/[domain]/`
- **Cloudflare credentials**: `/etc/letsencrypt/.secrets/cloudflare-[domain].ini`
- **Renewal hook**: `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`

## Troubleshooting

### Check Nginx status
```bash
systemctl status nginx
```

### Test Nginx configuration
```bash
nginx -t
```

### Check SSL certificate
```bash
certbot certificates
```

### View Nginx logs
```bash
tail -f /var/log/nginx/error.log
```

### Check if port is open
```bash
ss -tulpn | grep :[PORT]
```

## Multiple Domains

Run the script multiple times for different domains. Each domain gets:
- Separate Nginx configuration
- Separate SSL certificate
- Separate Cloudflare credential file

## Security Notes

- Cloudflare API tokens are stored with 600 permissions in `/etc/letsencrypt/.secrets/`
- Token is cleared from memory after certificate generation
- Each domain has its own credential file
- Default Nginx site is removed to prevent information disclosure

## Uninstallation

To remove a specific domain:
```bash
DOMAIN="api.example.com"
SAFE_DOMAIN=$(echo $DOMAIN | sed 's/\./-/g')

# Remove Nginx config
rm /etc/nginx/sites-enabled/$SAFE_DOMAIN
rm /etc/nginx/sites-available/$SAFE_DOMAIN

# Remove SSL certificate
certbot delete --cert-name $DOMAIN

# Remove Cloudflare credentials
rm /etc/letsencrypt/.secrets/cloudflare-$DOMAIN.ini

# Reload Nginx
systemctl reload nginx
```

## Tested On

- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- Debian 11
- Debian 12
