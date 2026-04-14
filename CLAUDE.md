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
  gateway-service/       # API gateway (Spring Cloud Gateway Server WebMVC)
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
make kind-up       # Full cluster lifecycle: deps-kind + kind-create + MetalLB + kind-setup + image-build + kind-deploy
make populate      # Seed test data
make gateway-open  # Open Swagger UI
```

### Test Layers

```bash
make test              # Unit + in-process controller tests (Surefire, seconds)
make e2e               # Full Kind-cluster e2e via gateway LoadBalancer (minutes)
# make integration-test — not yet wired (Failsafe profile pending; see Upgrade Backlog)
```

Granular alternatives (for debugging / partial workflows):

```bash
make kind-create   # Create local Kind cluster with MetalLB
make kind-setup    # Configure namespaces, RBAC, deploy MongoDB
make kind-deploy   # Build, load, and deploy all services
```

## Teardown

```bash
make kind-down     # Tear down the entire Kind cluster (alias for kind-destroy)
make kind-undeploy # Remove services but keep the cluster running
```

## CI/CD

- **ci.yml** -- `static-check` (composite quality gate), `build`, `test` (coverage), `cve-check` (OWASP, push-to-master + tag only), `image-scan` (per-service Trivy + Spring Boot smoke test on every push), `e2e` (Kind-based full stack on every push), `docker` (tag-gated, 4-service matrix with multi-arch + SLSA provenance + SBOM + cosign keyless signing), `ci-pass` (branch-protection aggregator)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 25, Spring Boot 4.0, Spring Cloud Kubernetes (2025.1)
- RestClient with @HttpExchange (inter-service communication)
- Micrometer Tracing (distributed trace propagation)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + MetalLB for local dev)
- MongoDB 8.0 (official `mongo` image, non-root UID 999, version-pinned for Renovate)
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks + Trivy + PlantUML drift check (static analysis composite gate via `make static-check`)

## Upgrade Backlog

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Drop `tools.jackson.core:jackson-core` override | Blocked on Spring Boot 4.0.6 | Module poms pin `tools.jackson.core:jackson-core:3.1.1` in `<dependencyManagement>` to fix **GHSA-2m67-wjpj-xhg9** (HIGH — Document length constraint bypass). Spring Boot 4.0.5 manages `jackson-core:3.1.0` which is vulnerable. Remove the override once SB 4.0.6 (or later) ships with 3.1.1 managed; Renovate should flag it via the Spring Boot group rule. Verify by running `mvn dependency:tree -Dincludes=tools.jackson.core:jackson-core` and confirming the natural version is ≥ 3.1.1. |
| 2 | `actions/cache` Node 20 deprecation (transitive via `sigstore/cosign-installer`) | Blocked on upstream | Node 20 hard-removed from GitHub Actions runners **2026-09-16**. The cache action is a transitive dep inside `sigstore/cosign-installer@v4.1.1` — we're already on latest. Renovate will ship the next cosign-installer release automatically. No manual action; track so it doesn't surprise us in Sept. |
| 3 | Add `integration-test` Maven profile + Makefile target + CI job | Pending | Multi-module Failsafe profile discovers `**/*IT.java`. Adds the middle layer between `make test` (unit) and `make e2e` (cluster). Currently `*ControllerTest.java` files are Testcontainers-backed integration tests running under Surefire — rename to `*IT.java` and route discovery to Failsafe. |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
