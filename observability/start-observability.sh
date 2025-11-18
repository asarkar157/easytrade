#!/bin/bash

set -e

echo "======================================"
echo "  EasyTrade Observability Stack"
echo "======================================"
echo

# Create easytrade network if it doesn't exist
if ! docker network inspect easytrade &> /dev/null; then
    echo "Creating 'easytrade' network..."
    docker network create easytrade
fi

# Start observability stack
echo "Starting observability stack..."
docker-compose -f docker-compose-observability.yml up -d

echo
echo "Waiting for services to be healthy..."
sleep 10

echo
echo "======================================"
echo "  Observability Stack is Ready!"
echo "======================================"
echo
echo "Access the following UIs:"
echo
echo "  Grafana:     http://localhost:3000"
echo "               Username: admin"
echo "               Password: admin"
echo
echo "  Jaeger:      http://localhost:16686"
echo "  Prometheus:  http://localhost:9090"
echo
echo "======================================"
echo "  Next Steps"
echo "======================================"
echo
echo "1. Start your EasyTrade services:"
echo "   cd .."
echo "   docker-compose build"
echo "   docker-compose up -d"
echo
echo "2. Generate some load to create traces"
echo
echo "3. View traces in Jaeger or Grafana"
echo
echo "For more information, see observability/README.md"
echo
