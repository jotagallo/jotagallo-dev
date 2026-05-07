# HTTPS Troubleshooting Guide

## Quick Diagnostics

If HTTPS is not working, run these commands on your EB instance:

### 1. Check if certificates exist
```bash
sudo ls -la /etc/letsencrypt/live/
sudo certbot certificates
```

### 2. Check if nginx is listening on port 443
```bash
sudo netstat -tuln | grep 443
# or
sudo ss -tuln | grep 443
```

### 3. Check nginx configuration
```bash
sudo nginx -t
sudo grep -r "listen.*443" /etc/nginx/
sudo grep -r "ssl_certificate" /etc/nginx/
```

### 4. Check deployment logs
```bash
sudo cat /var/log/certbot_deploy.log
sudo tail -50 /var/log/eb-engine.log
```

### 5. Check nginx logs
```bash
sudo tail -50 /var/log/nginx/error.log
sudo tail -50 /var/log/nginx/access.log
```

## Common Issues and Solutions

### Issue 1: Port 443 Not Listening

**Symptoms:** `netstat` shows no process on port 443

**Causes:**
- Certbot failed to configure nginx
- Nginx configuration has errors
- Certificates weren't properly installed

**Solutions:**
```bash
# Check nginx status
sudo systemctl status nginx

# Restart nginx
sudo systemctl restart nginx

# Check if SSL configuration exists
sudo ls -la /etc/nginx/conf.d/
sudo cat /etc/nginx/conf.d/https.conf  # if exists
```

### Issue 2: Certificate Not Found

**Symptoms:** Certbot says certificates don't exist

**Causes:**
- Domain not accessible during deployment
- DNS not pointing to EB environment
- Rate limiting from Let's Encrypt

**Solutions:**
1. Verify DNS points to your EB environment:
   ```bash
   nslookup yourdomain.com
   dig yourdomain.com
   ```

2. Check if domain resolves to your instance:
   ```bash
   curl -I http://yourdomain.com
   ```

3. Manually run certbot:
   ```bash
   sudo /var/app/current/bin/setup-certbot.sh
   ```

### Issue 3: Nginx Configuration Errors

**Symptoms:** `nginx -t` shows configuration errors

**Causes:**
- Certbot made invalid nginx configuration changes
- Conflicting nginx directives

**Solutions:**
```bash
# Check nginx configuration
sudo nginx -t

# View nginx error log
sudo tail -100 /var/log/nginx/error.log

# View certbot's nginx configuration
sudo ls -la /etc/nginx/conf.d/
sudo cat /etc/nginx/conf.d/*ssl*.conf
```

### Issue 4: Security Group Not Open

**Symptoms:** Connection timeout on HTTPS

**Causes:**
- AWS Security Group doesn't allow port 443

**Solutions:**
1. Check `.ebextensions/00_https_security.config` exists
2. Verify in AWS Console: EC2 → Security Groups → Your EB security group
3. Ensure inbound rule exists:
   - Type: HTTPS
   - Port: 443
   - Source: 0.0.0.0/0

### Issue 5: Domain Not Accessible

**Symptoms:** Certbot fails with "domain not accessible" error

**Causes:**
- DNS propagation not complete
- Application not responding on HTTP
- Load balancer/proxy issues

**Solutions:**
```bash
# Test if your domain is accessible
curl -v http://yourdomain.com

# Check if port 80 is open
sudo netstat -tuln | grep :80

# Verify nginx is serving HTTP
curl -H "Host: yourdomain.com" http://localhost
```

## Manual Certificate Installation

If automatic installation fails, try manual steps:

### 1. Stop nginx temporarily
```bash
sudo systemctl stop nginx
```

### 2. Obtain certificate using standalone method
```bash
sudo certbot certonly \
  --standalone \
  --non-interactive \
  --agree-tos \
  --email your-email@example.com \
  --domains yourdomain.com \
  --rsa-key-size 4096
```

### 3. Manually configure nginx
Create `/etc/nginx/conf.d/https.conf`:
```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

### 4. Test and restart nginx
```bash
sudo nginx -t
sudo systemctl start nginx
```

## Environment Variables Check

Ensure these are set in your EB environment:

```bash
# On EB instance:
/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_EMAIL
/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN
```

Should output your email and domain. If empty, set them in EB Console:
1. Go to your EB environment
2. Configuration → Software → Environment properties
3. Add: `CERTBOT_EMAIL=your-email@example.com`
4. Add: `CERTBOT_DOMAIN=yourdomain.com`

## Testing HTTPS

After fixing issues:

```bash
# Test HTTPS locally
curl -k https://localhost
curl -k https://yourdomain.com

# Test from outside
curl -v https://yourdomain.com

# Check SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
```

## Force Redeploy

If nothing works, force a redeploy:

```bash
# Locally
eb deploy --force

# Or update any file and deploy
touch .ebextensions/00_https_security.config
git add .
git commit -m "Force redeploy for SSL"
git push
eb deploy
```

## Get Help

If still stuck, provide these logs:
- `/var/log/certbot_deploy.log`
- `/var/log/nginx/error.log`
- Output of `sudo certbot certificates`
- Output of `sudo nginx -t`
- Output of `sudo netstat -tuln | grep "80\|443"`
