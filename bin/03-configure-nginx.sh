#!/bin/bash
# Configure and Verify Nginx for HTTPS
set -e

LOG_FILE="/var/log/certbot_nginx.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Nginx HTTPS Configuration ==="

# Get domain
CERTBOT_DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")

if [ -z "$CERTBOT_DOMAIN" ]; then
    log "ERROR: CERTBOT_DOMAIN not set"
    exit 1
fi

log "Domain: ${CERTBOT_DOMAIN}"

# Check nginx configuration syntax
log "Testing nginx configuration..."
if sudo nginx -t 2>&1 | tee -a "$LOG_FILE"; then
    log "✓ Nginx configuration is valid"
else
    log "✗ Nginx configuration has errors"
    log "Showing nginx error log:"
    sudo tail -30 /var/log/nginx/error.log | tee -a "$LOG_FILE"
    exit 1
fi

# Check if SSL configuration exists
log "Checking for SSL configuration in nginx..."
if sudo grep -r "listen.*443" /etc/nginx/ 2>&1 | tee -a "$LOG_FILE"; then
    log "✓ Found 443 listener in nginx configuration"
else
    log "✗ WARNING: No 443 listener found in nginx config!"
    log "This means nginx is not configured for HTTPS"
fi

# Check for SSL certificate directives
log "Checking for SSL certificate directives..."
if sudo grep -r "ssl_certificate.*${CERTBOT_DOMAIN}" /etc/nginx/ 2>&1 | tee -a "$LOG_FILE"; then
    log "✓ SSL certificate directive found for ${CERTBOT_DOMAIN}"
else
    log "⚠ WARNING: No SSL certificate directive found for ${CERTBOT_DOMAIN}"
fi

# Show all nginx config files
log "Listing nginx configuration files..."
sudo find /etc/nginx/ -type f -name "*.conf" | tee -a "$LOG_FILE"

# Show certbot-created nginx configs
log "Checking certbot nginx configurations..."
if [ -d /etc/nginx/sites-available ]; then
    sudo ls -lah /etc/nginx/sites-available/ | tee -a "$LOG_FILE"
fi
if [ -d /etc/nginx/sites-enabled ]; then
    sudo ls -lah /etc/nginx/sites-enabled/ | tee -a "$LOG_FILE"
fi

# Restart nginx
log "Restarting nginx..."
sudo systemctl restart nginx
sleep 3

# Verify nginx is running
if sudo systemctl is-active --quiet nginx; then
    log "✓ Nginx is running"
    sudo systemctl status nginx --no-pager | tee -a "$LOG_FILE"
else
    log "✗ ERROR: Nginx is not running"
    sudo systemctl status nginx --no-pager | tee -a "$LOG_FILE"
    exit 1
fi

# Reload nginx to apply any config changes
log "Reloading nginx..."
sudo systemctl reload nginx
sleep 2

log "=== Nginx Configuration Complete ==="
exit 0
