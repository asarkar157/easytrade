# Problem Patterns for Docker Compose Deployment

This directory contains scripts to enable/disable problem patterns when running EasyTrade via Docker Compose on EC2.

## Problem Patterns

1. **DB Not Responding** - Prevents new trades from being created (runs ~20 minutes)
2. **High CPU Usage** - Causes broker-service slowdown and high CPU usage
3. **Factory Crisis** - Prevents factory from producing cards, blocking credit card orders
4. **Ergo Aggregator Slowdown** - Causes aggregators to receive slower responses

## Manual Usage

You can manually enable/disable problem patterns using the scripts:

```bash
# Enable a problem pattern
./enable-db-not-responding.sh

# Disable a problem pattern
./disable-db-not-responding.sh
```

Or use the generic toggle script:

```bash
# Set FEATURE_FLAG_SERVICE_URL if accessing from outside Docker network
export FEATURE_FLAG_SERVICE_URL=http://localhost:8080

# Toggle any pattern
./toggle-problem-pattern.sh <flag-id> <true|false>

# Examples:
./toggle-problem-pattern.sh db_not_responding true
./toggle-problem-pattern.sh high_cpu_usage false
./toggle-problem-pattern.sh factory_crisis true
./toggle-problem-pattern.sh ergo_aggregator_slowdown false
```

## Automated Scheduling with Cron

To automatically run problem patterns on a schedule (matching the Kubernetes CronJob schedule):

### 1. Copy scripts to EC2 instance

```bash
# From your local machine
scp -i ~/.ssh/EC2-SSH.pem -r infrastructure/deploy/problem-patterns ubuntu@<EC2_IP>:/opt/easytrade/infrastructure/deploy/
```

### 2. Make scripts executable

```bash
# On EC2 instance
chmod +x /opt/easytrade/infrastructure/deploy/problem-patterns/*.sh
```

### 3. Update FEATURE_FLAG_SERVICE_URL in scripts

If the feature-flag-service is not accessible at `http://localhost:8080`, you can either:

**Option A:** Set environment variable in crontab:
```bash
# Edit crontab
crontab -e

# Add at the top:
FEATURE_FLAG_SERVICE_URL=http://feature-flag-service:8080
```

**Option B:** Modify the scripts to use the Docker network:
```bash
# Update toggle-problem-pattern.sh to use Docker exec
# Or use the service name if running from within Docker network
```

**Option C:** Use Docker exec to run curl from within the network:
```bash
# Modify scripts to use:
docker exec easytrade-feature-flag-service-1 curl ...
```

### 4. Install crontab

```bash
# On EC2 instance
crontab /opt/easytrade/infrastructure/deploy/problem-patterns/crontab.example

# Verify installation
crontab -l
```

### 5. Create log directory (optional)

```bash
sudo touch /var/log/easytrade-problem-patterns.log
sudo chown ubuntu:ubuntu /var/log/easytrade-problem-patterns.log
```

## Schedule

The default schedule matches the Kubernetes CronJobs:

- **DB Not Responding**: Enabled at 20:00 UTC, Disabled at 20:25 UTC
- **High CPU Usage**: Enabled at 04:00 UTC, Disabled at 04:25 UTC
- **Factory Crisis**: Enabled at 16:00 UTC, Disabled at 19:00 UTC
- **Ergo Aggregator Slowdown**: Enabled at 22:00 UTC, Disabled at 22:25 UTC

All times are in UTC. Adjust the schedule in `crontab.example` to match your timezone.

## Alternative: Using Docker Compose Service

You can also create a Docker Compose service that runs cron jobs. Create a `docker-compose-cron.yml`:

```yaml
services:
  problem-patterns-cron:
    image: alpine:latest
    volumes:
      - ./infrastructure/deploy/problem-patterns:/scripts:ro
      - /var/log:/var/log
    command: >
      sh -c "
        apk add --no-cache curl dcron &&
        chmod +x /scripts/*.sh &&
        echo '0 20 * * * /scripts/enable-db-not-responding.sh >> /var/log/easytrade-problem-patterns.log 2>&1' | crontab - &&
        crond -f
      "
    network_mode: service:feature-flag-service
    restart: unless-stopped
```

## Troubleshooting

1. **Check if feature-flag-service is accessible:**
   ```bash
   curl http://localhost:8080/v1/flags
   ```

2. **Check cron logs:**
   ```bash
   tail -f /var/log/easytrade-problem-patterns.log
   ```

3. **Test scripts manually:**
   ```bash
   export FEATURE_FLAG_SERVICE_URL=http://localhost:8080
   ./toggle-problem-pattern.sh db_not_responding true
   ```

4. **Verify cron is running:**
   ```bash
   systemctl status cron  # On Ubuntu/Debian
   ```

