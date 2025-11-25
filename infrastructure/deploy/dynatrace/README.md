# Dynatrace Deployment Markers

This directory contains scripts to automatically create Dynatrace deployment markers.

## Scripts

### `create-deployment-marker.sh`

Creates a single deployment marker in Dynatrace using the Business Events API.

**Usage:**
```bash
./create-deployment-marker.sh [deployment-name] [deployment-version]
```

**Environment Variables Required:**
- `DYNATRACE_TENANT_URL` or `DYNATRACE_ENDPOINT` - Your Dynatrace tenant URL
- `DYNATRACE_PLATFORM_TOKEN` or `DYNATRACE_API_TOKEN` - Dynatrace API token with "Ingest business events" permission

**Examples:**
```bash
# Use defaults (name: "EasyTrade Automated Deployment", version: timestamp)
./create-deployment-marker.sh

# Custom deployment name
./create-deployment-marker.sh "Production Deployment"

# Custom name and version
./create-deployment-marker.sh "Production Deployment" "v1.2.3"
```

### `setup-deployment-marker-cron.sh`

Sets up a cron job to automatically create deployment markers every 25 minutes.

**Usage:**
```bash
./setup-deployment-marker-cron.sh
```

This will:
1. Make the marker script executable
2. Create a log file at `/var/log/easytrade-deployment-markers.log`
3. Install a cron job that runs at 0, 25, and 50 minutes past every hour

## Setup on EC2

1. **Copy scripts to EC2:**
```bash
scp -i ~/.ssh/EC2-SSH.pem -r infrastructure/deploy/dynatrace ubuntu@<EC2_IP>:/opt/easytrade/infrastructure/deploy/
```

2. **SSH into EC2:**
```bash
ssh -i ~/.ssh/EC2-SSH.pem ubuntu@<EC2_IP>
```

3. **Ensure environment variables are set:**
The script will automatically load from `/opt/easytrade/.env.local` if it exists. Make sure it contains:
```bash
DYNATRACE_TENANT_URL=https://your-tenant.live.dynatrace.com
DYNATRACE_PLATFORM_TOKEN=your-token-here
```

4. **Run setup script:**
```bash
cd /opt/easytrade/infrastructure/deploy/dynatrace
./setup-deployment-marker-cron.sh
```

5. **Test manually (optional):**
```bash
./create-deployment-marker.sh "Test Deployment" "test-v1"
```

6. **View logs:**
```bash
tail -f /var/log/easytrade-deployment-markers.log
```

## Schedule

The cron job runs at:
- **0 minutes** past every hour (e.g., 12:00, 13:00, 14:00)
- **25 minutes** past every hour (e.g., 12:25, 13:25, 14:25)
- **50 minutes** past every hour (e.g., 12:50, 13:50, 14:50)

This creates deployment markers every 25 minutes throughout the day.

## API Requirements

The Dynatrace API token must have the following permission:
- **Ingest business events** (Platform API v2)

To create a token:
1. Go to Dynatrace → Settings → Integration → Dynatrace API
2. Generate a new token
3. Select "Ingest business events" permission
4. Copy the token and add it to your `.env.local` file

## Troubleshooting

1. **Check if cron is running:**
```bash
systemctl status cron
```

2. **View cron logs:**
```bash
tail -f /var/log/easytrade-deployment-markers.log
```

3. **Test the script manually:**
```bash
cd /opt/easytrade/infrastructure/deploy/dynatrace
./create-deployment-marker.sh "Manual Test" "test-$(date +%s)"
```

4. **Check environment variables:**
```bash
source /opt/easytrade/.env.local
echo "Tenant: $DYNATRACE_TENANT_URL"
echo "Token: ${DYNATRACE_PLATFORM_TOKEN:0:10}..."
```

5. **Verify API endpoint:**
```bash
curl -X POST "https://your-tenant.live.dynatrace.com/platform/classic/environment-api/v2/bizevents/ingest" \
  -H "Content-Type: application/json" \
  -H "Authorization: Api-Token $DYNATRACE_PLATFORM_TOKEN" \
  -d '{"event.provider":"Test","event.type":"deployment"}'
```

## Removing the Cron Job

To stop creating deployment markers:

```bash
crontab -e
# Delete the lines containing "create-deployment-marker.sh"
# Save and exit
```

Or remove all deployment marker entries:
```bash
crontab -l | grep -v "create-deployment-marker.sh" | crontab -
```

