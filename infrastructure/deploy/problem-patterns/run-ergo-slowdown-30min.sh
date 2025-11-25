#!/bin/bash
# Run Ergo Aggregator Slowdown pattern for 30 minutes
# This script enables the pattern, waits 30 minutes, then disables it

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DURATION_MINUTES=30

echo "======================================"
echo "  Ergo Aggregator Slowdown Pattern"
echo "  Duration: ${DURATION_MINUTES} minutes"
echo "======================================"
echo

# Enable the pattern
echo "$(date): Enabling ergo_aggregator_slowdown pattern..."
"${SCRIPT_DIR}/enable-ergo-aggregator-slowdown.sh"

if [ $? -eq 0 ]; then
    echo "$(date): Pattern enabled successfully"
    echo
    echo "Pattern will run for ${DURATION_MINUTES} minutes..."
    echo "Started at: $(date)"
    END_TIME=$(date -v+${DURATION_MINUTES}M +'%H:%M:%S' 2>/dev/null || date -d "+${DURATION_MINUTES} minutes" +'%H:%M:%S' 2>/dev/null || echo "in ${DURATION_MINUTES} minutes")
    echo "Will disable at: ${END_TIME}"
    echo
    echo "Press Ctrl+C to disable early, or wait for automatic disable"
    echo
    
    # Wait for the duration
    sleep $((DURATION_MINUTES * 60))
    
    # Disable the pattern
    echo
    echo "$(date): Disabling ergo_aggregator_slowdown pattern..."
    "${SCRIPT_DIR}/disable-ergo-aggregator-slowdown.sh"
    
    if [ $? -eq 0 ]; then
        echo "$(date): Pattern disabled successfully"
        echo
        echo "======================================"
        echo "  Pattern Run Complete"
        echo "======================================"
        echo "Started:  $(date -v-${DURATION_MINUTES}M +'%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'N/A')"
        echo "Ended:    $(date +'%Y-%m-%d %H:%M:%S')"
        echo "Duration: ${DURATION_MINUTES} minutes"
    else
        echo "$(date): Error: Failed to disable pattern"
        exit 1
    fi
else
    echo "$(date): Error: Failed to enable pattern"
    exit 1
fi

