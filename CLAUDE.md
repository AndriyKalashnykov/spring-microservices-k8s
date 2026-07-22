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
  k8s/                   # Kubernetes manifests, Kind configs
  e2e/                   # End-to-end test script
  docs/                  # Architecture documentation and diagrams
  Makefile               # Build orchestration (run `make help`)
  pom.xml                # Parent POM (multi-module)
  renovate.json          # Renovate dependency update configuration
```

## Build & Run

```bash
make build         # Build all modules
make kind-up       # Full cluster lifecycle: deps-kind + kind-create + cloud-provider-kind + kind-setup + image-build + kind-deploy
make populate      # Seed test data
make gateway-open  # Open Swagger UI
```

### Test Layers

```bash
make test              # Unit + in-process controller tests (Surefire, seconds)
make integration-test  # Testcontainers + WireMock + Failsafe **/*IT.java (tens of seconds)
make e2e               # Full Kind-cluster e2e via gateway LoadBalancer (minutes)
```

Granular alternatives (for debugging / partial workflows):

```bash
make kind-create   # Create local Kind cluster with cloud-provider-kind LoadBalancer controller
make kind-setup    # Configure namespaces, RBAC, deploy MongoDB
make kind-deploy   # Build, load, and deploy all services
```

### Doc Health

```bash
make check-readme-images  # Verify external README images (badges, star-history chart) resolve to an image/* body
```

`check-readme-images` is intentionally **manual-only** — not a `static-check`/CI prerequisite — because it hits external services (shields.io, star-history.com, hits.sh) that are transiently flaky and would redden unrelated PRs (same posture as `cve-check`). Run it on demand or after a push to confirm badges/charts render on github.com.

## Teardown

```bash
make kind-down     # Tear down the entire Kind cluster (alias for kind-destroy)
make kind-undeploy # Remove services but keep the cluster running
```

## CI/CD

- **ci.yml** -- `changes` (dorny/paths-filter gate that drives every downstream `needs:`/`if:`), `static-check` (composite quality gate incl. PlantUML `diagrams-check`), `build`, `test` (coverage), `integration-test` (Failsafe `**/*IT.java`), `cve-check` (OWASP, **tag pushes + dispatch only** — the weekly schedule was removed 2026-07-20; OFF the per-push path: slow NVD feed + `continue-on-error`, ALL dependency-CVE scanning is tag-time only as of 2026-07-20), `image-scan` (**tag-gated since 2026-07-20**; per-service Trivy + Spring Boot smoke test + container-structure-test — was ~50% of every push's billed minutes, and `e2e` already builds and boots all 4 images per push), `e2e` (Kind-based full stack on every push; builds + boots all 4 images, so it is the per-push image validation), `docker` (tag-gated, 4-service matrix with multi-arch + cosign keyless signing; **`needs:` `image-scan` AND `e2e`** so a CRITICAL finding or a failing e2e blocks the push — it did not until 2026-07-20; SLSA provenance + SBOM disabled until a downstream verifier exists), `ci-pass` (branch-protection aggregator)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 25 (LTS), Spring Boot 4.1, Spring Cloud Kubernetes (2025.1.2)
- RestClient with @HttpExchange (inter-service communication)
- Micrometer Tracing + OpenTelemetry OTLP exporter → Jaeger 2.19 (OTel-Collector-based; in-cluster, `observability` namespace; UI exposed via LoadBalancer Service on :16686 — cloud-provider-kind allocates the IP, `make jaeger-open`)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + cloud-provider-kind for local dev — LoadBalancer Services resolve via the `kind` Docker network)
- MongoDB 8.0 LTS (official `mongo` image, non-root UID 999, version-pinned for Renovate; 8.0 LTS line, EOL 2029-10-31)
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks + Trivy + PlantUML drift check + `mermaid-cli` (Mermaid lint) (static analysis composite gate via `make static-check`)

## Architecture Notes

- **C4 deployment diagram element budget**: `docs/diagrams/c4-deployment.puml` currently sits at 15 drawable boxes (host wrapper + cluster + 6 namespaces + 6 pods + `cloud-provider-kind`) — Simon Brown's soft cap for a single C4 view. Adding a 5th service tips it past the readable limit. The next service should drive a **view split** (e.g., move the `observability` namespace to its own diagram, or drop the host wrapper node) rather than packing more elements into the single deployment view.

## Upgrade Backlog → [`BACKLOG.md`](BACKLOG.md)

The upgrade backlog lives in **[`BACKLOG.md`](BACKLOG.md)**, which is *not* auto-loaded. It was
78% of this file (18,834 B) and it is task state, not instructions — and this file is paid on
every session and every subagent dispatch. Open it when you pick up upgrade work.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
