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
echo "OpenTelemetry Collector is running and configured to send data to:"
echo
if [ -n "$JAEGER_ENDPOINT" ]; then
  echo "  Jaeger:      $JAEGER_ENDPOINT"
else
  echo "  Jaeger:      (not configured - set JAEGER_ENDPOINT)"
fi
if [ -n "$LOKI_ENDPOINT" ]; then
  echo "  Loki:        $LOKI_ENDPOINT"
else
  echo "  Loki:        (not configured - set LOKI_ENDPOINT)"
fi
echo "  Prometheus:  Scrape http://<otel-collector-host>:8889/metrics"
echo
echo "======================================"
echo "  Next Steps"
echo "======================================"
echo
echo "1. Configure your external Prometheus to scrape:"
echo "   http://<otel-collector-host>:8889/metrics"
echo
echo "2. Start your EasyTrade services:"
echo "   cd .."
echo "   docker-compose build"
echo "   docker-compose up -d"
echo
echo "3. Generate some load to create traces"
echo
echo "4. View data in your external Grafana instance"
echo
echo "For more information, see observability/README.md"
echo
