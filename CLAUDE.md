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
- Checkstyle + hadolint + gitleaks + Trivy + mermaid-cli (static analysis composite gate via `make static-check`)

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.

## Upgrade Backlog

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Drop `tools.jackson.core:jackson-core` override | Blocked on Spring Boot 4.0.6 | Module poms pin `tools.jackson.core:jackson-core:3.1.1` in `<dependencyManagement>` to fix **GHSA-2m67-wjpj-xhg9** (HIGH — Document length constraint bypass). Spring Boot 4.0.5 manages `jackson-core:3.1.0` which is vulnerable. Remove the override once SB 4.0.6 (or later) ships with 3.1.1 managed; Renovate should flag it via the Spring Boot group rule. Verify by running `mvn dependency:tree -Dincludes=tools.jackson.core:jackson-core` and confirming the natural version is ≥ 3.1.1. |
| 2 | `actions/cache` Node 20 deprecation (transitive via `sigstore/cosign-installer`) | Blocked on upstream | Node 20 hard-removed from GitHub Actions runners **2026-09-16**. The cache action is a transitive dep inside `sigstore/cosign-installer@v4.1.1` — we're already on latest. Renovate will ship the next cosign-installer release automatically. No manual action; track so it doesn't surprise us in Sept. |
| 2 | Pin Kind node image in `k8s/kind-config.yaml` | Nice-to-have | `kind-config.yaml` has no `image:` field, so Kind 0.31.0 uses its default K8s version (~1.32, EOL 2026-02-28 per endoflife.date). For reproducible e2e, add explicit `image: kindest/node:v1.34.x@sha256:…` when a matching Kind release is published. Local-dev only, not production. |
| 3 | Observability bridge: Brave → OpenTelemetry | Optional | Project uses `micrometer-tracing-bridge-brave` (Zipkin backend). OTel is the industry-standard consolidation target. Evaluate as part of an observability backend decision. |
| 4 | Consolidate MongoDB version pin | Nice-to-have | `mongo:8.0.20` is pinned in 5 places (`k8s/mongodb-deployment.yaml`, `docs/reference-architecture.md`, 3 × `*ControllerTest.java`). Renovate custom manager tracks all 5, but the `**/*ControllerTest.java` glob silently drops entries if a test file is renamed. Consider a single `MONGODB_VERSION := 8.0.20` Makefile constant referenced everywhere. |
