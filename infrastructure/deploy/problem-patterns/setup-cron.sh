#!/bin/bash
# Setup script to install problem pattern cron jobs on EC2
# Run this on the EC2 instance after copying the problem-patterns directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRONTAB_FILE="${SCRIPT_DIR}/crontab.example"
LOG_FILE="/var/log/easytrade-problem-patterns.log"

echo "Setting up EasyTrade problem patterns cron jobs..."

# Make all scripts executable
chmod +x "${SCRIPT_DIR}"/*.sh

# Create log file if it doesn't exist
if [ ! -f "${LOG_FILE}" ]; then
    sudo touch "${LOG_FILE}"
    sudo chown "$(whoami):$(whoami)" "${LOG_FILE}"
    echo "Created log file: ${LOG_FILE}"
fi

# Check if feature-flag-service is accessible
echo "Checking feature-flag-service accessibility..."

# Try to find the container
FEATURE_FLAG_CONTAINER=$(docker ps --filter "name=feature-flag-service" --format "{{.Names}}" | head -1)

if [ -z "${FEATURE_FLAG_CONTAINER}" ]; then
    echo "Warning: feature-flag-service container not found. Make sure services are running."
    echo "You may need to update FEATURE_FLAG_SERVICE_URL in the scripts."
else
    echo "Found feature-flag-service container: ${FEATURE_FLAG_CONTAINER}"
    
    # Test connectivity
    if docker exec "${FEATURE_FLAG_CONTAINER}" curl -s -f "http://feature-flag-service:8080/v1/flags" > /dev/null 2>&1; then
        echo "✓ feature-flag-service is accessible via Docker network"
    else
        echo "Warning: Could not reach feature-flag-service. Scripts will try multiple methods."
    fi
fi

# Install crontab
echo ""
echo "Installing crontab from ${CRONTAB_FILE}..."
echo "Current crontab will be backed up to ${HOME}/.crontab.backup"

# Backup existing crontab
crontab -l > "${HOME}/.crontab.backup" 2>/dev/null || true

# Install new crontab
if crontab "${CRONTAB_FILE}"; then
    echo "✓ Crontab installed successfully"
    echo ""
    echo "Current cron schedule:"
    crontab -l | grep -E "(problem-patterns|enable-|disable-)" || crontab -l
    echo ""
    echo "To view/edit the crontab, run: crontab -e"
    echo "To view logs, run: tail -f ${LOG_FILE}"
else
    echo "Error: Failed to install crontab"
    exit 1
fi

echo ""
echo "Setup complete!"
echo ""
echo "To test a problem pattern manually:"
echo "  ${SCRIPT_DIR}/enable-db-not-responding.sh"
echo ""
echo "To view cron logs:"
echo "  tail -f ${LOG_FILE}"

