# OpenTelemetry Auto-Instrumentation Implementation Summary

## Overview

This document summarizes the OpenTelemetry auto-instrumentation implementation across all EasyTrade services. The implementation enables services to export telemetry data (traces, metrics, and logs) to Jaeger, Prometheus, and Loki for visualization in Grafana.

## Implementation Approach

All services use **auto-instrumentation** with minimal or zero code changes:
- **Java services**: OpenTelemetry Java agent (zero code changes)
- **Node.js services**: OpenTelemetry SDK with auto-instrumentations
- **.NET services**: OpenTelemetry SDK with ASP.NET Core instrumentation

## Files Created

### Observability Infrastructure

1. **observability/otel-collector-config.yml**
   - OpenTelemetry Collector configuration
   - Receives OTLP on ports 4317 (gRPC) and 4318 (HTTP)
   - Exports to Jaeger, Loki, and Prometheus

2. **observability/docker-compose-observability.yml**
   - Complete observability stack (Jaeger, Loki, Prometheus, Grafana, Tempo)
   - Pre-configured with proper networking and volumes

3. **observability/prometheus.yml**
   - Prometheus scrape configuration
   - Targets all instrumented services

4. **observability/loki-config.yml**
   - Loki configuration for log aggregation

5. **observability/tempo-config.yml**
   - Tempo configuration (alternative to Jaeger)

6. **observability/promtail-config.yml**
   - Promtail configuration for log shipping

7. **observability/grafana/provisioning/datasources/datasources.yml**
   - Auto-provisioned Grafana datasources
   - Includes correlation between traces, logs, and metrics

8. **observability/grafana/provisioning/dashboards/dashboards.yml**
   - Dashboard auto-discovery configuration

9. **observability/README.md**
   - Comprehensive documentation
   - Quick start guide
   - Troubleshooting

10. **observability/start-observability.sh**
    - Convenience script to start the stack

## Services Modified

### Java/Spring Boot Services (6 services)

**Services:**
1. accountservice
2. contentcreator
3. credit-card-order-service
4. engine
5. feature-flag-service
6. third-party-service

**Changes per service:**

**Dockerfile modifications:**
- Added OpenTelemetry Java agent download
- Added environment variables for OTLP export
- Modified CMD to include `-javaagent` flag

**Example (accountservice/Dockerfile):**
```dockerfile
# Download OpenTelemetry Java agent
ARG OTEL_AGENT_VERSION=2.2.0
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar /opt/opentelemetry-javaagent.jar

# Environment variables for OpenTelemetry
ENV OTEL_SERVICE_NAME=accountservice
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_LOGS_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
ENV OTEL_RESOURCE_ATTRIBUTES=service.namespace=easytrade,deployment.environment=local

CMD ["java", "-javaagent:/opt/opentelemetry-javaagent.jar", "-jar", "app.jar"]
```

**Auto-instrumented components:**
- HTTP requests (Spring MVC/WebFlux)
- HTTP client (RestTemplate, WebClient)
- JDBC/JPA database calls
- RabbitMQ (if used)
- JVM metrics

### Node.js Services (2 services)

**Services:**
1. offerservice
2. loadgenerator

**Changes per service:**

**package.json additions:**
```json
"@opentelemetry/api": "^1.9.0",
"@opentelemetry/auto-instrumentations-node": "^0.52.1",
"@opentelemetry/exporter-metrics-otlp-proto": "^0.56.0",
"@opentelemetry/exporter-trace-otlp-proto": "^0.56.0",
"@opentelemetry/instrumentation": "^0.56.0",
"@opentelemetry/resources": "^1.29.0",
"@opentelemetry/sdk-metrics": "^1.29.0",
"@opentelemetry/sdk-node": "^0.56.0",
"@opentelemetry/sdk-trace-node": "^1.29.0",
"@opentelemetry/semantic-conventions": "^1.29.0"
```

**New file: instrumentation.js**
- OpenTelemetry SDK initialization
- Auto-instrumentation configuration
- OTLP exporter setup

**Dockerfile modifications:**
- Copy instrumentation.js
- Add environment variables
- Modify CMD to use `--require ./instrumentation.js`

**Auto-instrumented components:**
- HTTP requests (Express)
- HTTP client (axios, fetch)
- DNS lookups
- File system operations (disabled by default)
- Node.js runtime metrics

### .NET Services (3 services)

**Services:**
1. loginservice
2. broker-service
3. manager

**Changes per service:**

**.csproj additions:**
```xml
<PackageReference Include="OpenTelemetry" Version="1.10.0" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.10.0" />
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.10.0" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.10.1" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.10.1" />
<PackageReference Include="OpenTelemetry.Instrumentation.EntityFrameworkCore" Version="1.0.0-beta.13" />
```

**Program.cs / Startup.cs modifications:**
- Added OpenTelemetry using statements
- Configured OpenTelemetry with traces and metrics
- Added instrumentation for ASP.NET Core, HTTP client, and Entity Framework Core

**Example (broker-service/Program.cs):**
```csharp
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(serviceName: serviceName, serviceVersion: "1.0.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = "local",
            ["service.namespace"] = "easytrade"
        }))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter(options => { ... }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options => { ... }));
```

**Dockerfile modifications:**
- Added environment variables for OTLP export

**Auto-instrumented components:**
- ASP.NET Core requests/responses
- HTTP client calls
- Entity Framework Core database queries
- .NET runtime metrics

## Services NOT Instrumented

The following services were not instrumented (reasons provided):

1. **calculationservice** - C++ service, requires manual instrumentation
2. **pricing-service** - Go service, can be instrumented but requires code changes
3. **aggregator-service** - Go service, can be instrumented but requires code changes
4. **frontend** - React app, browser-based tracing requires different approach

## Telemetry Data Collected

### Traces

**Automatic trace collection includes:**
- HTTP request/response (method, path, status, latency)
- Database queries (SQL statements, duration)
- Service-to-service calls
- Error stack traces
- Custom attributes (user ID, transaction ID, etc.)

**Trace context propagation:**
- W3C Trace Context headers (`traceparent`, `tracestate`)
- Automatic context propagation across service boundaries

### Metrics

**HTTP metrics:**
- `http.server.duration` - Request latency histogram
- `http.server.request.count` - Request count by status
- `http.client.duration` - Outbound request latency

**Runtime metrics:**
- Java: JVM memory, GC, thread pool
- Node.js: Event loop lag, heap size
- .NET: CLR metrics, GC, thread pool

**Database metrics:**
- Query duration
- Connection pool utilization
- Query errors

### Logs

**Log correlation:**
- Trace ID automatically injected into logs
- Span ID included for precise correlation
- Service name and attributes added

## Testing the Implementation

### 1. Start the observability stack:
```bash
cd observability
./start-observability.sh
```

### 2. Rebuild and start services:
```bash
docker-compose build
docker-compose up -d
```

### 3. Generate traffic:
- Use the load generator
- Access the frontend and perform actions

### 4. View telemetry:

**Jaeger (Traces):**
- Go to http://localhost:16686
- Select a service from dropdown
- Click "Find Traces"
- Explore trace details and service dependencies

**Prometheus (Metrics):**
- Go to http://localhost:9090
- Run queries:
  ```promql
  rate(http_server_duration_seconds_count[5m])
  histogram_quantile(0.95, rate(http_server_duration_seconds_bucket[5m]))
  ```

**Grafana (Unified View):**
- Go to http://localhost:3000 (admin/admin)
- Explore → Select Jaeger datasource → View traces
- Explore → Select Prometheus datasource → Query metrics
- Explore → Select Loki datasource → View logs
- Click on trace IDs in logs to jump to traces
- Click on "View Logs" in traces to see related logs

## Performance Impact

Auto-instrumentation has minimal performance impact:
- **Java**: ~1-3% overhead with Java agent
- **Node.js**: ~2-5% overhead with SDK
- **.NET**: ~1-3% overhead with SDK

Overhead can be reduced by:
- Adjusting sampling rates
- Disabling unnecessary instrumentations
- Using batch export

## Next Steps

### Immediate:
1. Test the implementation with your application
2. Verify traces appear in Jaeger
3. Confirm metrics in Prometheus
4. Check log correlation in Loki

### Short-term:
1. Create custom Grafana dashboards
2. Add custom spans for business logic
3. Implement custom metrics for KPIs
4. Set up alerting rules

### Long-term:
1. Implement Go service instrumentation (pricing-service, aggregator-service)
2. Add browser-based tracing for frontend
3. Set up production-ready backends (Elasticsearch for Jaeger, S3 for Loki)
4. Implement sampling strategies for high-volume services

## Troubleshooting

### No data in Jaeger/Prometheus/Loki

1. Check OTel Collector logs:
   ```bash
   docker logs otel-collector
   ```

2. Verify service can reach OTel Collector:
   ```bash
   docker exec <service> ping otel-collector
   ```

3. Check service environment variables:
   ```bash
   docker exec <service> env | grep OTEL
   ```

### Build failures

**Java services:**
- Ensure Docker can download from GitHub releases
- Check internet connectivity during build

**Node.js services:**
- Run `npm install` to verify dependencies
- Check for conflicts with existing packages

**.NET services:**
- Ensure NuGet can resolve OpenTelemetry packages
- Check for version conflicts with existing packages

## Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Java Auto-Instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation)
- [Node.js SDK](https://github.com/open-telemetry/opentelemetry-js)
- [.NET SDK](https://github.com/open-telemetry/opentelemetry-dotnet)

## Support

For questions or issues:
1. Review the observability/README.md
2. Check component logs
3. Consult OpenTelemetry documentation
4. Review service-specific instrumentation guides
