#!/bin/bash
# Install Certbot
set -e

LOG_FILE="/var/log/certbot_install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Installing Certbot ==="

if [ -f /usr/bin/certbot ]; then
    log "Certbot already installed at /usr/bin/certbot"
    /usr/bin/certbot --version | tee -a "$LOG_FILE"
    exit 0
fi

log "Installing dependencies..."
sudo dnf install -y augeas-libs python3-pip 2>&1 | tee -a "$LOG_FILE"

log "Creating Python virtual environment..."
sudo python3 -m venv /opt/certbot/ 2>&1 | tee -a "$LOG_FILE"

log "Upgrading pip..."
sudo /opt/certbot/bin/pip install --upgrade pip 2>&1 | tee -a "$LOG_FILE"

log "Installing certbot and certbot-nginx..."
sudo /opt/certbot/bin/pip install certbot certbot-nginx 2>&1 | tee -a "$LOG_FILE"

log "Creating symlink to /usr/bin/certbot..."
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot

if [ -f /usr/bin/certbot ]; then
    log "✓ Certbot installed successfully"
    /usr/bin/certbot --version | tee -a "$LOG_FILE"
else
    log "✗ ERROR: Certbot installation failed"
    exit 1
fi

log "=== Certbot Installation Complete ==="
exit 0
