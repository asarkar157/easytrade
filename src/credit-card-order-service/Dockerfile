FROM eclipse-temurin:21.0.8_9-jdk-alpine-3.22@sha256:89517925fa675c6c4b770bee7c44d38a7763212741b0d6fca5a5103caab21a97 AS build

WORKDIR /app
# make gradlew download gradle files before copying source files to use caching
COPY ["build.gradle", "settings.gradle", "gradlew", "./"]
COPY ["gradle", "gradle"]
RUN ./gradlew dependencies

COPY ["src", "./src"]

RUN ./gradlew test bootJar

FROM eclipse-temurin:21.0.8_9-jre-alpine-3.22@sha256:990397e0495ac088ab6ee3d949a2e97b715a134d8b96c561c5d130b3786a489d

# Download OpenTelemetry Java agent
ARG OTEL_AGENT_VERSION=2.2.0
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar /opt/opentelemetry-javaagent.jar
RUN chmod 644 /opt/opentelemetry-javaagent.jar

RUN addgroup --system --gid 3369 easytrade \
    && adduser --system --ingroup easytrade --uid 3369 easytrade
USER easytrade:easytrade
WORKDIR /home/easytrade

COPY --from=build --chown=easytrade:easytrade ["/app/build/libs/*.jar", "app.jar"]

# Environment variables for OpenTelemetry
ENV OTEL_SERVICE_NAME=credit-card-order-service
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp
ENV OTEL_LOGS_EXPORTER=otlp
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
ENV OTEL_RESOURCE_ATTRIBUTES=service.namespace=easytrade,deployment.environment=local

CMD ["java", "-javaagent:/opt/opentelemetry-javaagent.jar", "-jar", "app.jar"]
