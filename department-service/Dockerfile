ARG MVN_VERSION=3.6.3
ARG JDK_VERSION=11

FROM maven:${MVN_VERSION}-jdk-${JDK_VERSION}-slim as build

WORKDIR /build
COPY pom.xml .
# creates a layer with all of the Manven dependencies, first time it takes a while consequent call are very fast
RUN mvn dependency:go-offline

COPY ./pom.xml /tmp/
COPY ./src /tmp/src/
WORKDIR /tmp/
RUN mvn clean package

WORKDIR /application
COPY target/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM gcr.io/distroless/java:${JDK_VERSION}

USER nonroot:nonroot
WORKDIR application

COPY --from=build --chown=nonroot:nonroot /application/dependencies/ ./
COPY --from=build --chown=nonroot:nonroot /application/snapshot-dependencies/ ./
COPY --from=build --chown=nonroot:nonroot /application/resources/ ./
COPY --from=build --chown=nonroot:nonroot /application/application/ ./

EXPOSE 8080

ENV _JAVA_OPTIONS "-XX:MinRAMPercentage=60.0 -XX:MaxRAMPercentage=90.0 \
-Djava.security.egd=file:/dev/./urandom \
-Djava.awt.headless=true -Dfile.encoding=UTF-8 \
-Dspring.output.ansi.enabled=ALWAYS \
-Dspring.profiles.active=default"

ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
