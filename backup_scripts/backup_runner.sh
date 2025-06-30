#!/bin/sh

# Set time for daily backup (e.g., 2:00 AM)
CRON_SCHEDULE="0 2 * * *"

# Write the cron job
echo "$CRON_SCHEDULE /scripts/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Start cron
crond -f
