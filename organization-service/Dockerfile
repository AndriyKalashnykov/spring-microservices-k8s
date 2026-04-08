# Runtime Dockerfile — uses pre-built JAR from Maven build
# For local builds: run `make build` first, then `make image-build`
# For CI: the builds job produces JARs before Docker builds

ARG VARIANT=nonroot

FROM eclipse-temurin:21-jre AS extract
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

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
