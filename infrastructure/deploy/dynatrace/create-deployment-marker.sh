#!/bin/bash
# Create a Dynatrace deployment marker
# This script sends a deployment event to Dynatrace using the Business Events API
# Usage: ./create-deployment-marker.sh [deployment-name] [deployment-version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get deployment name and version from arguments or use defaults
DEPLOYMENT_NAME="${1:-EasyTrade Automated Deployment}"
DEPLOYMENT_VERSION="${2:-$(date +'%Y%m%d-%H%M%S')}"

# Load environment variables from .env.local if it exists (for local use)
if [ -f "/opt/easytrade/.env.local" ]; then
    source /opt/easytrade/.env.local
elif [ -f ".env.local" ]; then
    source .env.local
fi

# Construct Dynatrace tenant URL
# Support both DYNATRACE_TENANT_URL and DYNATRACE_ENDPOINT
if [ -n "$DYNATRACE_TENANT_URL" ]; then
    TENANT_URL=$(echo "$DYNATRACE_TENANT_URL" | sed 's|/*$||')
    # Convert .apps to .live if needed
    if echo "$TENANT_URL" | grep -q "\.apps\.dynatrace\.com"; then
        TENANT_ID=$(echo "$TENANT_URL" | sed -E 's|https?://([^.]+)\.apps\.dynatrace\.com.*|\1|')
        TENANT_URL="https://${TENANT_ID}.live.dynatrace.com"
    fi
elif [ -n "$DYNATRACE_ENDPOINT" ]; then
    # Extract tenant URL from endpoint (remove /api/v2/otlp)
    TENANT_URL=$(echo "$DYNATRACE_ENDPOINT" | sed 's|/api/v2/otlp.*||' | sed 's|/*$||')
    # Convert .apps to .live if needed
    if echo "$TENANT_URL" | grep -q "\.apps\.dynatrace\.com"; then
        TENANT_ID=$(echo "$TENANT_URL" | sed -E 's|https?://([^.]+)\.apps\.dynatrace\.com.*|\1|')
        TENANT_URL="https://${TENANT_ID}.live.dynatrace.com"
    fi
else
    echo -e "${RED}Error: DYNATRACE_TENANT_URL or DYNATRACE_ENDPOINT must be set${NC}"
    exit 1
fi

# Get API token
if [ -n "$DYNATRACE_PLATFORM_TOKEN" ]; then
    API_TOKEN="$DYNATRACE_PLATFORM_TOKEN"
elif [ -n "$DYNATRACE_API_TOKEN" ]; then
    API_TOKEN="$DYNATRACE_API_TOKEN"
else
    echo -e "${RED}Error: DYNATRACE_PLATFORM_TOKEN or DYNATRACE_API_TOKEN must be set${NC}"
    exit 1
fi

# Business Events API endpoint
API_ENDPOINT="${TENANT_URL}/platform/classic/environment-api/v2/bizevents/ingest"

# Create the deployment event payload
# Using jq if available, otherwise constructing JSON manually
if command -v jq &> /dev/null; then
    PAYLOAD=$(jq -cn \
        --arg app "easytrade" \
        --arg version "$DEPLOYMENT_VERSION" \
        --arg name "$DEPLOYMENT_NAME" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            "event.provider": "EasyTrade Automation",
            "event.type": "deployment",
            "tags.application": $app,
            "tags.deployment.name": $name,
            "tags.deployment.version": $version,
            "tags.deployment.timestamp": $timestamp,
            "tags.environment": "production"
        }')
else
    # Fallback JSON construction without jq
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    PAYLOAD="{\"event.provider\":\"EasyTrade Automation\",\"event.type\":\"deployment\",\"tags.application\":\"easytrade\",\"tags.deployment.name\":\"${DEPLOYMENT_NAME}\",\"tags.deployment.version\":\"${DEPLOYMENT_VERSION}\",\"tags.deployment.timestamp\":\"${TIMESTAMP}\",\"tags.environment\":\"production\"}"
fi

echo -e "${YELLOW}Creating Dynatrace deployment marker...${NC}"
echo "  Tenant: ${TENANT_URL}"
echo "  Deployment: ${DEPLOYMENT_NAME}"
echo "  Version: ${DEPLOYMENT_VERSION}"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Send the deployment event
RESPONSE=$(curl -sfw "\n%{http_code}" -X POST "${API_ENDPOINT}" \
    --header "Content-Type: application/json" \
    --header "Authorization: Api-Token ${API_TOKEN}" \
    --data-raw "${PAYLOAD}" 2>&1)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓${NC} Deployment marker created successfully (HTTP ${HTTP_CODE})"
    exit 0
else
    echo -e "${RED}✗${NC} Failed to create deployment marker (HTTP ${HTTP_CODE})"
    echo "Response: ${BODY}"
    exit 1
fi

