# CLAUDE.md

## Project Overview

Spring Boot microservices with Spring Cloud Kubernetes. Multi-module Maven project
deploying four services (employee, department, organization, gateway) to a Kubernetes
cluster with MongoDB backing.

## Repository Layout

```
spring-microservices-k8s/
  department-service/    # Department microservice (Spring Boot)
  employee-service/      # Employee microservice (Spring Boot)
  gateway-service/       # API gateway (Spring Cloud Gateway)
  organization-service/  # Organization microservice (Spring Boot)
  k8s/                   # Kubernetes manifests (deployments, configmaps, secrets)
  scripts/               # Shell scripts for cluster setup, deploy, teardown
  pom.xml                # Parent POM (multi-module)
```

## Build & Run

```bash
# Build all modules
mvn clean package

# Start Minikube cluster
./scripts/start-cluster.sh

# Configure cluster (namespaces, RBAC)
./scripts/setup-cluster.sh

# Deploy all services
./scripts/install-all.sh

# Populate test data
./scripts/populate-data.sh

# Open Swagger UI
./scripts/gateway-open.sh
```

## Teardown

```bash
./scripts/delete-all.sh      # Undeploy services
./scripts/destroy-cluster.sh  # Remove cluster config
./scripts/stop-cluster.sh     # Stop Minikube
```

## CI/CD

- **main.yml** -- builds with Maven, builds Docker images, pushes on tags
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 11, Spring Boot, Spring Cloud Kubernetes
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Minikube for local dev)
- MongoDB
