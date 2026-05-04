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
make integration-test  # Testcontainers + Failsafe **/*IT.java (tens of seconds)
make e2e               # Full Kind-cluster e2e via gateway LoadBalancer (minutes)
```

Granular alternatives (for debugging / partial workflows):

```bash
make kind-create   # Create local Kind cluster with cloud-provider-kind LoadBalancer controller
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
- Micrometer Tracing + OpenTelemetry OTLP exporter → Jaeger 2.x (OTel-Collector-based; in-cluster, `observability` namespace; UI exposed via LoadBalancer Service on :16686 — cloud-provider-kind allocates the IP, `make jaeger-open`)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + cloud-provider-kind for local dev — LoadBalancer Services resolve via the `kind` Docker network)
- MongoDB 8.0 (official `mongo` image, non-root UID 999, version-pinned for Renovate)
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks + Trivy + PlantUML drift check + `mermaid-cli` (Mermaid lint) (static analysis composite gate via `make static-check`)

## Upgrade Backlog

Each row carries an explicit **Revisit-if** list of observable conditions. When any trigger fires, the item is re-opened for evaluation — the deferral rationale is not self-refreshing, and the trigger column makes stale rationales detectable in seconds instead of months.

| # | Item | Status | Revisit-if (any trigger fires → re-open) | Notes |
|---|------|--------|-----------------------------------------|-------|
| 1 | Drop `tools.jackson.core:jackson-core` override | **Trigger fired (2026-05-01)** — ready to remove | SB 4.0.6 BOM ships `<jackson-bom.version>3.1.2</jackson-bom.version>`, identical to the override | Module poms pin `tools.jackson.core:jackson-core:3.1.2` in `<dependencyManagement>` to fix **GHSA-2m67-wjpj-xhg9** (HIGH — Document length constraint bypass). Verified via `repo1.maven.org/maven2/org/springframework/boot/spring-boot-dependencies/4.0.6/spring-boot-dependencies-4.0.6.pom`. Action: delete the `<dependency>` block from all 4 module poms; re-render `docs/diagrams/c4-container.puml` + `c4-deployment.puml` (patch version "4.0.5" appears in Container labels; run `make diagrams` and commit `docs/diagrams/out/`). |
| 1b | Drop `org.apache.tomcat.embed:tomcat-embed-core` override | **Trigger fired (2026-05-01)** — ready to remove | SB 4.0.6 BOM ships `<tomcat.version>11.0.21</tomcat.version>`, identical to the override | Module poms pin `tomcat-embed-core:11.0.21` to fix **CVE-2026-34483 / -34486 / -34487** (all HIGH). Verified via the same SB 4.0.6 BOM lookup. Paired with #1 — same PR removes both overrides and re-renders C4 diagrams. |
| 1c | Remove `continue-on-error: true` from `cve-check` job's OWASP step | Blocked on upstream fix (dependency-check/DependencyCheck#8424) | - `jeremylong/open-vulnerability-clients#106` closed<br>- OWASP Dependency-Check releases a version > `12.2.1`<br>- NVD rolls back the 9-digit nanosecond timestamp change (check https://nvd.nist.gov/vuln/data-feeds)<br>- A full CI run passes with `continue-on-error` removed locally | **2026-04-15**: NVD changed its API `timestamp` field from 6-digit microsecond to 9-digit nanosecond precision. ODC's Jackson `ZonedDateTime` deserializer in `CveApiJson20` can't parse the new format; every `cve-check` run fails with `DateTimeParseException: unparsed text found at index 23`. Affects ODC 12.2.0 and 12.2.1 (the latest). Upstream maintainer's quote: *"ODC will be broken when using the NVD API for ever"* until the upstream client library is fixed and a new ODC release ships it. Coverage is not lost in the interim — the `image-scan` job runs Trivy with CRITICAL/HIGH blocking on every push across the 4-service matrix, and it catches the same class of CVEs at the image layer (Trivy caught CVE-2026-34483/34486/34487 in tomcat-embed-core 11.0.20 during the ship-it pipeline that introduced this backlog entry). Remove the `continue-on-error: true` flag on the "Run OWASP dependency check" step in `.github/workflows/ci.yml` when any trigger fires. |
| 2 | `actions/cache` Node 20 deprecation (transitive via `sigstore/cosign-installer`) | Blocked on upstream | - `sigstore/cosign-installer` releases a version past `v4.1.1`<br>- Current date ≥ 2026-08-16 (one month before runner enforcement) and upstream still hasn't shipped | Node 20 hard-removed from GitHub Actions runners **2026-09-16**. The cache action is a transitive dep inside `sigstore/cosign-installer@v4.1.1` — we're already on latest. Renovate will ship the next cosign-installer release automatically. No manual action; track so it doesn't surprise us in Sept. |
| 3 | Java 25 → Java 29 LTS migration | Planned for Q3–Q4 2027 | - Java 29 GA announced (target 2027-09)<br>- Java 25 security backports end (earlier than Java 29 GA would be unusual but possible) | Java 25 is a non-LTS release (6-month support). Next LTS is **Java 29** (Sep 2027). No action needed now — Temurin 25 still receives security backports through its standard window, and the `eclipse-temurin:25.0.2_10-jre-noble@sha256:…` digest is re-pinned by Renovate when new patches ship. Plan the Java 29 bump when `.java-version`, parent pom `<java.version>`, the `java = "25"` pin in `.mise.toml`, and `JAVA_MAJOR` in the Makefile move together. |
| 4 | Spring Boot 4.0 → 4.1 migration | Planned for Q3 2026 | - Spring Boot 4.1 GA announced on https://spring.io/projects/spring-boot (`4.1.0-RC1` is on Maven Central as of 2026-05-01)<br>- Current date ≥ 2026-09-01 (≥ 4 months before EOL)<br>- Spring Boot 4.0 receives a final maintenance release | Spring Boot 4.0 line **EOL 2026-12-31**. Currently on `4.0.6` (latest patch). Track 4.1 GA via Renovate's Spring Boot group; when available, plan migration that updates parent pom version, audits any new deprecations, and re-renders C4 diagrams (Container labels reference `Spring Boot 4.0`). Major migration — read 4.0 → 4.1 release notes for binding changes before the bump. |
| 5 | MongoDB 8.2 → 8.0 LTS pin (or accept 8.x cadence) | Decision pending | - Current date ≥ 2026-07-01 (within 1 month of 8.2 EOL)<br>- Renovate opens a `mongo:8.3.x` PR (8.2 → 8.3 is a major-line bump, not patch) | `k8s/mongodb-deployment.yaml` pins `mongo:8.2.7@sha256:…`. The 8.2 line **EOLs 2026-07-31** (~3 months from 2026-05-01). Two paths: (a) re-pin to **`mongo:8.0`** LTS (EOL **2029-10-31**) — single Renovate group, less churn; (b) accept the 8.x quarterly-line cadence and let Renovate keep us current (more churn, always-near-EOL). Decision is style — both are safe. If (a), update Renovate to follow 8.0.* tags only. |
| 6 | `opentelemetry-semconv` 1.37.0 transitive CVEs (CVE-2026-29181, -39883, -39882) | Tracking — wait for Renovate | - Renovate bumps `micrometer-tracing-bridge-otel` (or its transitive `opentelemetry-semconv`) past 1.37.0 with the fixes<br>- Trivy/OWASP severity escalates to CRITICAL on subsequent scans (currently HIGH per `make ci` output) — pin override at that point | Surfaced by `make cve-check` 2026-05-03. `opentelemetry-semconv-1.37.0` is a transitive dep via `micrometer-tracing-bridge-otel`. No direct override possible without pinning the upstream `io.micrometer:micrometer-tracing-bridge-otel` version (which Spring Boot manages). Coverage at the image layer: `image-scan` job's Trivy CRITICAL/HIGH gate catches the same class of CVEs every push. Same deferral rationale as #1c — `cve-check` is `continue-on-error: true` while transitive fixes propagate from upstream. |
| 7 | `swagger-ui-5.32.2` bundled DOMPurify@3.3.2 CVEs (CVE-2026-41240, -41238, -41239, GHSA-39q2-94rc-95cp) | Tracking — wait for upstream | - `org.springdoc:springdoc-openapi-starter-webmvc-ui` releases a version past `3.0.3` (Renovate-tracked) with an updated `swagger-ui` bundle<br>- A user-facing XSS exploit is reported against an exposed Swagger UI on a public endpoint — escalate to immediate suppression / disable | Surfaced by `make cve-check` 2026-05-03. DOMPurify is a JS dep bundled inside the `swagger-ui-5.32.2.jar` static assets — NOT directly overridable via Maven `<dependencyManagement>` (the override would need to be on `springdoc-openapi-starter-webmvc-ui` itself, which is already pinned to the latest `3.0.3`). Risk is low for this project: Swagger UI is dev-facing, served only behind the gateway LoadBalancer on local KinD; not exposed publicly. Real fix lands when Springdoc bundles a newer swagger-ui (typically follows swagger-api/swagger-ui upstream within weeks). |
| 8 | OSS Index Analyzer auth migration to "Sonatype Guide" | Tracking — wait for upstream | - `org.owasp:dependency-check-maven` releases a version that supports Sonatype Guide auth (Renovate-tracked)<br>- The `[WARNING] Sonatype OSS Index Analyzer disabled due to missing credentials. Authentication with token is now required` message disappears from `make cve-check` output even with `OSS_INDEX_USER` + `OSS_INDEX_TOKEN` set | Surfaced by `make cve-check` 2026-05-03. Sonatype announced OSS Index migration to Sonatype Guide; the existing settings.xml `<server id="ossindex">` form may no longer match the new auth path. Coverage gap: while OSS Index Analyzer is disabled, OWASP relies on the NVD analyzer alone for CVE data — slightly weaker. NVD analyzer still runs (the `nvd` server entry from `maven-settings-ossindex` provides the API key via the safe `nvdApiServerId` pattern). Trivy image scan in `image-scan` job catches the gap at runtime. |
| 9 | `repo.spring.release` 401 on BouncyCastle metadata | Tracking — investigate when convenient | - The `[WARNING] Could not transfer metadata org.bouncycastle:bc{util,prov}-jdk18on/maven-metadata.xml ... status code: 401` warning disappears from `make ci` / `make e2e` output<br>- Spring's repository policy changes (gates `release` repo behind auth) | Surfaced repeatedly during `make ci` and `make e2e` 2026-05-03. Module poms include `<repository>repository.spring.release</repository>` (line 91-95 in gateway-service/pom.xml + others); BouncyCastle is on Maven Central but Maven tries Spring's `release` repo first per declaration order and gets 401. Possibly fixable by reordering so Maven Central is consulted first, or removing the Spring `release` repo if no Spring artefacts actually require it (Spring Boot 4.0.6 GA artefacts are on Maven Central; `release` repo is mainly for non-GA milestones). Cost of doing nothing: noisy build output (4× per `make ci`), no functional impact (Maven falls through to Central). |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
