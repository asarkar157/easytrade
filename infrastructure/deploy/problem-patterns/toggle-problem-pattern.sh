#!/bin/bash
# Script to toggle a problem pattern feature flag
# Usage: ./toggle-problem-pattern.sh <flag-id> <enabled>
# Example: ./toggle-problem-pattern.sh db_not_responding true
#
# This script tries multiple methods to access the feature-flag-service:
# 1. Direct HTTP (if FEATURE_FLAG_SERVICE_URL is set or service is exposed)
# 2. Docker exec (if running from host and service is in Docker network)

set -e

FLAG_ID="${1}"
ENABLED="${2}"

if [ -z "$FLAG_ID" ] || [ -z "$ENABLED" ]; then
    echo "Usage: $0 <flag-id> <enabled>"
    echo "  flag-id: One of: db_not_responding, high_cpu_usage, factory_crisis, ergo_aggregator_slowdown"
    echo "  enabled: true or false"
    exit 1
fi

if [ "$ENABLED" != "true" ] && [ "$ENABLED" != "false" ]; then
    echo "Error: enabled must be 'true' or 'false'"
    exit 1
fi

echo "$(date): Toggling problem pattern '${FLAG_ID}' to ${ENABLED}"

# Try to find feature-flag-service container
FEATURE_FLAG_CONTAINER=$(docker ps --filter "name=feature-flag-service" --format "{{.Names}}" | head -1)

# Method 1: Use FEATURE_FLAG_SERVICE_URL if set
if [ -n "${FEATURE_FLAG_SERVICE_URL}" ]; then
    URL="${FEATURE_FLAG_SERVICE_URL}/v1/flags/${FLAG_ID}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
        "${URL}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"enabled\": ${ENABLED}}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
        echo "$(date): Successfully set ${FLAG_ID} to ${ENABLED}"
        exit 0
    fi
fi

# Method 2: Try localhost:8080 (if port is exposed)
if curl -s -f -o /dev/null "http://localhost:8080/v1/flags" 2>/dev/null; then
    URL="http://localhost:8080/v1/flags/${FLAG_ID}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
        "${URL}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"enabled\": ${ENABLED}}")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
        echo "$(date): Successfully set ${FLAG_ID} to ${ENABLED}"
        exit 0
    fi
fi

# Method 3: Use Docker exec to run curl from within the network
if [ -n "${FEATURE_FLAG_CONTAINER}" ]; then
    if docker exec "${FEATURE_FLAG_CONTAINER}" curl -s -f -o /dev/null "http://feature-flag-service:8080/v1/flags" 2>/dev/null; then
        RESPONSE=$(docker exec "${FEATURE_FLAG_CONTAINER}" curl -s -w "\n%{http_code}" -X PUT \
            "http://feature-flag-service:8080/v1/flags/${FLAG_ID}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "{\"enabled\": ${ENABLED}}")
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | sed '$d')
        
        if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
            echo "$(date): Successfully set ${FLAG_ID} to ${ENABLED}"
            exit 0
        fi
    fi
fi

# Method 4: Use a temporary curl container in the same network
if [ -n "${FEATURE_FLAG_CONTAINER}" ]; then
    NETWORK=$(docker inspect "${FEATURE_FLAG_CONTAINER}" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}' | head -1)
    if [ -n "${NETWORK}" ]; then
        RESPONSE=$(docker run --rm --network "${NETWORK}" curlimages/curl:latest \
            -s -w "\n%{http_code}" -X PUT \
            "http://feature-flag-service:8080/v1/flags/${FLAG_ID}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "{\"enabled\": ${ENABLED}}")
        
        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | sed '$d')
        
        if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
            echo "$(date): Successfully set ${FLAG_ID} to ${ENABLED}"
            exit 0
        fi
    fi
fi

# If all methods failed
echo "$(date): Error: Failed to set ${FLAG_ID} to ${ENABLED}"
echo "Tried multiple methods but could not reach feature-flag-service"
echo "Please ensure:"
echo "  1. feature-flag-service is running"
echo "  2. Port 8080 is exposed, or"
echo "  3. Set FEATURE_FLAG_SERVICE_URL environment variable"
exit 1

