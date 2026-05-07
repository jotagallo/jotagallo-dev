# Certbot SSL Certificate Setup

## Overview

SSL certificate management has been migrated from `.ebextensions` to a standalone bin script with deployment hooks for better reliability and maintainability.

## Architecture

### Scripts
- **`bin/setup-certbot.sh`** - Main Certbot installation and certificate management script
- **`.platform/hooks/postdeploy/01_setup_certbot.sh`** - Deployment hook that executes after each deployment

### How It Works

1. **On Deployment**: The postdeploy hook automatically runs `bin/setup-certbot.sh`
2. **Installation**: Certbot is installed if not present (using Python venv at `/opt/certbot/`)
3. **Certificate Acquisition**: Obtains SSL certificate from Let's Encrypt for configured domain
4. **Auto-Renewal**: Sets up cron job to check renewal twice daily

## Configuration

Required environment variables in Elastic Beanstalk:
```
CERTBOT_EMAIL=your-email@example.com
CERTBOT_DOMAIN=yourdomain.com
```

## Certificate Details

### Validity Period
- Let's Encrypt certificates are valid for **90 days**
- Auto-renewal attempts start when **30 days or less** remain
- Cron runs twice daily (midnight and noon) to check renewal status

### RSA Key Size
- Uses **4096-bit RSA keys** for enhanced security

### Auto-Renewal Configuration
```
0 0,12 * * * root /usr/bin/certbot renew --quiet --nginx --renew-hook "systemctl reload nginx"
```

## Improvements Over Previous Setup

1. **Better Separation of Concerns**: Logic in maintainable bin script vs inline YAML
2. **Easier Debugging**: Comprehensive logging to `/var/log/certbot_deploy.log`
3. **Enhanced Security**: 4096-bit RSA keys (previously default 2048-bit)
4. **Automatic Nginx Reload**: Nginx automatically reloads after successful renewal
5. **Better Error Handling**: Exit codes and error messages for troubleshooting
6. **Certificate Expiry Checks**: Logs current certificate status on each run

## Logs

- **Deployment Log**: `/var/log/certbot_deploy.log`
- **Renewal Log**: `/var/log/letsencrypt/renew.log`
- **Nginx Logs**: `/var/log/nginx/error.log`, `/var/log/nginx/access.log`

## Manual Operations

### Check Certificate Status
```bash
sudo certbot certificates
```

### Force Renewal (for testing)
```bash
sudo certbot renew --force-renewal --nginx
```

### Run Setup Script Manually
```bash
sudo /var/app/current/bin/setup-certbot.sh
```

### Test Nginx Configuration
```bash
sudo nginx -t
```

## Troubleshooting

1. **Check deployment logs**: `tail -f /var/log/certbot_deploy.log`
2. **Verify environment variables are set** in EB console
3. **Ensure port 443 is open** in security group (handled by `00_https_security.config`)
4. **Check domain DNS** points to your EB environment
5. **Verify Nginx is running**: `sudo systemctl status nginx`

## Migration Notes

- Removed `.ebextensions/10_install_certbot.config`
- Migrated to `.platform/hooks/postdeploy/` approach
- All functionality preserved and enhanced
