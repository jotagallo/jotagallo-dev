#!/bin/bash
# Obtain or Reconfigure SSL Certificate
set -e

LOG_FILE="/var/log/certbot_certificate.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== SSL Certificate Setup ==="

# Get environment variables
CERTBOT_EMAIL=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_EMAIL 2>/dev/null || echo "")
CERTBOT_DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")

if [ -z "$CERTBOT_EMAIL" ] || [ -z "$CERTBOT_DOMAIN" ]; then
    log "ERROR: CERTBOT_EMAIL or CERTBOT_DOMAIN not set in environment variables"
    exit 1
fi

log "Email: ${CERTBOT_EMAIL}"
log "Domain: ${CERTBOT_DOMAIN}"

# Check if certificates exist
if [ -d "/etc/letsencrypt/live/${CERTBOT_DOMAIN}" ]; then
    log "Certificate directory exists for ${CERTBOT_DOMAIN}"
    
    # Verify certificate files
    log "Checking certificate files..."
    if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ]; then
        log "✓ fullchain.pem exists"
        sudo ls -lah "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" | tee -a "$LOG_FILE"
    else
        log "✗ fullchain.pem NOT found"
    fi
    
    if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/privkey.pem" ]; then
        log "✓ privkey.pem exists"
        sudo ls -lah "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/privkey.pem" | tee -a "$LOG_FILE"
    else
        log "✗ privkey.pem NOT found"
    fi
    
    # Check certificate expiration
    log "Certificate details:"
    sudo certbot certificates 2>&1 | tee -a "$LOG_FILE"
    
    # Reconfigure nginx with existing certificate
    log "Reconfiguring nginx with existing certificate..."
    sudo certbot install \
        --non-interactive \
        --nginx \
        --cert-name "${CERTBOT_DOMAIN}" \
        --redirect 2>&1 | tee -a "$LOG_FILE"
    
    INSTALL_EXIT=$?
    log "Certbot install exit code: ${INSTALL_EXIT}"
    
    if [ $INSTALL_EXIT -ne 0 ]; then
        log "WARNING: certbot install failed, trying --reinstall..."
        sudo certbot install \
            --non-interactive \
            --nginx \
            --cert-name "${CERTBOT_DOMAIN}" \
            --redirect \
            --reinstall 2>&1 | tee -a "$LOG_FILE"
        log "Certbot reinstall exit code: $?"
    fi
    
else
    log "No certificate found, obtaining new certificate..."
    
    # Ensure nginx is running before certbot
    if ! sudo systemctl is-active --quiet nginx; then
        log "Nginx not running, starting it..."
        sudo systemctl start nginx
        sleep 3
    fi
    
    # Obtain new certificate
    sudo certbot --nginx \
        --non-interactive \
        --agree-tos \
        --email "${CERTBOT_EMAIL}" \
        --domains "${CERTBOT_DOMAIN}" \
        --redirect \
        --rsa-key-size 4096 2>&1 | tee -a "$LOG_FILE"
    
    CERTBOT_EXIT=$?
    log "Certbot exit code: ${CERTBOT_EXIT}"
    
    if [ $CERTBOT_EXIT -ne 0 ]; then
        log "ERROR: Failed to obtain certificate"
        exit 1
    fi
    
    log "✓ Certificate obtained successfully"
fi

# Verify certificate permissions
log "Checking certificate permissions..."
sudo ls -lah "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/" | tee -a "$LOG_FILE"
sudo ls -lah /etc/letsencrypt/archive/ | tee -a "$LOG_FILE"

log "=== Certificate Setup Complete ==="
exit 0
