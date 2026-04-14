#!/bin/bash
# Single bot run for off-peak checks
# Checks for cron lock to avoid overlap with peak window runs

CRON_LOCK="/tmp/tockstalk-cron.lock"

# Try to acquire the cron lock (non-blocking)
# If we can acquire it, peak window isn't running
exec 200>"$CRON_LOCK"
if ! flock -n 200; then
  echo "Peak window run in progress, skipping off-peak check"
  exit 0
fi

# We got the lock, release it immediately (we don't need to hold it)
flock -u 200

cd ~/projects/tockstalk-bot
xvfb-run -a --server-args="-screen 0 1920x1080x24" node src/bot.js
