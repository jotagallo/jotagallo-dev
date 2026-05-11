#!/bin/bash
# Quick HTTPS Fix Script
# Run this on your EB instance to immediately fix HTTPS configuration

set -e

echo "================================"
echo "HTTPS Quick Fix Script"
echo "================================"
echo ""

# Get domain from environment
DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")

if [ -z "$DOMAIN" ]; then
    echo "ERROR: CERTBOT_DOMAIN not found in environment"
    echo "Please provide domain manually:"
    read -p "Domain: " DOMAIN
fi

echo "Domain: $DOMAIN"
echo ""

# Check if certificates exist
echo "1. Checking certificates..."
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
    echo "   ✓ Certificates found for ${DOMAIN}"
    sudo certbot certificates | grep -A 5 "${DOMAIN}"
else
    echo "   ✗ No certificates found for ${DOMAIN}"
    echo "   Please run certbot first to obtain certificates"
    exit 1
fi
echo ""

# Reconfigure nginx
echo "2. Reconfiguring nginx with SSL..."
sudo certbot install \
    --non-interactive \
    --nginx \
    --cert-name ${DOMAIN} \
    --redirect

if [ $? -eq 0 ]; then
    echo "   ✓ Nginx reconfigured successfully"
else
    echo "   ✗ Failed to reconfigure nginx"
    echo "   Trying force reinstall..."
    sudo certbot install \
        --non-interactive \
        --nginx \
        --cert-name ${DOMAIN} \
        --redirect \
        --reinstall
fi
echo ""

# Test nginx configuration
echo "3. Testing nginx configuration..."
if sudo nginx -t 2>&1; then
    echo "   ✓ Nginx configuration is valid"
else
    echo "   ✗ Nginx configuration has errors"
    echo "   Check /var/log/nginx/error.log for details"
fi
echo ""

# Restart nginx
echo "4. Restarting nginx..."
sudo systemctl restart nginx
sleep 3

if sudo systemctl is-active --quiet nginx; then
    echo "   ✓ Nginx is running"
else
    echo "   ✗ Nginx failed to start"
    sudo systemctl status nginx
    exit 1
fi
echo ""

# Check if port 443 is listening
echo "5. Checking if HTTPS port 443 is listening..."
if sudo netstat -tuln 2>/dev/null | grep :443 || sudo ss -tuln 2>/dev/null | grep :443; then
    echo "   ✓ Port 443 is listening"
else
    echo "   ✗ Port 443 is NOT listening"
    echo "   This is a problem. Checking nginx config..."
    sudo grep -r "listen.*443" /etc/nginx/ || echo "   No 443 listener found in nginx configs"
fi
echo ""

# Test HTTPS locally
echo "6. Testing HTTPS connection..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost" 2>/dev/null || echo "failed")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "   ✓ HTTPS is responding (HTTP $HTTP_CODE)"
else
    echo "   ⚠ HTTPS response: $HTTP_CODE"
fi
echo ""

# Test domain
echo "7. Testing domain HTTPS..."
DOMAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null || echo "failed")
if [ "$DOMAIN_CODE" = "200" ] || [ "$DOMAIN_CODE" = "301" ] || [ "$DOMAIN_CODE" = "302" ]; then
    echo "   ✓ https://${DOMAIN} is responding (HTTP $DOMAIN_CODE)"
else
    echo "   ⚠ https://${DOMAIN} response: $DOMAIN_CODE"
fi
echo ""

# Summary
echo "================================"
echo "Summary"
echo "================================"
echo "Certificate: $(sudo ls -1 /etc/letsencrypt/live/ | grep -v README | head -1)"
echo "Nginx status: $(sudo systemctl is-active nginx)"
echo "Port 443: $(sudo netstat -tuln 2>/dev/null | grep :443 | wc -l | xargs echo) listener(s)"
echo ""
echo "Check full logs:"
echo "  sudo cat /var/log/certbot_deploy.log"
echo "  sudo tail -50 /var/log/nginx/error.log"
echo ""
echo "Test in browser: https://${DOMAIN}"
echo "================================"
