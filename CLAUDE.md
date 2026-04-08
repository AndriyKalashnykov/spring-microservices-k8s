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
  docs/                  # Architecture documentation and diagrams
  Makefile               # Build orchestration (run `make help`)
  pom.xml                # Parent POM (multi-module)
  renovate.json          # Renovate dependency update configuration
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

- **ci.yml** -- `lint` (static-check + Trivy), `builds`, `tests` (coverage), `cve-check` (OWASP) + `docker` (tag-gated)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 25, Spring Boot 3.5, Spring Cloud Kubernetes (2025.0)
- RestClient with @HttpExchange (inter-service communication)
- Micrometer Tracing (distributed trace propagation)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + MetalLB for local dev)
- MongoDB 8
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks (static analysis)

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

## Deferred Upgrades

| Item | Blocker | Revisit |
|------|---------|---------|
| SpringDoc 2.x → 3.x | Incompatible with Spring Boot 3.5 (`NoClassDefFoundError` on relocated `ErrorPageRegistrar`) | When SpringDoc releases SB 3.5-compatible version |
| Spring Boot 4.x | Ecosystem not ready — SpringDoc, Spring Cloud need compatible releases. MongoDB property renames, tracing config changes. | 3-6 months after SB 4.0 GA (October 2026+) |
