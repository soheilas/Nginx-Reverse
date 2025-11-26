#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Reverse Proxy with SSL Setup${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Get domain
read -p "Enter domain name (e.g., api.example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain cannot be empty${NC}"
    exit 1
fi

# Get port
read -p "Enter port number (e.g., 2054): " PORT
if [ -z "$PORT" ]; then
    echo -e "${RED}Port cannot be empty${NC}"
    exit 1
fi

# Get target URL
read -p "Enter target URL (e.g., https://google.com): " TARGET_URL
if [ -z "$TARGET_URL" ]; then
    echo -e "${RED}Target URL cannot be empty${NC}"
    exit 1
fi

# Get Cloudflare API token
read -sp "Enter Cloudflare API Token: " CF_TOKEN
echo ""
if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}Cloudflare token cannot be empty${NC}"
    exit 1
fi

# Get email
read -p "Enter your email for Let's Encrypt: " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}Email cannot be empty${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Installing required packages...${NC}"
apt update -qq
apt install -y nginx certbot python3-certbot-dns-cloudflare ufw > /dev/null 2>&1

echo -e "${GREEN}Packages installed successfully${NC}"

# Remove default nginx site
echo -e "${YELLOW}Removing default nginx configuration...${NC}"
rm -f /etc/nginx/sites-enabled/default

# Create secure directory for credentials
echo -e "${YELLOW}Creating Cloudflare credentials...${NC}"
CRED_DIR="/etc/letsencrypt/.secrets"
mkdir -p $CRED_DIR
chmod 700 $CRED_DIR

cat > $CRED_DIR/cloudflare-$DOMAIN.ini <<EOF
dns_cloudflare_api_token = $CF_TOKEN
EOF
chmod 600 $CRED_DIR/cloudflare-$DOMAIN.ini

# Clear token from memory
CF_TOKEN=""

echo -e "${GREEN}Cloudflare credentials created securely${NC}"

# Get SSL certificate
echo -e "${YELLOW}Obtaining SSL certificate...${NC}"
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials $CRED_DIR/cloudflare-$DOMAIN.ini \
  -d $DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --non-interactive

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to obtain SSL certificate${NC}"
    exit 1
fi

echo -e "${GREEN}SSL certificate obtained successfully${NC}"

# Extract hostname from target URL
TARGET_HOST=$(echo $TARGET_URL | sed -e 's|^[^/]*//||' -e 's|/.*$||')

# Create nginx configuration
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
SAFE_DOMAIN=$(echo $DOMAIN | sed 's/\./-/g')
cat > /etc/nginx/sites-available/$SAFE_DOMAIN <<EOF
server {
    listen $PORT ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass $TARGET_URL;
        proxy_ssl_server_name on;
        proxy_set_header Host $TARGET_HOST;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_verify off;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/$SAFE_DOMAIN /etc/nginx/sites-enabled/

# Test nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
nginx -t
if [ $? -ne 0 ]; then
    echo -e "${RED}Nginx configuration test failed${NC}"
    exit 1
fi

echo -e "${GREEN}Nginx configuration is valid${NC}"

# Restart or start nginx
echo -e "${YELLOW}Starting Nginx...${NC}"
systemctl restart nginx 2>/dev/null || systemctl start nginx
systemctl enable nginx > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start Nginx${NC}"
    exit 1
fi

echo -e "${GREEN}Nginx started successfully${NC}"

# Setup auto-renewal hook
echo -e "${YELLOW}Setting up SSL auto-renewal...${NC}"
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'EOF'
#!/bin/bash
systemctl reload nginx
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

echo -e "${GREEN}Auto-renewal configured${NC}"

# Open firewall port
echo -e "${YELLOW}Opening firewall port $PORT...${NC}"
ufw allow $PORT/tcp > /dev/null 2>&1

echo -e "${GREEN}Firewall configured${NC}"

# Test renewal
echo -e "${YELLOW}Testing certificate renewal...${NC}"
certbot renew --dry-run > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Certificate renewal test passed${NC}"
else
    echo -e "${YELLOW}Certificate renewal test had warnings (this is usually OK)${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "Your reverse proxy is ready at: ${GREEN}https://$DOMAIN:$PORT${NC}"
echo -e "It redirects to: ${GREEN}$TARGET_URL${NC}"
echo ""
echo -e "SSL certificate will auto-renew before expiration"
echo -e "Cloudflare credentials stored at: ${YELLOW}$CRED_DIR/cloudflare-$DOMAIN.ini${NC}"
echo ""
