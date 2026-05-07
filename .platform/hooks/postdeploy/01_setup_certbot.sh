#!/bin/bash
# Elastic Beanstalk Post-Deployment Hook
# Runs after application deployment to setup SSL certificates

/var/app/current/bin/setup-certbot.sh
