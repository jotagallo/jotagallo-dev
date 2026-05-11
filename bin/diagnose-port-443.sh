#!/bin/bash
# Comprehensive Port 443 Diagnostics
# Run this on your EB instance to investigate why HTTPS isn't working

echo "========================================"
echo "PORT 443 / HTTPS DIAGNOSTICS"
echo "========================================"
echo ""

# Get domain
CERTBOT_DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN 2>/dev/null || echo "")
if [ -z "$CERTBOT_DOMAIN" ]; then
    echo "⚠ WARNING: CERTBOT_DOMAIN not found in environment"
    read -p "Enter your domain: " CERTBOT_DOMAIN
fi

echo "Domain: ${CERTBOT_DOMAIN}"
echo ""

# 1. Check if certificates exist
echo "1. CERTIFICATE FILES"
echo "-------------------"
if [ -d "/etc/letsencrypt/live/${CERTBOT_DOMAIN}" ]; then
    echo "✓ Certificate directory exists"
    echo ""
    echo "Directory contents:"
    sudo ls -lah "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/"
    echo ""
    echo "Certificate file details:"
    for file in fullchain.pem privkey.pem cert.pem chain.pem; do
        if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/${file}" ]; then
            echo "  ✓ ${file} exists"
            sudo ls -lh "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/${file}"
        else
            echo "  ✗ ${file} MISSING"
        fi
    done
else
    echo "✗ Certificate directory does NOT exist"
    echo "  Expected path: /etc/letsencrypt/live/${CERTBOT_DOMAIN}"
fi
echo ""

# 2. Check certificate permissions and ownership
echo "2. CERTIFICATE PERMISSIONS"
echo "-------------------------"
if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ]; then
    echo "Ownership and permissions of certificate files:"
    sudo stat "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" | grep -E "(Access|Uid|Gid)"
    echo ""
    echo "These files are symlinks to:"
    sudo readlink -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem"
    echo ""
    echo "Actual file permissions:"
    ACTUAL_CERT=$(sudo readlink -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem")
    sudo ls -lah "$ACTUAL_CERT"
    sudo stat "$ACTUAL_CERT" | grep -E "(Access|Uid|Gid)"
fi
echo ""

# 3. Check nginx user
echo "3. NGINX USER & PERMISSIONS"
echo "---------------------------"
NGINX_MASTER=$(ps aux | grep "nginx: master" | grep -v grep | awk '{print $1}')
NGINX_WORKER=$(ps aux | grep "nginx: worker" | grep -v grep | awk '{print $1}' | head -1)
echo "Nginx master process runs as: ${NGINX_MASTER}"
echo "Nginx worker process runs as: ${NGINX_WORKER}"
echo ""

if [ -f "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" ]; then
    echo "Testing if nginx can read certificate files:"
    
    # Test master process user
    if [ ! -z "$NGINX_MASTER" ]; then
        if [ "$NGINX_MASTER" = "root" ]; then
            echo "  ✓ Master runs as root - can read certificates"
        else
            if sudo -u ${NGINX_MASTER} test -r "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" 2>/dev/null; then
                echo "  ✓ User ${NGINX_MASTER} can read certificates"
            else
                echo "  ✗ User ${NGINX_MASTER} CANNOT read certificates"
            fi
        fi
    fi
    
    # Test worker process user
    if [ ! -z "$NGINX_WORKER" ]; then
        if [ "$NGINX_WORKER" = "root" ]; then
            echo "  ✓ Worker runs as root - can read certificates"
        else
            if sudo -u ${NGINX_WORKER} test -r "/etc/letsencrypt/live/${CERTBOT_DOMAIN}/fullchain.pem" 2>/dev/null; then
                echo "  ✓ User ${NGINX_WORKER} can read certificates"
            else
                echo "  ✗ User ${NGINX_WORKER} CANNOT read certificates"
            fi
        fi
    fi
fi
echo ""

# 4. Check nginx configuration
echo "4. NGINX CONFIGURATION"
echo "---------------------"
echo "Nginx config test:"
if sudo nginx -t 2>&1; then
    echo "✓ Nginx configuration is valid"
else
    echo "✗ Nginx configuration has ERRORS"
fi
echo ""

echo "Checking for SSL configuration:"
if sudo grep -r "listen.*443" /etc/nginx/ 2>/dev/null; then
    echo "✓ Found 443 listener(s) in nginx config"
else
    echo "✗ NO 443 listener found in nginx config"
fi
echo ""

echo "Checking for SSL certificate directives:"
if sudo grep -r "ssl_certificate" /etc/nginx/ 2>/dev/null | grep -v "#"; then
    echo "✓ Found SSL certificate directives"
else
    echo "✗ NO SSL certificate directives found"
fi
echo ""

echo "All nginx configuration files:"
sudo find /etc/nginx/ -type f -name "*.conf" -o -name "nginx.conf"
echo ""

# 5. Check if nginx is running
echo "5. NGINX STATUS"
echo "--------------"
if sudo systemctl is-active --quiet nginx; then
    echo "✓ Nginx is RUNNING"
    sudo systemctl status nginx --no-pager | head -10
else
    echo "✗ Nginx is NOT running"
    sudo systemctl status nginx --no-pager
fi
echo ""

# 6. Check if port 443 is listening
echo "6. PORT 443 STATUS"
echo "-----------------"
echo "Checking with netstat:"
if sudo netstat -tuln 2>/dev/null | grep :443; then
    echo "✓ Port 443 is LISTENING"
else
    echo "✗ Port 443 is NOT listening (netstat)"
fi
echo ""

echo "Checking with ss:"
if sudo ss -tuln 2>/dev/null | grep :443; then
    echo "✓ Port 443 is LISTENING"
else
    echo "✗ Port 443 is NOT listening (ss)"
fi
echo ""

echo "All listening ports:"
sudo netstat -tuln 2>/dev/null | grep LISTEN || sudo ss -tuln | grep LISTEN
echo ""

# 7. Check firewall/iptables
echo "7. FIREWALL STATUS"
echo "-----------------"
if command -v iptables &> /dev/null; then
    echo "iptables rules for port 443:"
    sudo iptables -L -n | grep -i 443 || echo "No specific rules for port 443"
fi
echo ""

# 8. Test HTTPS connection
echo "8. HTTPS CONNECTION TEST"
echo "-----------------------"
echo "Testing localhost HTTPS:"
LOCALHOST_TEST=$(curl -k -s -o /dev/null -w "%{http_code}" "https://localhost" 2>&1 || echo "failed")
echo "  Response code: ${LOCALHOST_TEST}"

echo "Testing domain HTTPS:"
DOMAIN_TEST=$(curl -s -o /dev/null -w "%{http_code}" "https://${CERTBOT_DOMAIN}" 2>&1 || echo "failed")
echo "  Response code: ${DOMAIN_TEST}"
echo ""

# 9. Check nginx error logs
echo "9. NGINX ERROR LOG (last 30 lines)"
echo "-----------------------------------"
if [ -f /var/log/nginx/error.log ]; then
    sudo tail -30 /var/log/nginx/error.log
else
    echo "No error log found"
fi
echo ""

# 10. Check certbot logs
echo "10. CERTBOT LOGS"
echo "---------------"
if [ -f /var/log/certbot_deploy.log ]; then
    echo "Last deployment log:"
    sudo tail -50 /var/log/certbot_deploy.log
fi
echo ""

# Summary
echo "========================================"
echo "DIAGNOSTIC SUMMARY"
echo "========================================"
echo "Domain: ${CERTBOT_DOMAIN}"
echo "Certificates exist: $([ -d "/etc/letsencrypt/live/${CERTBOT_DOMAIN}" ] && echo 'YES' || echo 'NO')"
echo "Nginx running: $(sudo systemctl is-active nginx 2>/dev/null || echo 'unknown')"
echo "Nginx config valid: $(sudo nginx -t 2>&1 > /dev/null && echo 'YES' || echo 'NO')"
echo "Port 443 listening: $(sudo netstat -tuln 2>/dev/null | grep :443 > /dev/null && echo 'YES' || echo 'NO')"
echo "SSL in nginx config: $(sudo grep -r "listen.*443" /etc/nginx/ 2>/dev/null > /dev/null && echo 'YES' || echo 'NO')"
echo "HTTPS localhost: ${LOCALHOST_TEST}"
echo "HTTPS domain: ${DOMAIN_TEST}"
echo ""
echo "LOG FILES TO CHECK:"
echo "  - /var/log/certbot_install.log"
echo "  - /var/log/certbot_certificate.log"
echo "  - /var/log/certbot_nginx.log"
echo "  - /var/log/certbot_verify.log"
echo "  - /var/log/nginx/error.log"
echo "  - /var/log/nginx/access.log"
echo "========================================"
