# Runtime Dockerfile — uses pre-built JAR from Maven build
# For local builds: run `make build` first, then `make image-build`
# For CI: the builds job produces JARs before Docker builds

FROM eclipse-temurin:25.0.2_10-jre-noble@sha256:aa8759eb18c5fcab069c62558a6f7e0b26359c29cc889a29ed7e5bbaed6a9ce5 AS extract
WORKDIR /tmp
COPY target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

FROM eclipse-temurin:25.0.2_10-jre-noble@sha256:aa8759eb18c5fcab069c62558a6f7e0b26359c29cc889a29ed7e5bbaed6a9ce5 AS runtime

RUN groupadd -r appuser && useradd -r -g appuser -u 10001 -d /application appuser
USER 10001
WORKDIR /application

COPY --from=extract --chown=appuser:appuser /tmp/dependencies/ ./
COPY --from=extract --chown=appuser:appuser /tmp/snapshot-dependencies/ ./
COPY --from=extract --chown=appuser:appuser /tmp/spring-boot-loader/ ./
COPY --from=extract --chown=appuser:appuser /tmp/application/ ./

EXPOSE 8080

ENV JAVA_TOOL_OPTIONS="-XX:MinRAMPercentage=60.0 -XX:MaxRAMPercentage=90.0 \
-Djava.awt.headless=true -Dfile.encoding=UTF-8 \
-Dspring.output.ansi.enabled=ALWAYS"

# HEALTHCHECK: not needed — Kubernetes startup/readiness/liveness probes
# handle health checks. For standalone Docker use, add:
# HEALTHCHECK CMD ["curl","-sf","http://localhost:8080/actuator/health"]
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
