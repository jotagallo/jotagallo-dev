#!/bin/bash
# Verify HTTPS is Working
set -e

LOG_FILE="/var/log/certbot_verify.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== HTTPS Verification ==="

# Get domain
CERTBOT_DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")

if [ -z "$CERTBOT_DOMAIN" ]; then
    log "ERROR: CERTBOT_DOMAIN not set"
    exit 1
fi

log "Domain: ${CERTBOT_DOMAIN}"

# Check if port 443 is listening
log "Checking if port 443 is listening..."
if sudo netstat -tuln 2>/dev/null | grep :443 | tee -a "$LOG_FILE"; then
    log "✓ Port 443 is LISTENING"
elif sudo ss -tuln 2>/dev/null | grep :443 | tee -a "$LOG_FILE"; then
    log "✓ Port 443 is LISTENING (via ss)"
else
    log "✗ ERROR: Port 443 is NOT listening!"
    log "This is a critical issue - HTTPS will not work"
    
    # Show what ports ARE listening
    log "Ports currently listening:"
    sudo netstat -tuln 2>/dev/null | grep LISTEN | tee -a "$LOG_FILE" || sudo ss -tuln | grep LISTEN | tee -a "$LOG_FILE"
    
    # Check nginx processes
    log "Nginx processes:"
    sudo ps aux | grep nginx | tee -a "$LOG_FILE"
fi

# Check nginx user and permissions
log "Checking nginx user..."
NGINX_USER=$(ps aux | grep nginx | grep -v grep | grep worker | awk '{print $1}' | head -1)
log "Nginx is running as user: ${NGINX_USER}"

# Verify nginx can read certificates
log "Verifying nginx can read certificate files..."
if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ]; then
    log "Certificate file ownership and permissions:"
    sudo ls -lah "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/" | tee -a "$LOG_FILE"
    
    # Test if nginx user can read the cert (nginx usually runs as root/nginx)
    if [ "$NGINX_USER" = "root" ]; then
        log "✓ Nginx runs as root, can read certificates"
    else
        log "Nginx runs as ${NGINX_USER}, checking access..."
        if sudo -u ${NGINX_USER} test -r "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" 2>/dev/null; then
            log "✓ ${NGINX_USER} can read certificates"
        else
            log "✗ WARNING: ${NGINX_USER} cannot read certificates!"
            log "This could be a permissions issue"
        fi
    fi
else
    log "✗ Certificate file not found!"
fi

# Display certificate details
log "Certificate information:"
sudo certbot certificates 2>&1 | tee -a "$LOG_FILE"

# Test HTTPS locally
log "Testing HTTPS connection to localhost..."
LOCALHOST_HTTPS=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost" 2>/dev/null || echo "failed")
log "HTTPS localhost response: ${LOCALHOST_HTTPS}"

# Test domain HTTPS
log "Testing HTTPS connection to ${CERTBOT_DOMAIN}..."
DOMAIN_HTTPS=$(curl -s -o /dev/null -w "%{http_code}" "https://${CERTBOT_DOMAIN}" 2>/dev/null || echo "failed")
log "HTTPS ${CERTBOT_DOMAIN} response: ${DOMAIN_HTTPS}"

# Show recent nginx errors
log "Recent nginx errors (if any):"
sudo tail -20 /var/log/nginx/error.log | tee -a "$LOG_FILE" || log "No nginx error log found"

# Summary
log "================================"
log "VERIFICATION SUMMARY"
log "================================"
log "Domain: ${CERTBOT_DOMAIN}"
log "Port 443 listening: $(sudo netstat -tuln 2>/dev/null | grep :443 > /dev/null && echo 'YES' || echo 'NO')"
log "Nginx running: $(sudo systemctl is-active nginx)"
log "Certificate exists: $([ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ] && echo 'YES' || echo 'NO')"
log "HTTPS localhost: ${LOCALHOST_HTTPS}"
log "HTTPS domain: ${DOMAIN_HTTPS}"
log "================================"

# Exit with error if port 443 is not listening
if ! sudo netstat -tuln 2>/dev/null | grep :443 > /dev/null && ! sudo ss -tuln 2>/dev/null | grep :443 > /dev/null; then
    log "CRITICAL: Port 443 is not listening - HTTPS will not work!"
    exit 1
fi

log "=== Verification Complete ==="
exit 0
