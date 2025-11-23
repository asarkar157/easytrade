#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "  EasyTrade EC2 Setup Script"
echo "======================================"
echo

# Check if running on EC2
if [ ! -f /sys/hypervisor/uuid ] && [ ! -d /sys/firmware/efi ]; then
    echo -e "${YELLOW}Warning: This script is designed to run on EC2 instances${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ] && [ -z "$GITHUB_PAT" ]; then
    echo -e "${YELLOW}GitHub token not found in environment${NC}"
    echo "To pull images from ghcr.io, you need a GitHub Personal Access Token"
    echo "with 'read:packages' permission."
    echo
    read -p "Enter GitHub Personal Access Token (or press Enter to skip): " -s GITHUB_TOKEN
    echo
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${YELLOW}Skipping ghcr.io authentication setup${NC}"
        echo "You'll need to configure this manually later"
    fi
fi

# Configure Docker to login to ghcr.io
if [ -n "$GITHUB_TOKEN" ] || [ -n "$GITHUB_PAT" ]; then
    TOKEN="${GITHUB_TOKEN:-${GITHUB_PAT}}"
    GITHUB_USER=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/user | jq -r '.login')
    
    if [ "$GITHUB_USER" != "null" ] && [ -n "$GITHUB_USER" ]; then
        echo -e "${GREEN}Logging into ghcr.io as $GITHUB_USER...${NC}"
        echo "$TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Successfully logged into ghcr.io${NC}"
        else
            echo -e "${RED}✗ Failed to login to ghcr.io${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to get GitHub username from token${NC}"
    fi
fi

# Create .env file for docker-compose
if [ ! -f /opt/easytrade/.env ]; then
    echo "Creating .env file..."
    cat > /opt/easytrade/.env <<EOF
# EasyTrade Configuration
REGISTRY=ghcr.io/${GITHUB_USER:-your-username}
TAG=latest

# Database Configuration
SA_PASSWORD=yourStrong(!)Password

# RabbitMQ Configuration
RABBITMQ_USER=userxxx
RABBITMQ_PASSWORD=passxxx
RABBITMQ_PORT=5672
RABBITMQ_HOST=rabbitmq
RABBITMQ_QUEUE=Trade_Data_Raw
EOF
    echo -e "${GREEN}✓ Created .env file${NC}"
else
    echo -e "${YELLOW}.env file already exists, skipping...${NC}"
fi

echo
echo -e "${GREEN}Setup complete!${NC}"
echo
echo "Next steps:"
echo "1. Copy your compose.yaml to /opt/easytrade/"
echo "2. Run the deployment script: ./ec2-deploy.sh"
echo

