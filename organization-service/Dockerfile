# Runtime Dockerfile — uses pre-built JAR from Maven build
# For local builds: run `make build` first, then `make image-build`
# For CI: the builds job produces JARs before Docker builds

FROM eclipse-temurin:25.0.3_9-jre-noble@sha256:f9bd8815e73632c22985ebb133ec49b9fc4ad5ffe0657594ac02748ad0431ab7 AS extract
WORKDIR /tmp
COPY target/*.jar app.jar
RUN java -Djarmode=tools -jar app.jar extract --layers --destination extracted

FROM eclipse-temurin:25.0.3_9-jre-noble@sha256:f9bd8815e73632c22985ebb133ec49b9fc4ad5ffe0657594ac02748ad0431ab7 AS runtime

# Patch base-image OS packages for security fixes that lag the base rebuild
# (e.g. CVE-2026-45447 in libssl3t64/openssl). Runs as root before the
# non-root USER switch. DL3005 is intentionally allowed (see .hadolint.yaml).
RUN apt-get update && apt-get upgrade -y \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -r appuser && useradd -r -g appuser -u 10001 -d /application appuser
USER 10001
WORKDIR /application

COPY --from=extract --chown=appuser:appuser /tmp/extracted/dependencies/ ./
COPY --from=extract --chown=appuser:appuser /tmp/extracted/spring-boot-loader/ ./
COPY --from=extract --chown=appuser:appuser /tmp/extracted/snapshot-dependencies/ ./
COPY --from=extract --chown=appuser:appuser /tmp/extracted/application/ ./

EXPOSE 8080

ENV JAVA_TOOL_OPTIONS="-XX:MinRAMPercentage=60.0 -XX:MaxRAMPercentage=90.0 \
-Djava.awt.headless=true -Dfile.encoding=UTF-8 \
-Dspring.output.ansi.enabled=ALWAYS"

# HEALTHCHECK: not needed — Kubernetes startup/readiness/liveness probes
# handle health checks. For standalone Docker use, add:
# HEALTHCHECK CMD ["curl","-sf","http://localhost:8080/actuator/health"]
ENTRYPOINT ["java", "-jar", "app.jar"]
