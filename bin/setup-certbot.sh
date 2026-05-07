#!/bin/bash
set -e

# Certbot Setup and SSL Certificate Management Script
# This script installs Certbot, obtains SSL certificates, and configures auto-renewal

LOG_FILE="/var/log/certbot_deploy.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting Certbot Setup ==="

# Get environment variables from Elastic Beanstalk
CERTBOT_EMAIL=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_EMAIL 2>/dev/null || echo "")
CERTBOT_DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")

if [ -z "$CERTBOT_EMAIL" ] || [ -z "$CERTBOT_DOMAIN" ]; then
    log "ERROR: CERTBOT_EMAIL or CERTBOT_DOMAIN not set in environment variables"
    log "Please configure these in your Elastic Beanstalk environment"
    exit 1
fi

log "Certbot Email: ${CERTBOT_EMAIL}"
log "Certbot Domain: ${CERTBOT_DOMAIN}"

# Install Certbot if not already installed
if [ ! -f /usr/bin/certbot ]; then
    log "Installing Certbot..."
    sudo dnf install -y augeas-libs python3-pip
    sudo python3 -m venv /opt/certbot/
    sudo /opt/certbot/bin/pip install --upgrade pip
    sudo /opt/certbot/bin/pip install certbot certbot-nginx
    sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
    log "Certbot installed successfully"
else
    log "Certbot already installed, skipping installation"
fi

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/${CERTBOT_DOMAIN}" ]; then
    log "Certificate already exists for ${CERTBOT_DOMAIN}"
    
    # Check certificate expiration
    CERT_EXPIRY=$(sudo certbot certificates 2>/dev/null | grep "Expiry Date" | head -1)
    log "Current certificate: ${CERT_EXPIRY}"
    
    # Try to renew if within 30 days of expiration
    log "Attempting renewal if needed..."
    sudo certbot renew --quiet --nginx || log "Renewal not needed or failed"
else
    log "Obtaining new SSL certificate for ${CERTBOT_DOMAIN}..."
    
    # First, ensure nginx is running
    sudo systemctl start nginx || log "Nginx not started yet"
    sleep 3
    
    # Check if nginx is actually running
    if ! sudo systemctl is-active --quiet nginx; then
        log "WARNING: Nginx is not running. Attempting to start..."
        sudo systemctl start nginx
        sleep 5
    fi
    
    # Verify domain is accessible
    log "Checking if domain is accessible..."
    if curl -s -o /dev/null -w "%{http_code}" "http://${CERTBOT_DOMAIN}" | grep -q "200\|301\|302"; then
        log "Domain is accessible, proceeding with certificate acquisition"
    else
        log "WARNING: Domain may not be accessible yet. Status: $(curl -s -o /dev/null -w "%{http_code}" "http://${CERTBOT_DOMAIN}" || echo "failed")"
    fi
    
    # Obtain certificate with extended renewal window
    # Note: Let's Encrypt certificates are always valid for 90 days
    # We configure aggressive renewal (at 60 days) to ensure plenty of time
    sudo certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "${CERTBOT_EMAIL}" \
        --domains "${CERTBOT_DOMAIN}" \
        --redirect \
        --renew-by-default \
        --rsa-key-size 4096 \
        --debug 2>&1 | tee -a "$LOG_FILE"
    
    CERTBOT_EXIT_CODE=$?
    log "Certbot exit code: ${CERTBOT_EXIT_CODE}"
    
    if [ $CERTBOT_EXIT_CODE -ne 0 ]; then
        log "ERROR: Certbot failed to obtain certificate"
        log "This might be due to:"
        log "1. Domain DNS not pointing to this server"
        log "2. Port 80/443 not accessible"
        log "3. Nginx configuration issues"
        exit 1
    fi
    
    log "Certificate obtained successfully"
fi

# Setup automatic renewal cron job
# Runs once daily at 3 AM and renews certificates that expire within 30 days
log "Setting up automatic certificate renewal..."
cat > /tmp/certbot-renew << 'EOF'
# Certbot automatic renewal - runs once daily at 3 AM
# Renews certificates within 30 days of expiration
0 3 * * * root /usr/bin/certbot renew --quiet --nginx --renew-hook "systemctl reload nginx" >> /var/log/letsencrypt/renew.log 2>&1
EOF

sudo mv /tmp/certbot-renew /etc/cron.d/certbot-renew
sudo chmod 644 /etc/cron.d/certbot-renew
sudo mkdir -p /var/log/letsencrypt
log "Auto-renewal cron job configured (runs daily at 3 AM)"

# Restart and verify nginx
log "Restarting nginx..."
sudo systemctl restart nginx
sleep 3

# Verify nginx configuration
log "Verifying nginx configuration..."
if sudo nginx -t 2>&1 | tee -a "$LOG_FILE"; then
    log "Nginx configuration is valid"
else
    log "ERROR: Nginx configuration test failed"
    log "Nginx error log:"
    sudo tail -30 /var/log/nginx/error.log | tee -a "$LOG_FILE"
    exit 1
fi

# Forcereload nginx to ensure SSL config is active
log "Reloading nginx to apply SSL configuration..."
sudo systemctl reload nginx
sleep 2

# Check if HTTPS is listening
log "Checking if HTTPS port 443 is listening..."
if sudo netstat -tuln | grep :443 >> "$LOG_FILE"; then
    log "✓ HTTPS port 443 is listening"
else
    log "✗ WARNING: Port 443 is not listening!"
    log "Checking nginx processes..."
    sudo ps aux | grep nginx | tee -a "$LOG_FILE"
fi

# Check nginx SSL configuration
log "Checking nginx SSL configuration..."
if sudo grep -r "ssl_certificate" /etc/nginx/ >> "$LOG_FILE" 2>&1; then
    log "✓ SSL certificate configuration found in nginx"
else
    log "✗ WARNING: No SSL certificate configuration found in nginx!"
fi

# Display certificate information
log "Certificate details:"
sudo certbot certificates 2>&1 | tee -a "$LOG_FILE"

# Show recent nginx errors if any
if [ -f /var/log/nginx/error.log ]; then
    log "Recent nginx errors (if any):"
    sudo tail -20 /var/log/nginx/error.log | tee -a "$LOG_FILE"
fi

log "=== Certbot Setup Complete ==="
log "Certificates will auto-renew when they have 30 days or less remaining"
log "Auto-renewal check runs daily at 3 AM"
log "Log file: ${LOG_FILE}"

exit 0
