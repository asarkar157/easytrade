#!/bin/bash
# Setup cron job to create Dynatrace deployment markers every 25 minutes
# This script installs a cron job that runs create-deployment-marker.sh every 25 minutes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER_SCRIPT="${SCRIPT_DIR}/create-deployment-marker.sh"
LOG_FILE="/var/log/easytrade-deployment-markers.log"

echo "======================================"
echo "  Dynatrace Deployment Marker Setup"
echo "======================================"
echo

# Check if marker script exists
if [ ! -f "$MARKER_SCRIPT" ]; then
    echo -e "${RED}Error: create-deployment-marker.sh not found at ${MARKER_SCRIPT}${NC}"
    exit 1
fi

# Make script executable
chmod +x "$MARKER_SCRIPT"
echo -e "${GREEN}✓${NC} Made create-deployment-marker.sh executable"

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chown "$(whoami):$(whoami)" "$LOG_FILE"
    echo -e "${GREEN}✓${NC} Created log file: ${LOG_FILE}"
else
    echo -e "${YELLOW}⚠${NC} Log file already exists: ${LOG_FILE}"
fi

# Create temporary crontab file
TEMP_CRON=$(mktemp)

# Get existing crontab (if any) and filter out our deployment marker entries
(crontab -l 2>/dev/null | grep -v "create-deployment-marker.sh" || true) > "$TEMP_CRON"

# Add deployment marker cron jobs
# Run at minutes 0, 25, and 50 of every hour (every 25 minutes)
cat >> "$TEMP_CRON" << EOF

# Dynatrace Deployment Markers - Every 25 minutes
# Run at 0, 25, and 50 minutes past every hour
0,25,50 * * * * ${MARKER_SCRIPT} >> ${LOG_FILE} 2>&1
EOF

# Install the crontab
crontab "$TEMP_CRON"
rm "$TEMP_CRON"

echo -e "${GREEN}✓${NC} Installed cron job to create deployment markers every 25 minutes"
echo
echo "Schedule: Runs at 0, 25, and 50 minutes past every hour"
echo "Log file: ${LOG_FILE}"
echo
echo "Current crontab:"
crontab -l | grep -A 1 "create-deployment-marker" || echo "  (none found)"
echo
echo -e "${GREEN}======================================"
echo "  Setup Complete!"
echo "======================================"
echo
echo "To test the script manually:"
echo "  ${MARKER_SCRIPT}"
echo
echo "To view logs:"
echo "  tail -f ${LOG_FILE}"
echo
echo "To remove the cron job:"
echo "  crontab -e"
echo "  (then delete the lines with create-deployment-marker.sh)"
echo

