#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "======================================"
echo "  EasyTrade EC2 Instance Setup"
echo "======================================"
echo "Starting user-data script at $(date)"
echo "Ubuntu version: $(lsb_release -rs)"

# Update system
echo "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    unzip \
    jq

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install Docker Compose (standalone)
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.24.0"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/easytrade
chown ubuntu:ubuntu /opt/easytrade

# Create docker-compose override directory
mkdir -p /opt/easytrade/overrides
chown ubuntu:ubuntu /opt/easytrade/overrides

# Note: kubectl installation removed - using Docker Compose deployment, not Kubernetes

# Configure Docker to use ghcr.io authentication
# Note: This requires a GitHub Personal Access Token (PAT) with read:packages permission
# The token should be provided via environment variable or AWS Systems Manager Parameter Store
echo "Docker and Docker Compose installed successfully"
echo "Note: Configure ghcr.io authentication manually or via deployment script"

# Create systemd service for EasyTrade (optional)
cat > /etc/systemd/system/easytrade.service <<EOF
[Unit]
Description=EasyTrade Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/easytrade
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# Don't enable the service by default - let user start it manually
# systemctl enable easytrade.service

echo "======================================"
echo "  Setup Complete!"
echo "======================================"
echo "Instance ready at $(date)"
echo "SSH into the instance and run deployment scripts"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"

