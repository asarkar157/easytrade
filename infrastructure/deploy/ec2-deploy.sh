#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

EASYTRADE_DIR="/opt/easytrade"
COMPOSE_FILE="${EASYTRADE_DIR}/compose.yaml"

echo "======================================"
echo "  EasyTrade EC2 Deployment Script"
echo "======================================"
echo

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Switching to ubuntu user...${NC}"
    exec su - ubuntu -c "$0 $@"
fi

# Check if compose.yaml exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: compose.yaml not found at $COMPOSE_FILE${NC}"
    echo
    echo "Please copy compose.yaml to $COMPOSE_FILE first:"
    echo "  scp compose.yaml ubuntu@<instance-ip>:/opt/easytrade/"
    exit 1
fi

# Check if .env exists
if [ ! -f "${EASYTRADE_DIR}/.env" ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo "Running setup script first..."
    cd "$(dirname "$0")"
    ./ec2-setup.sh
fi

# Load environment variables
echo -e "${BLUE}Loading environment variables...${NC}"
set -a
source "${EASYTRADE_DIR}/.env"
set +a

# Verify Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Starting Docker..."
    sudo systemctl start docker
    sleep 5
fi

# Check Docker login to ghcr.io
echo -e "${BLUE}Checking ghcr.io authentication...${NC}"
if ! docker pull "${REGISTRY}/db:${TAG}" > /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Failed to pull test image. Checking authentication...${NC}"
    if ! docker login ghcr.io > /dev/null 2>&1; then
        echo -e "${YELLOW}Not authenticated to ghcr.io. Running setup script...${NC}"
        cd "$(dirname "$0")"
        ./ec2-setup.sh
    fi
fi

# Pull all images
echo -e "${BLUE}Pulling Docker images...${NC}"
cd "$EASYTRADE_DIR"
docker-compose pull

# Start services
echo -e "${BLUE}Starting EasyTrade services...${NC}"
docker-compose up -d

# Wait for services to be healthy
echo -e "${BLUE}Waiting for services to start...${NC}"
sleep 10

# Check service status
echo
echo -e "${GREEN}Service Status:${NC}"
docker-compose ps

echo
echo -e "${GREEN}======================================"
echo "  Deployment Complete!"
echo "======================================"
echo
echo "Services are starting up. Check status with:"
echo "  docker-compose -f $COMPOSE_FILE ps"
echo
echo "View logs with:"
echo "  docker-compose -f $COMPOSE_FILE logs -f"
echo
echo "Stop services with:"
echo "  docker-compose -f $COMPOSE_FILE down"
echo
echo "Access the application at:"
echo "  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo

