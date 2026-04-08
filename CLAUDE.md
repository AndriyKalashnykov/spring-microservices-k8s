# CLAUDE.md

## Project Overview

Spring Boot microservices with Spring Cloud Kubernetes. Multi-module Maven project
deploying four services (employee, department, organization, gateway) to a local Kind
cluster with MongoDB backing.

## Repository Layout

```
spring-microservices-k8s/
  department-service/    # Department microservice (Spring Boot)
  employee-service/      # Employee microservice (Spring Boot)
  gateway-service/       # API gateway (Spring Cloud Gateway MVC)
  organization-service/  # Organization microservice (Spring Boot)
  .github/workflows/     # CI/CD (GitHub Actions)
  k8s/                   # Kubernetes manifests, Kind + MetalLB configs
  e2e/                   # End-to-end test script
  Makefile               # Build orchestration (run `make help`)
  pom.xml                # Parent POM (multi-module)
```

## Build & Run

```bash
make build         # Build all modules
make kind-create   # Create local Kind cluster with MetalLB
make kind-setup    # Configure namespaces, RBAC, deploy MongoDB
make kind-deploy   # Build, load, and deploy all services
make populate      # Seed test data
make gateway-open  # Open Swagger UI
```

## Teardown

```bash
make kind-undeploy   # Remove services
make kind-destroy    # Delete Kind cluster
```

## CI/CD

- **main.yml** -- `ci` job (build/lint/test via `make ci`) + `docker` job (tag-gated multi-arch image builds)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 21, Spring Boot 3.4, Spring Cloud Kubernetes (2024.0)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + MetalLB for local dev)
- MongoDB 7.0

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |
| `CLAUDE.md` | `/claude` |
| `renovate.json` | `/renovate` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
