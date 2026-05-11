#!/bin/bash
# Setup Auto-Renewal Cron Job
set -e

LOG_FILE="/var/log/certbot_renewal_setup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Setting Up Auto-Renewal ==="

# Create log directory
sudo mkdir -p /var/log/letsencrypt
log "Created log directory: /var/log/letsencrypt"

# Create cron job
log "Creating cron job for daily renewal check at 3 AM..."
echo "0 3 * * * root /usr/bin/certbot renew --quiet --nginx --renew-hook 'systemctl reload nginx' >> /var/log/letsencrypt/renew.log 2>&1" | sudo tee /etc/cron.d/certbot-renew > /dev/null

sudo chmod 644 /etc/cron.d/certbot-renew
log "✓ Cron job created: /etc/cron.d/certbot-renew"

# Show cron job
log "Cron job contents:"
sudo cat /etc/cron.d/certbot-renew | tee -a "$LOG_FILE"

log "Auto-renewal configured to run daily at 3:00 AM"
log "Certificates will be renewed when they have 30 days or less remaining"
log "Renewal logs will be written to: /var/log/letsencrypt/renew.log"

log "=== Auto-Renewal Setup Complete ==="
exit 0
