# Tockstalk Bot

Automated reservation monitoring bot for Tock restaurants, running on Distiller (pamir.ai). Uses Playwright with stealth mode to bypass Cloudflare protection, monitors availability in real-time, and books reservations automatically when desired time slots become available.

## Features

- **Cloudflare Bypass**: Uses Playwright-extra with stealth plugin to bypass bot detection
- **Session Persistence**: Saves cookies to avoid repeated logins
- **Peak Window Detection**: Automatically adjusts timeouts during high-traffic reservation release times
- **Slack Notifications**: Real-time alerts for availability and booking status
- **Analytics Dashboard**: Visual tracking of availability patterns and Cloudflare blocks
- **Cron Scheduling**: Automated checks with peak window intensive monitoring
- **Lock Management**: Prevents concurrent runs and ensures safe execution
- **Auto-shutdown**: Disables cron jobs after successful booking

## Project Structure

```
tockstalk-bot/
├── .claude/                 # Claude Code skills
├── src/
│   ├── bot.js              # Main bot script
│   ├── analytics-server.js # Analytics dashboard server
│   └── dashboard.html      # Analytics UI
├── scripts/
│   ├── run-bot.sh          # Single bot run (with lock checking)
│   ├── run-4x.sh           # 4 attempts with 15s intervals
│   ├── stop-bot.sh         # Disable cron jobs
│   └── start-analytics.sh  # Start analytics server
├── data/                   # Runtime data (gitignored)
│   ├── analytics.json      # Availability tracking data
│   ├── cloudflare-blocks.json  # Cloudflare challenge history
│   ├── tock-cookies.json   # Session cookies
│   └── *.png               # Debug screenshots
├── .env                    # Configuration (create from .env.example)
├── .env.example            # Environment variables template
├── .gitignore
├── package.json
└── README.md
```

## Setup

### 1. Install Dependencies

```bash
cd ~/projects/tockstalk-bot
npm install
```

### 2. Configure Environment

Copy the example environment file and edit with your details:

```bash
cp .env.example .env
nano .env
```

Required configuration:

```bash
# Tock Account
TOCK_EMAIL=your@email.com
TOCK_PASSWORD=yourpassword
TOCK_CVV=123

# Restaurant Details
BOOKING_PAGE=/restaurant-name/experience/123456/experience-name
PARTY_SIZE=2
DESIRED_TIME_SLOTS=5:00 PM,6:30 PM,8:00 PM

# Notifications (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# Testing
DRY_RUN=false  # Set to 'true' for testing without booking
```

To find your `BOOKING_PAGE`:
1. Go to the restaurant's Tock page
2. Select party size
3. Copy the path from URL (everything after `exploretock.com`)

### 3. Test the Bot

Run a single check in dry-run mode:

```bash
DRY_RUN=true ./scripts/run-bot.sh
```

This will:
- Log into Tock (or use saved session)
- Check for available days
- Report matching time slots
- Take screenshots but NOT book

## Usage

### Manual Runs

**Single check:**
```bash
./scripts/run-bot.sh
```

**4 attempts with 15-second intervals (peak window mode):**
```bash
./scripts/run-4x.sh
```

### Scheduled Monitoring with Cron

Edit your crontab:
```bash
crontab -e
```

Example configuration:

```bash
# Peak Window #1: 4:59pm PT (12:59am UTC next day)
# Run 4 times per minute for 3 minutes = 12 checks
57-59 0 * * * flock -n /tmp/tockstalk-cron.lock /home/distiller/projects/tockstalk-bot/scripts/run-4x.sh >> /home/distiller/projects/tockstalk-bot/data/cron.log 2>&1

# Peak Window #2: 5:59pm PT (1:59am UTC next day)
# Run 4 times per minute for 3 minutes = 12 checks
57-59 1 * * * flock -n /tmp/tockstalk-cron.lock /home/distiller/projects/tockstalk-bot/scripts/run-4x.sh >> /home/distiller/projects/tockstalk-bot/data/cron.log 2>&1

# Off-peak checks: Every 15 minutes
*/15 * * * * /home/distiller/projects/tockstalk-bot/scripts/run-bot.sh >> /home/distiller/projects/tockstalk-bot/data/cron.log 2>&1
```

**Important:**
- Peak window runs use `flock` with a cron lock to prevent overlap
- Off-peak runs check for the cron lock and skip if peak is running
- Adjust times based on your target restaurant's release schedule

### Stop the Bot

After a successful booking, the bot automatically disables itself. You can also stop it manually:

```bash
./scripts/stop-bot.sh
```

This removes all tockstalk-related cron jobs.

## Analytics Dashboard

View real-time availability patterns and Cloudflare block tracking:

```bash
./scripts/start-analytics.sh
```

Then open http://localhost:3002 in your browser.

The dashboard shows:
- Availability rate over time
- Peak vs off-peak check patterns
- Hourly and daily availability trends
- Cloudflare challenge detection
- Recent activity timeline

**Stop the analytics server:**
```bash
pkill -f "node src/analytics-server.js"
```

## How It Works

### Bot Flow

1. **Lock Check**: Ensures only one instance runs at a time
2. **Session Management**: Tries to use saved cookies, logs in if expired
3. **Cloudflare Detection**: Automatically detects and handles challenges
   - Waits up to 150 seconds for auto-solve
   - Tracks consecutive blocks
   - Alerts if session may be flagged
4. **Calendar Check**: Waits for calendar to load with retry logic
5. **Availability Scan**: Checks each available day for matching time slots
6. **Booking**: When match found:
   - Clicks time slot
   - Enters CVV if needed
   - Submits reservation
   - Screenshots confirmation
   - Disables cron jobs
   - Deletes session cookies

### Peak Window Behavior

The bot automatically detects peak windows and adjusts:
- **Longer timeouts**: 60s vs 30s for page loads
- **Slack alerts**: Peak status included in notifications
- **Analytics tracking**: Marks runs as peak vs off-peak

Peak windows (configurable in `src/bot.js`):
- 4:59pm PT (12:59am UTC next day)
- 5:59pm PT (1:59am UTC next day)

### Cloudflare Handling

The bot uses multiple strategies to bypass Cloudflare:
- Playwright-extra stealth plugin
- Realistic user agent and browser headers
- Session cookie persistence
- Automatic challenge detection and waiting (up to 150 seconds)
- Consecutive block tracking with alerts

## Monitoring

### Check Cron Status

```bash
crontab -l
```

### View Logs

**Bot logs:**
```bash
tail -f data/cron.log
```

**Analytics server logs:**
```bash
tail -f data/analytics-server.log
```

### Check Running Processes

```bash
# Check for bot instances
ps aux | grep "node src/bot.js"

# Check for analytics server
ps aux | grep "node src/analytics-server.js"
```

### Screenshots

Debug screenshots are saved to `data/`:
- `cloudflare-detected.png` - When challenge appears
- `cloudflare-cleared.png` - After auto-solve
- `cloudflare-timeout.png` - If challenge fails
- `calendar-timeout.png` - If calendar doesn't load
- `error.png` - Generic errors
- `would-book.png` - Dry run mode matches
- `success.png` - Successful booking confirmation

## Troubleshooting

### "403 Forbidden" or Repeated Cloudflare Blocks

- Check `data/cloudflare-blocks.json` for consecutive block count
- If high (3+), session may be flagged:
  - Delete `data/tock-cookies.json`
  - Wait 24 hours before retrying
  - Reduce check frequency

### Login Fails

- Verify credentials in `.env`
- Check for Tock website changes
- Delete `data/tock-cookies.json` and retry

### Calendar Not Loading

- Restaurant page structure may have changed
- Check `BOOKING_PAGE` in `.env` is correct
- Review `data/calendar-timeout.png` screenshot

### Cron Jobs Not Running

```bash
# Check cron service
sudo service cron status

# Check cron logs
grep CRON /var/log/syslog
```

### Bot Crashes

- Check `data/cron.log` for error messages
- Ensure Xvfb is installed: `sudo apt-get install xvfb`
- Verify all dependencies: `npm install`

## Development

### Run in Dry-Run Mode

Test without actually booking:

```bash
DRY_RUN=true xvfb-run -a --server-args="-screen 0 1920x1080x24" node src/bot.js
```

### Modify Peak Windows

Edit `src/bot.js`, lines 205-212 and 328-334:

```javascript
const isPeakWindow = (hour === 0 && minute === 59) || // Adjust UTC times
                     (hour === 1 && minute === 59);
```

### Add More Notifications

The bot separates critical alerts (sent to Slack) from console logs:
- `log(message)` - Console + Slack
- `consoleLog(message)` - Console only

## Technical Details

### Dependencies

- **playwright**: Browser automation
- **playwright-extra**: Plugin support
- **puppeteer-extra-plugin-stealth**: Cloudflare bypass
- **@slack/webhook**: Slack notifications
- **express**: Analytics server
- **dotenv**: Environment configuration

### System Requirements

- Node.js 14+
- Xvfb (virtual display for headless browser)
- Linux (tested on Raspberry Pi OS)
- 500MB+ RAM available
- Stable internet connection

### Lock Files

- `/tmp/tockstalk.lock` - Bot instance lock (3 min timeout)
- `/tmp/tockstalk-cron.lock` - Cron lock (prevents peak/off-peak overlap)

## Security Notes

- `.env` file contains sensitive credentials - never commit it
- `data/tock-cookies.json` contains session cookies - gitignored
- Use Slack webhook URLs carefully (can post to channels)
- Set `DRY_RUN=true` for testing to avoid accidental bookings

## License

ISC

## Support

For issues or questions:
1. Check troubleshooting section
2. Review logs in `data/`
3. Verify configuration in `.env`
4. Test with `DRY_RUN=true`
