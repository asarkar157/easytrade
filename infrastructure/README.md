# EasyTrade EC2 Infrastructure

This directory contains Terraform configuration and deployment scripts for running EasyTrade on an AWS EC2 instance.

## Resource Requirements

Based on Kubernetes manifest resource analysis (for sizing purposes):
- **CPU**: 1.54 cores (requests)
- **Memory**: ~8.5 GiB (requests)
- **Recommended Instance**: m5.xlarge (4 vCPU, 16 GiB RAM)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with AWS SSO
4. **SSH Key Pair** in AWS (for EC2 access)
5. **GitHub Personal Access Token** with `read:packages` permission (for pulling images from ghcr.io)

## Quick Start

### 1. Configure Terraform Variables

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
- `key_pair_name`: Your AWS key pair name
- `allowed_ssh_cidr`: Your IP address in CIDR notation (e.g., "203.0.113.0/32")
  - Find your IP at https://www.whatismyip.com/
  - **Important**: Change from `0.0.0.0/0` for security!

### 2. Authenticate with AWS SSO

```bash
# Login to AWS SSO
aws sso login

# Verify your credentials
aws sts get-caller-identity
```

**Note**: AWS SSO sessions typically expire after a few hours. If you get authentication errors, run `aws sso login` again. Terraform will automatically use your AWS SSO credentials from the AWS CLI configuration.

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

After deployment, Terraform will output:
- Instance public IP
- SSH command
- Public DNS name

### 4. Connect to the Instance

```bash
# Use the SSH command from Terraform output, or:
ssh -i ~/.ssh/your-key.pem ubuntu@<instance-ip>
```

### 5. Set Up the Instance

On the EC2 instance:

```bash
# Clone or copy the repository
cd /opt/easytrade

# Run the setup script
sudo bash /path/to/infrastructure/deploy/ec2-setup.sh
```

The setup script will:
- Configure Docker authentication to ghcr.io
- Create necessary directories
- Set up environment variables

### 6. Deploy Services

```bash
# Copy compose.yaml to the instance
scp compose.yaml ubuntu@<instance-ip>:/opt/easytrade/

# On the instance, run deployment
cd /opt/easytrade
bash /path/to/infrastructure/deploy/ec2-deploy.sh
```

## Deployment Method

This infrastructure deploys EasyTrade using **Docker Compose** (not Kubernetes). All services run as Docker containers managed by docker-compose on a single EC2 instance.

## Configuration

### Environment Variables

The deployment uses a `.env` file in `/opt/easytrade/`. Key variables:

- `REGISTRY`: Container registry (default: `ghcr.io/your-username`)
- `TAG`: Image tag (default: `latest`)
- `SA_PASSWORD`: SQL Server password
- RabbitMQ configuration variables

### GitHub Container Registry Authentication

To pull images from ghcr.io, you need a GitHub Personal Access Token:

1. Create a token at https://github.com/settings/tokens
2. Grant `read:packages` permission
3. Set it as an environment variable:
   ```bash
   export GITHUB_TOKEN=your-token-here
   ```
4. Run the setup script, which will configure Docker authentication

## Managing Services

### Start Services
```bash
cd /opt/easytrade
docker-compose up -d
```

### Stop Services
```bash
cd /opt/easytrade
docker-compose down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f accountservice
```

### Check Status
```bash
docker-compose ps
```

### Restart a Service
```bash
docker-compose restart accountservice
```

## Accessing the Application

After deployment, access the application at:
- **Frontend**: `http://<instance-ip>`
- **Services**: `http://<instance-ip>:8080-8094` (depending on service)

## Security Considerations

1. **SSH Access**: The default security group allows SSH from `0.0.0.0/0`. **Change this** to your IP address in `terraform.tfvars`.

2. **Firewall**: Consider using AWS Security Groups to restrict access further.

3. **Secrets**: Store sensitive values (passwords, tokens) in AWS Systems Manager Parameter Store or Secrets Manager instead of plain text.

4. **Updates**: Keep the instance and Docker images updated for security patches.

## Troubleshooting

### Docker Authentication Issues

If you can't pull images from ghcr.io:

```bash
# Check current authentication
cat ~/.docker/config.json

# Re-authenticate
docker login ghcr.io
```

### Services Not Starting

1. Check Docker logs:
   ```bash
   docker-compose logs
   ```

2. Verify environment variables:
   ```bash
   cat /opt/easytrade/.env
   ```

3. Check Docker resources:
   ```bash
   docker system df
   docker stats
   ```

### Out of Memory

If services are being killed:

1. Check memory usage:
   ```bash
   free -h
   docker stats
   ```

2. Consider upgrading to a larger instance type (e.g., m5.2xlarge)

3. Reduce resource limits in `compose.yaml` if needed

### Network Issues

1. Check security group rules:
   ```bash
   # From your local machine
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. Verify instance has public IP:
   ```bash
   # On the instance
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

## Cleanup

To destroy the infrastructure:

```bash
cd infrastructure/terraform
terraform destroy
```

**Note**: The instance has a `do-not-delete=true` tag. Terraform will still destroy it, but this tag helps prevent accidental deletion through the AWS console.

## Cost Estimation

- **m5.xlarge**: ~$0.192/hour (~$140/month)
- **EBS Storage (50GB gp3)**: ~$4/month
- **Data Transfer**: Varies by usage

Total estimated cost: ~$150/month (excluding data transfer)

## Support

For issues or questions:
1. Check the logs: `docker-compose logs`
2. Review this README
3. Check the main EasyTrade repository documentation

