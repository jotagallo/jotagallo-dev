# HTTPS Not Responding - Diagnostic Steps

## Quick Diagnosis Commands

SSH into your EB instance and run these commands:

### 1. Check if certificates exist
```bash
sudo certbot certificates
sudo ls -la /etc/letsencrypt/live/
```

### 2. Check if nginx is listening on port 443
```bash
sudo netstat -tuln | grep :443
# or
sudo ss -tuln | grep :443
```
**Expected:** Should show `0.0.0.0:443` or `:::443` LISTEN

### 3. Check nginx configuration for SSL
```bash
sudo nginx -t
sudo grep -r "listen.*443" /etc/nginx/
sudo grep -r "ssl_certificate" /etc/nginx/
```
**Expected:** Should find SSL configuration in nginx files

### 4. Check deployment logs
```bash
sudo cat /var/log/certbot_deploy.log
```

### 5. Check nginx error logs
```bash
sudo tail -50 /var/log/nginx/error.log
```

### 6. Test HTTPS locally on the instance
```bash
curl -I https://localhost
curl -I https://yourdomain.com
```

### 7. Check if nginx is running
```bash
sudo systemctl status nginx
```

---

## Common Issues and Quick Fixes

### Issue 1: Port 443 Not Listening

**Symptom:** `netstat` shows no process on port 443

**Fix:**
```bash
# Reconfigure nginx with existing certificates
sudo certbot install --nginx --cert-name yourdomain.com --redirect

# Restart nginx
sudo systemctl restart nginx

# Verify
sudo netstat -tuln | grep :443
```

### Issue 2: Nginx Configuration Lost After Deployment

**Symptom:** Certificates exist but nginx not configured for SSL

**Fix:**
```bash
# Force certbot to reconfigure nginx
sudo certbot install --nginx --cert-name yourdomain.com --redirect --force

# Reload nginx
sudo systemctl reload nginx
```

### Issue 3: Nginx Config Has Errors

**Symptom:** `nginx -t` shows errors

**Fix:**
```bash
# Check what's wrong
sudo nginx -t

# View nginx configs
sudo ls -la /etc/nginx/conf.d/
sudo cat /etc/nginx/conf.d/*.conf

# If configs are broken, remove and reinstall
sudo rm /etc/nginx/conf.d/*ssl*.conf
sudo certbot install --nginx --cert-name yourdomain.com --redirect
sudo nginx -t
sudo systemctl restart nginx
```

### Issue 4: Certificate Files Missing or Invalid

**Symptom:** Certbot says certificates exist but files are missing

**Fix:**
```bash
# Check certificate status
sudo certbot certificates

# If broken, delete and recreate
sudo certbot delete --cert-name yourdomain.com
sudo certbot --nginx --email your@email.com --domains yourdomain.com --agree-tos --redirect --rsa-key-size 4096
```

---

## Force Reconfiguration

If HTTPS stopped working after a deployment:

```bash
# This forces certbot to reconfigure nginx with existing certs
sudo certbot install --nginx --cert-name yourdomain.com --redirect --reinstall

# Restart nginx
sudo systemctl restart nginx
sleep 2

# Verify
sudo netstat -tuln | grep :443
curl -I https://yourdomain.com
```

---

## Manual Nginx SSL Configuration (Emergency)

If certbot fails completely, manually configure nginx:

### 1. Check certificate location
```bash
DOMAIN="yourdomain.com"
sudo ls -la /etc/letsencrypt/live/${DOMAIN}/
```

### 2. Create nginx SSL config
```bash
DOMAIN="yourdomain.com"

sudo tee /etc/nginx/conf.d/ssl_custom.conf > /dev/null <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}
EOF
```

### 3. Test and restart
```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

## Check AWS Security Group

Ensure port 443 is open:

1. Go to AWS Console → EC2 → Security Groups
2. Find your Elastic Beanstalk security group
3. Check Inbound Rules for:
   - Type: HTTPS
   - Port: 443
   - Source: 0.0.0.0/0 (or your IP range)

Or use AWS CLI:
```bash
# Get your instance security group
aws ec2 describe-instances --filters "Name=tag:elasticbeanstalk:environment-name,Values=YOUR_ENV_NAME" --query 'Reservations[*].Instances[*].SecurityGroups'

# Check inbound rules
aws ec2 describe-security-groups --group-ids sg-XXXXXXXX
```

---

## Check Elastic Beanstalk Load Balancer

If you're using a load balancer:

1. Go to EC2 → Load Balancers
2. Find your EB load balancer
3. Check Listeners tab:
   - Should have listener on port 443
   - Should forward to instances on port 443 or 80

---

## Immediate Fix (SSH to Instance)

Run this to quickly fix HTTPS:

```bash
#!/bin/bash
DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN)

echo "Domain: $DOMAIN"
echo "Reconfiguring nginx for HTTPS..."

# Reconfigure nginx with existing cert
sudo certbot install --nginx --cert-name $DOMAIN --redirect --reinstall

# Restart nginx
sudo systemctl restart nginx
sleep 3

# Verify
echo "Checking port 443..."
if sudo netstat -tuln | grep :443; then
  echo "✓ Port 443 is listening"
else
  echo "✗ Port 443 NOT listening"
fi

echo "Testing HTTPS..."
curl -I https://${DOMAIN} 2>&1 | head -5
```

Save this as `fix-https.sh`, upload to your instance, and run:
```bash
chmod +x fix-https.sh
sudo ./fix-https.sh
```

---

## After Fixing - Redeploy

Once you've manually fixed it, redeploy your application so the fix in `.ebextensions/10_install_certbot.config` applies on future deployments:

```bash
eb deploy
# or
git commit -am "Fix HTTPS configuration"
eb deploy
```

---

## Get Help

If still not working, provide these logs:
- `/var/log/certbot_deploy.log`
- `/var/log/nginx/error.log`
- Output of `sudo certbot certificates`
- Output of `sudo nginx -t`
- Output of `sudo netstat -tuln | grep -E '(80|443)'`
