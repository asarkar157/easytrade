# EasyTrade Observability Stack

This directory contains the configuration for the EasyTrade observability stack, which includes:

- **OpenTelemetry Collector**: Receives, processes, and exports telemetry data to external observability backends

**Note**: This setup is configured to send telemetry data to **external instances** of Prometheus, Loki, Grafana, and Jaeger. The OpenTelemetry Collector acts as the central hub that receives telemetry from your services and forwards it to your existing observability infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 EasyTrade Services                  │
│  (Java, Node.js, .NET, Go - All instrumented)      │
└────────────────┬────────────────────────────────────┘
                 │
                 │ OTLP (gRPC/HTTP)
                 ▼
         ┌───────────────┐
         │ OTel Collector│
         │  (Port 4318)  │
         └───────┬───────┘
                 │
      ┌──────────┼──────────┐
      │          │          │
      ▼          ▼          ▼
  ┌────────┐ ┌──────┐ ┌──────────┐
  │ Jaeger │ │ Loki │ │Prometheus│
  │(External│ │(External│ │ (External) │
  │Instance)│ │Instance)│ │  Instance   │
  └────┬───┘ └───┬──┘ └────┬─────┘
       │         │         │
       └─────────┼─────────┘
                 ▼
           ┌──────────┐
           │ Grafana  │
           │(External │
           │ Instance)│
           └──────────┘
```

**Note**: Prometheus, Loki, and Grafana are external instances. The OpenTelemetry Collector forwards:
- **Traces** → External Jaeger (via OTLP)
- **Logs** → External Loki (via HTTP push API)
- **Metrics** → External Prometheus (via scrape endpoint on port 8889)

## Quick Start

### 1. Configure External Observability Endpoints

**⚠️ IMPORTANT**: Before starting the observability stack with docker compose, you **must** set the following environment variables if you want to connect to external Jaeger and Loki instances:

```bash
export JAEGER_ENDPOINT=http://your-jaeger-host:4318
export LOKI_ENDPOINT=http://your-loki-host:3100/loki/api/v1/push
export JAEGER_INSECURE=true  # Set to false if using TLS
```

**Note**: 
- These environment variables are **required** when using docker compose to connect to external Jaeger and Loki systems
- If these variables are not set, the OpenTelemetry Collector will not be able to export traces and logs to your external instances
- For Prometheus, you don't need to set an environment variable. Instead, configure your external Prometheus to scrape the OpenTelemetry Collector's metrics endpoint (see Configuration section below)

### 2. Start the Observability Stack

Make sure the environment variables are set in your current shell session, then start the stack:

```bash
cd observability
docker-compose -f docker-compose-observability.yml up -d
```

**Alternative**: You can also pass environment variables directly to docker compose:

```bash
cd observability
JAEGER_ENDPOINT=http://your-jaeger-host:4318 \
LOKI_ENDPOINT=http://your-loki-host:3100/loki/api/v1/push \
JAEGER_INSECURE=true \
docker-compose -f docker-compose-observability.yml up -d
```

This will start:
- **OpenTelemetry Collector**: Receives telemetry from your services and forwards to external observability backends

### 3. Configure External Prometheus

Add the following scrape configuration to your external Prometheus instance to collect metrics from the OpenTelemetry Collector:

```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['<otel-collector-host>:8889']
        labels:
          service: 'otel-collector'
```

Replace `<otel-collector-host>` with the hostname or IP address where the OpenTelemetry Collector is running.

### 4. Start Your EasyTrade Services

Rebuild and start your services to include the OpenTelemetry instrumentation:

```bash
# From the root of the easytrade repository
docker-compose build
docker-compose up -d
```

## What's Instrumented

### Java/Spring Boot Services (Auto-instrumented via Java Agent)

The following services automatically collect traces and metrics with zero code changes:

- **accountservice** - Account management
- **contentcreator** - Content generation
- **credit-card-order-service** - Credit card order processing
- **engine** - Trading engine
- **feature-flag-service** - Feature flag management
- **third-party-service** - Third-party integrations

**What's captured:**
- HTTP requests/responses (latency, status codes, paths)
- Database queries (via JDBC instrumentation)
- JVM metrics (memory, GC, threads)
- Custom business metrics (if added via Micrometer)

### Node.js Services (Auto-instrumented via OpenTelemetry SDK)

- **offerservice** - Offer management
- **loadgenerator** - Load generation

**What's captured:**
- HTTP requests/responses (Express routes)
- Outbound HTTP calls (axios)
- Custom spans (if added)
- Node.js runtime metrics (event loop lag, memory usage)

### .NET Services (Auto-instrumented via OpenTelemetry SDK)

- **loginservice** - Authentication
- **broker-service** - Broker operations
- **manager** - Management operations

**What's captured:**
- ASP.NET Core requests/responses
- HTTP client calls
- Entity Framework Core database queries
- .NET runtime metrics (GC, exceptions, thread pool)

## Data Types and Formats

### 1. Traces (→ Jaeger)

Distributed traces show the complete journey of a request through your microservices.

**Example trace:**
```
User Request → Frontend → Offer Service → Aggregator → Pricing Service → Database
```

Each service creates spans that include:
- Service name and operation
- Start time and duration
- HTTP method, path, status code
- Database queries
- Errors and stack traces

**Viewing traces in Grafana:**
1. Go to Explore
2. Select "Jaeger" datasource (configured to point to your external Jaeger instance)
3. Search by service name, operation, or trace ID
4. Click on a trace to see the waterfall view

### 2. Metrics (→ Prometheus)

Time-series metrics for monitoring and alerting.

**Auto-collected metrics include:**

**HTTP metrics:**
- `http_server_duration_seconds` - Request latency histogram
- `http_server_requests_total` - Request count by status
- `http_client_duration_seconds` - Outbound request latency

**Runtime metrics:**
- Java: `jvm_memory_used_bytes`, `jvm_gc_pause_seconds`
- Node.js: `nodejs_eventloop_lag_seconds`, `nodejs_heap_size_total_bytes`
- .NET: `dotnet_gc_heap_size_bytes`, `dotnet_threadpool_num_threads`

**Database metrics:**
- `db_client_operation_duration_seconds` - Database query latency

**Viewing metrics in Grafana:**
1. Go to Explore
2. Select "Prometheus" datasource (configured to point to your external Prometheus instance)
3. Use PromQL queries:
   ```promql
   # Request rate by service
   rate(http_server_requests_total[5m])

   # 95th percentile latency
   histogram_quantile(0.95, rate(http_server_duration_seconds_bucket[5m]))

   # Error rate
   rate(http_server_requests_total{status=~"5.."}[5m])
   ```

### 3. Logs (→ Loki)

Structured logs with trace correlation.

**Log correlation:**
Logs automatically include `trace_id` and `span_id` for correlation with traces.

**Example log entry:**
```json
{
  "timestamp": "2025-11-17T10:30:45.123Z",
  "level": "INFO",
  "service": "offerservice",
  "trace_id": "abc123def456",
  "span_id": "789ghi012jkl",
  "message": "Processing offer request",
  "user_id": "user-123",
  "offer_id": "offer-456"
}
```

**Querying logs in Grafana:**
1. Go to Explore
2. Select "Loki" datasource (configured to point to your external Loki instance)
3. Use LogQL queries:
   ```logql
   # All logs from a service
   {service_name="offerservice"}

   # Error logs only
   {service_name="offerservice"} |= "ERROR"

   # Logs for a specific trace
   {service_name="offerservice"} | json | trace_id="abc123def456"
   ```

## Correlation Features in Grafana

### 1. Trace → Logs

Click on any span in Jaeger, then click "View Logs" to see all logs related to that trace.

### 2. Logs → Trace

In Loki log results, trace IDs are automatically linked. Click the trace ID to jump to Jaeger.

### 3. Metrics → Traces

Prometheus metrics include exemplars that link to example traces for specific metric values.

### 4. Alerts → Everything

Set up Prometheus alerts that include trace IDs in notifications:
```yaml
groups:
  - name: latency_alerts
    rules:
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_server_duration_seconds_bucket[5m])) > 1
        annotations:
          summary: "High latency detected"
          description: "95th percentile latency is {{ $value }}s"
```

## Configuration Files

### OpenTelemetry Collector

**File:** `otel-collector-config.yml`

Key features:
- Receives OTLP data on ports 4317 (gRPC) and 4318 (HTTP)
- Batches telemetry for efficiency
- Exports traces to external Jaeger (configured via `JAEGER_ENDPOINT` environment variable)
- Exports metrics via Prometheus exporter endpoint (port 8889) for external Prometheus to scrape
- Exports logs to external Loki (configured via `LOKI_ENDPOINT` environment variable)
- Generates span metrics (RED metrics from traces)

**Environment Variables (Required for Docker Compose):**
- `JAEGER_ENDPOINT`: URL of your external Jaeger instance (e.g., `http://jaeger.example.com:4318`)
  - **Required** when using docker compose to connect to external Jaeger
  - Must be set before running `docker-compose up`
- `LOKI_ENDPOINT`: URL of your external Loki push API (e.g., `http://loki.example.com:3100/loki/api/v1/push`)
  - **Required** when using docker compose to connect to external Loki
  - Must be set before running `docker-compose up`
- `JAEGER_INSECURE`: Set to `true` if Jaeger doesn't use TLS, `false` otherwise (default: `true`)

**Example:**
```bash
# Set environment variables
export JAEGER_ENDPOINT=http://your-jaeger-host:4318
export LOKI_ENDPOINT=http://your-loki-host:3100/loki/api/v1/push
export JAEGER_INSECURE=true

# Then start docker compose
cd observability
docker-compose -f docker-compose-observability.yml up -d
```

**Prometheus Configuration:**
The OpenTelemetry Collector exposes metrics on port 8889. Configure your external Prometheus to scrape this endpoint:

```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['<otel-collector-host>:8889']
```

### External Observability Stack

This setup assumes you have existing instances of:
- **Prometheus**: For metrics storage and querying
- **Loki**: For log aggregation
- **Grafana**: For visualization and dashboards

Configure these in your Grafana instance to connect to your external Prometheus, Loki, and Jaeger instances.

## Customization

### Adding Custom Metrics

**Java (Micrometer):**
```java
@Autowired
private MeterRegistry meterRegistry;

public void processOrder(Order order) {
    Counter.builder("orders_processed")
        .tag("product", order.getProduct())
        .register(meterRegistry)
        .increment();
}
```

**Node.js (OpenTelemetry):**
```javascript
const { metrics } = require('@opentelemetry/api');
const meter = metrics.getMeter('offerservice');

const orderCounter = meter.createCounter('orders_processed', {
  description: 'Number of orders processed'
});

orderCounter.add(1, { product: 'stock' });
```

**.NET (OpenTelemetry):**
```csharp
using System.Diagnostics.Metrics;

var meter = new Meter("BrokerService");
var orderCounter = meter.CreateCounter<long>("orders_processed");

orderCounter.Add(1, new KeyValuePair<string, object?>("product", "stock"));
```

### Adding Custom Spans

**Java:**
```java
@Autowired
private Tracer tracer;

public void complexOperation() {
    Span span = tracer.spanBuilder("complex_operation").startSpan();
    try (Scope scope = span.makeCurrent()) {
        // Your code here
        span.addEvent("Processing step 1");
        // More code
    } finally {
        span.end();
    }
}
```

**Node.js:**
```javascript
const { trace } = require('@opentelemetry/api');

function complexOperation() {
  const span = trace.getTracer('offerservice').startSpan('complex_operation');
  try {
    // Your code here
    span.addEvent('Processing step 1');
    // More code
  } finally {
    span.end();
  }
}
```

**.NET:**
```csharp
using System.Diagnostics;

var activitySource = new ActivitySource("BrokerService");

using (var activity = activitySource.StartActivity("ComplexOperation"))
{
    // Your code here
    activity?.AddEvent(new ActivityEvent("Processing step 1"));
    // More code
}
```

## Troubleshooting

### Services not sending data

1. **Check OTel Collector is running:**
   ```bash
   docker ps | grep otel-collector
   docker logs otel-collector
   ```

2. **Verify environment variables in services:**
   ```bash
   docker exec <service-name> env | grep OTEL
   ```

   Should show:
   ```
   OTEL_SERVICE_NAME=<service-name>
   OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
   ```

3. **Check network connectivity:**
   ```bash
   docker exec <service-name> ping otel-collector
   ```

### No traces in Jaeger

1. Check OTel Collector logs for export errors
2. Verify Jaeger is receiving data:
   ```bash
   docker logs jaeger
   ```
3. Generate load on your services to create traces

### Prometheus not scraping metrics

1. Check Prometheus targets in your external Prometheus instance
2. Verify the OpenTelemetry Collector is accessible from Prometheus:
   ```bash
   curl http://<otel-collector-host>:8889/metrics
   ```
3. Verify the scrape configuration in your external Prometheus includes the OpenTelemetry Collector endpoint
4. Check that services expose metrics endpoints (if scraping directly):
   - Java: http://<service>:8080/actuator/prometheus
   - Node.js/Go/.NET: http://<service>:8080/metrics

### External observability endpoints not receiving data

1. Verify environment variables are set correctly:
   ```bash
   docker exec otel-collector env | grep -E "JAEGER_ENDPOINT|LOKI_ENDPOINT"
   ```
2. Check OpenTelemetry Collector logs for export errors:
   ```bash
   docker logs otel-collector
   ```
3. Test connectivity from the collector to external endpoints:
   ```bash
   docker exec otel-collector wget -O- <your-jaeger-endpoint>
   docker exec otel-collector wget -O- <your-loki-endpoint>
   ```
4. Verify your external Prometheus can reach the collector's metrics endpoint (port 8889)

### Grafana datasources not working

1. Check datasource configuration in your external Grafana UI (Configuration → Data Sources)
2. Test connection for each datasource
3. Verify URLs point to your external instances:
   - Prometheus: `http://your-prometheus-host:9090`
   - Jaeger: `http://your-jaeger-host:16686` (or OTLP endpoint)
   - Loki: `http://your-loki-host:3100`

## Resource Usage

Approximate resource requirements for local components:

| Component | CPU | Memory |
|-----------|-----|--------|
| OTel Collector | 0.1-0.5 cores | 256-512 MB |
| **Total** | **0.1-0.5 cores** | **256-512 MB** |

**Note**: Prometheus, Loki, Grafana, and Jaeger run on your external infrastructure and are not included in these resource requirements.

## Production Considerations

This setup is configured to work with external observability infrastructure, making it suitable for both development and production:

1. **High Availability:**
   - Run multiple replicas of OTel Collector
   - Use distributed Jaeger backend (Elasticsearch/Cassandra)
   - Use Loki with object storage (S3/GCS)
   - Use Prometheus with remote write to long-term storage

2. **Security:**
   - Enable authentication on all components
   - Use TLS for all connections
   - Implement RBAC in Grafana
   - Secure OTel Collector endpoints

3. **Data Retention:**
   - Configure appropriate retention policies
   - Archive old traces to object storage
   - Use recording rules in Prometheus for long-term metrics

4. **Sampling:**
   - Implement head-based sampling in OTel Collector
   - Use tail-based sampling for complex scenarios
   - Adjust sampling rates based on traffic

## Further Reading

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Grafana Documentation](https://grafana.com/docs/grafana/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review component logs: `docker logs <component-name>`
3. Consult the official documentation links
