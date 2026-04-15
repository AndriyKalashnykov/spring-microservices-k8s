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
make integration-test  # Testcontainers + Failsafe **/*IT.java (tens of seconds)
make e2e               # Full Kind-cluster e2e via gateway LoadBalancer (minutes)
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

- **ci.yml** -- `static-check` (composite quality gate incl. PlantUML `diagrams-check`), `build`, `test` (coverage), `integration-test` (Failsafe `**/*IT.java`), `cve-check` (OWASP, push-to-master + tag only), `image-scan` (per-service Trivy + Spring Boot smoke test on every push), `e2e` (Kind-based full stack on every push), `docker` (tag-gated, 4-service matrix with multi-arch + SLSA provenance + SBOM + cosign keyless signing), `ci-pass` (branch-protection aggregator)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 25, Spring Boot 4.0, Spring Cloud Kubernetes (2025.1)
- RestClient with @HttpExchange (inter-service communication)
- Micrometer Tracing + OpenTelemetry OTLP exporter → Jaeger all-in-one (in-cluster, `observability` namespace; UI exposed via MetalLB on :16686, `make jaeger-open`)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + MetalLB for local dev)
- MongoDB 8.0 (official `mongo` image, non-root UID 999, version-pinned for Renovate)
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks + Trivy + PlantUML drift check + `mermaid-cli` (Mermaid lint) (static analysis composite gate via `make static-check`)

## Upgrade Backlog

Each row carries an explicit **Revisit-if** list of observable conditions. When any trigger fires, the item is re-opened for evaluation — the deferral rationale is not self-refreshing, and the trigger column makes stale rationales detectable in seconds instead of months.

| # | Item | Status | Revisit-if (any trigger fires → re-open) | Notes |
|---|------|--------|-----------------------------------------|-------|
| 1 | Drop `tools.jackson.core:jackson-core` override | Blocked on Spring Boot 4.0.6 | `mvn dependency:tree -Dincludes=tools.jackson.core:jackson-core` shows natural version ≥ 3.1.1 (Renovate bumped Spring Boot) | Module poms pin `tools.jackson.core:jackson-core:3.1.2` in `<dependencyManagement>` to fix **GHSA-2m67-wjpj-xhg9** (HIGH — Document length constraint bypass). Spring Boot 4.0.5 manages `jackson-core:3.1.0` which is vulnerable. Remove the override once SB 4.0.6 (or later) ships with jackson-core ≥ 3.1.1 managed; Renovate should flag it via the Spring Boot group rule. |
| 1b | Drop `org.apache.tomcat.embed:tomcat-embed-core` override | Blocked on Spring Boot 4.0.6 | `mvn dependency:tree -Dincludes=org.apache.tomcat.embed:tomcat-embed-core` shows natural version ≥ 11.0.21 (Renovate bumped Spring Boot) | Module poms pin `tomcat-embed-core:11.0.21` in `<dependencyManagement>` to fix **CVE-2026-34483** (JsonAccessLogValve information disclosure), **CVE-2026-34486** (EncryptInterceptor missing encryption), and **CVE-2026-34487** (sensitive data in log files) — all HIGH. Spring Boot 4.0.5 manages `tomcat-embed-core:11.0.20` which is vulnerable. Remove the override once SB 4.0.6 (or later) ships with tomcat-embed-core ≥ 11.0.21 managed. |
| 1c | Remove `continue-on-error: true` from `cve-check` job's OWASP step | Blocked on upstream fix (dependency-check/DependencyCheck#8424) | - `jeremylong/open-vulnerability-clients#106` closed<br>- OWASP Dependency-Check releases a version > `12.2.1`<br>- NVD rolls back the 9-digit nanosecond timestamp change (check https://nvd.nist.gov/vuln/data-feeds)<br>- A full CI run passes with `continue-on-error` removed locally | **2026-04-15**: NVD changed its API `timestamp` field from 6-digit microsecond to 9-digit nanosecond precision. ODC's Jackson `ZonedDateTime` deserializer in `CveApiJson20` can't parse the new format; every `cve-check` run fails with `DateTimeParseException: unparsed text found at index 23`. Affects ODC 12.2.0 and 12.2.1 (the latest). Upstream maintainer's quote: *"ODC will be broken when using the NVD API for ever"* until the upstream client library is fixed and a new ODC release ships it. Coverage is not lost in the interim — the `image-scan` job runs Trivy with CRITICAL/HIGH blocking on every push across the 4-service matrix, and it catches the same class of CVEs at the image layer (Trivy caught CVE-2026-34483/34486/34487 in tomcat-embed-core 11.0.20 during the ship-it pipeline that introduced this backlog entry). Remove the `continue-on-error: true` flag on the "Run OWASP dependency check" step in `.github/workflows/ci.yml` when any trigger fires. |
| 2 | `actions/cache` Node 20 deprecation (transitive via `sigstore/cosign-installer`) | Blocked on upstream | - `sigstore/cosign-installer` releases a version past `v4.1.1`<br>- Current date ≥ 2026-08-16 (one month before runner enforcement) and upstream still hasn't shipped | Node 20 hard-removed from GitHub Actions runners **2026-09-16**. The cache action is a transitive dep inside `sigstore/cosign-installer@v4.1.1` — we're already on latest. Renovate will ship the next cosign-installer release automatically. No manual action; track so it doesn't surprise us in Sept. |
| 3 | Java 25 → Java 29 LTS migration | Planned for Q3–Q4 2027 | - Java 29 GA announced (target 2027-09)<br>- Java 25 security backports end (earlier than Java 29 GA would be unusual but possible) | Java 25 is a non-LTS release (6-month support). Next LTS is **Java 29** (Sep 2027). No action needed now — Temurin 25 still receives security backports through its standard window, and the `eclipse-temurin:25.0.2_10-jre-noble@sha256:…` digest is re-pinned by Renovate when new patches ship. Plan the Java 29 bump when `.java-version`, parent pom `<java.version>`, the `java = "25"` pin in `.mise.toml`, and `JAVA_MAJOR` in the Makefile move together. |
| 4 | Jaeger v1 → v2 migration | Deferred (topology change) | - Jaeger v2 reaches feature parity for all-in-one deployments (monitor release notes)<br>- Official Jaeger v2 migration guide published<br>- Jaeger v1.x line announces EOL date | Jaeger v2 stable line has shipped (v2.17.0 as of Mar 2026) but requires a topology change — the `jaegertracing/all-in-one` image is replaced by `jaegertracing/jaeger:` + OTel-collector-based configuration (YAML config file instead of env vars). Not a drop-in. Current pin: `jaegertracing/all-in-one:1.76.0` (v1.x line is still maintained as of this writing). Renovate is pinned to the 1.x line implicitly because it tracks the exact image; switching to v2 requires a manual k8s manifest rewrite (new image coordinate, new Service + ConfigMap, updated ports). Plan as a single PR: new deployment YAML, OTLP endpoint sanity check in all four services, e2e verification. |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
