# Runtime Dockerfile — uses pre-built JAR from Maven build
# For local builds: run `make build` first, then `make image-build`
# For CI: the builds job produces JARs before Docker builds

ARG VARIANT=nonroot@sha256:7e37784d94dccbf5ccb195c73b295f5ad00cd266512dfbac12eb9c3c28f8077d

FROM eclipse-temurin:21-jre@sha256:a27f3be269a0a12b99ee58af1c4ebe45233d119d3926f643e3da5d298d4726dc AS extract
WORKDIR /tmp
COPY target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

FROM gcr.io/distroless/java21-debian12:${VARIANT} AS runtime

USER nonroot:nonroot
WORKDIR /application

COPY --from=extract --chown=nonroot:nonroot /tmp/dependencies/ ./
COPY --from=extract --chown=nonroot:nonroot /tmp/snapshot-dependencies/ ./
COPY --from=extract --chown=nonroot:nonroot /tmp/spring-boot-loader/ ./
COPY --from=extract --chown=nonroot:nonroot /tmp/application/ ./

EXPOSE 8080

ENV _JAVA_OPTIONS="-XX:MinRAMPercentage=60.0 -XX:MaxRAMPercentage=90.0 \
-Djava.security.egd=file:/dev/./urandom \
-Djava.awt.headless=true -Dfile.encoding=UTF-8 \
-Dspring.output.ansi.enabled=ALWAYS \
-Dspring.profiles.active=default"

# HEALTHCHECK: not needed — Kubernetes startup/readiness/liveness probes
# handle health checks. Distroless :nonroot has no shell or curl.
# For standalone Docker use, run with --build-arg VARIANT=debug and
# add: HEALTHCHECK CMD ["wget","--spider","-q","http://localhost:8080/actuator/health"]
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
