# Port 443 / HTTPS Investigation

## Problem: Certificate exists but port 443 not listening

### Certificate Permissions - This is NORMAL

The certificates in `/etc/letsencrypt/live/` require sudo because:
- They're owned by `root:root`
- Permissions are typically `0644` (readable by owner, group, others)
- This is **correct and expected** behavior

**Why this works:**
- Nginx master process runs as **root**
- Root can read these files without issues
- Worker processes inherit the file descriptors from master

### The Real Issue

If port 443 isn't listening, the problem is **NOT permissions**. It's one of these:

1. **Nginx not configured for SSL** - Most likely!
   - Certificate exists but nginx config wasn't updated
   - Certbot didn't modify nginx configuration
   - Nginx config was reset by deployment

2. **Nginx configuration errors**
   - Syntax errors preventing nginx from starting
   - Missing SSL directives
   - Wrong certificate paths

3. **Nginx not restarted after configuration**
   - Changes not applied
   - Old configuration still active

## New Modular Scripts

I've created separate scripts for each step:

### 1. `bin/01-install-certbot.sh`
- Installs certbot if not present
- Sets up Python virtual environment
- Creates `/usr/bin/certbot` symlink
- Logs to: `/var/log/certbot_install.log`

### 2. `bin/02-setup-certificate.sh`
- Obtains new certificate OR reconfigures nginx with existing cert
- **KEY FIX:** Always runs `certbot install --nginx` if cert exists
- Verifies certificate files and permissions
- Logs to: `/var/log/certbot_certificate.log`

### 3. `bin/03-configure-nginx.sh`
- Verifies nginx configuration
- Checks for SSL directives
- Restarts and reloads nginx
- Logs to: `/var/log/certbot_nginx.log`

### 4. `bin/04-verify-https.sh`
- **Checks port 443 listening status**
- Verifies nginx can read certificates
- Tests HTTPS connections
- **FAILS if port 443 not listening**
- Logs to: `/var/log/certbot_verify.log`

### 5. `bin/05-setup-renewal.sh`
- Creates auto-renewal cron job (3 AM daily)
- Sets up log directory
- Logs to: `/var/log/certbot_renewal_setup.log`

## Diagnostic Script

### `bin/diagnose-port-443.sh`
Comprehensive diagnostic tool that checks:
- ✓ Certificate files exist and permissions
- ✓ Nginx user and ability to read certificates  
- ✓ Nginx configuration validity
- ✓ SSL directives in nginx
- ✓ Port 443 listening status
- ✓ HTTPS connection tests
- ✓ Recent error logs

**Run this on your EB instance to investigate the issue:**
```bash
sudo /var/app/current/bin/diagnose-port-443.sh
```

## Updated .ebextensions Config

The new `10_install_certbot.config` now calls scripts in sequence:
1. Install certbot
2. Setup certificate (with nginx reconfiguration)
3. Configure nginx
4. Verify HTTPS is working
5. Setup auto-renewal

Each step is isolated, making debugging much easier.

## How to Debug the Issue

### Step 1: Run diagnostics on your EB instance
```bash
# SSH into your EB instance
eb ssh

# Run comprehensive diagnostics
sudo /var/app/current/bin/diagnose-port-443.sh
```

This will tell you:
- Are certificates present?
- Can nginx read them? (spoiler: yes, if nginx runs as root)
- Is nginx configured for SSL?
- Is port 443 listening?

### Step 2: Check the logs
```bash
# Check each step's log
sudo cat /var/log/certbot_install.log
sudo cat /var/log/certbot_certificate.log
sudo cat /var/log/certbot_nginx.log
sudo cat /var/log/certbot_verify.log
sudo tail -50 /var/log/nginx/error.log
```

### Step 3: Most likely fix
If certificates exist but port 443 isn't listening:

```bash
# Force nginx reconfiguration with existing certificate
DOMAIN=$(/opt/elasticbeanstalk/bin/get-config environment -k CERTBOT_DOMAIN)
sudo certbot install --nginx --cert-name $DOMAIN --redirect --reinstall

# Restart nginx
sudo systemctl restart nginx

# Verify
sudo netstat -tuln | grep :443
```

## Why Port 443 Might Not Be Listening

### Reason 1: Nginx not configured (MOST COMMON)
Certbot created certificates but didn't modify nginx config.

**Fix:** Run `certbot install --nginx`

### Reason 2: Nginx config has errors
SSL configuration has syntax errors.

**Fix:** 
```bash
sudo nginx -t  # Check for errors
sudo tail -50 /var/log/nginx/error.log  # See what's wrong
```

### Reason 3: Nginx not restarted
Configuration changes weren't applied.

**Fix:**
```bash
sudo systemctl restart nginx
```

### Reason 4: Wrong certificate paths
Nginx is looking for certificates in wrong location.

**Fix:** Check nginx config has correct paths:
```bash
sudo grep -r "ssl_certificate" /etc/nginx/
# Should show: /etc/letsencrypt/live/yourdomain.com/fullchain.pem
```

## Certificate Permissions Explained

```bash
$ sudo ls -lah /etc/letsencrypt/live/yourdomain.com/
drwxr-xr-x 2 root root  93 May 10 15:30 .
lrwxrwxrwx 1 root root  37 May 10 15:30 fullchain.pem -> ../../archive/yourdomain.com/fullchain1.pem
lrwxrwxrwx 1 root root  35 May 10 15:30 privkey.pem -> ../../archive/yourdomain.com/privkey1.pem
```

- **Owner:** root:root - CORRECT
- **Permissions:** 644 (readable by all) - CORRECT
- **Symlinks:** Point to /etc/letsencrypt/archive/ - CORRECT

**Nginx master runs as root, so it can read these files.**

The "need sudo" to view them is normal - YOU need sudo because you're not root. But nginx master IS root, so it has no problem.

## Testing After Deployment

After deploying with the new scripts:

```bash
# 1. Check deployment was successful
eb ssh
cd /var/app/current

# 2. Verify all scripts ran
ls -la /var/log/certbot_*.log

# 3. Run diagnostics
sudo ./bin/diagnose-port-443.sh

# 4. If port 443 not listening, run fix
sudo ./bin/fix-https.sh
```

## Next Steps

1. **Deploy the updated configuration:**
   ```bash
   git add .ebextensions/10_install_certbot.config bin/
   git commit -m "Modular certbot setup with diagnostics"
   git push
   eb deploy
   ```

2. **After deployment, SSH in and check:**
   ```bash
   eb ssh
   sudo /var/app/current/bin/diagnose-port-443.sh
   ```

3. **If still broken, the diagnostic output will tell you exactly what's wrong**

The modular scripts will make it much clearer which step is failing!
