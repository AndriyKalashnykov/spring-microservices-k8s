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

## Teardown

```bash
make kind-down     # Tear down the entire Kind cluster (alias for kind-destroy)
make kind-undeploy # Remove services but keep the cluster running
```

## CI/CD

- **ci.yml** -- `static-check` (composite quality gate incl. PlantUML `diagrams-check`), `build`, `test` (coverage), `integration-test` (Failsafe `**/*IT.java`), `cve-check` (OWASP, push-to-master + tag only), `image-scan` (per-service Trivy + Spring Boot smoke test on every push), `e2e` (Kind-based full stack on every push), `docker` (tag-gated, 4-service matrix with multi-arch + SLSA provenance + SBOM + cosign keyless signing), `ci-pass` (branch-protection aggregator)
- **cleanup-runs.yml** -- weekly cleanup of old workflow runs

## Tech Stack

- Java 25 (LTS), Spring Boot 4.0, Spring Cloud Kubernetes (2025.1.1)
- RestClient with @HttpExchange (inter-service communication)
- Micrometer Tracing + OpenTelemetry OTLP exporter → Jaeger 2.18 (OTel-Collector-based; in-cluster, `observability` namespace; UI exposed via LoadBalancer Service on :16686 — cloud-provider-kind allocates the IP, `make jaeger-open`)
- Maven multi-module build
- Docker (multi-arch via buildx)
- Kubernetes (Kind + cloud-provider-kind for local dev — LoadBalancer Services resolve via the `kind` Docker network)
- MongoDB 8.3 (official `mongo` image, non-root UID 999, version-pinned for Renovate)
- Testcontainers (integration tests)
- Checkstyle + hadolint + gitleaks + Trivy + PlantUML drift check + `mermaid-cli` (Mermaid lint) (static analysis composite gate via `make static-check`)

## Architecture Notes

- **C4 deployment diagram element budget**: `docs/diagrams/c4-deployment.puml` currently sits at 15 drawable boxes (host wrapper + cluster + 6 namespaces + 6 pods + `cloud-provider-kind`) — Simon Brown's soft cap for a single C4 view. Adding a 5th service tips it past the readable limit. The next service should drive a **view split** (e.g., move the `observability` namespace to its own diagram, or drop the host wrapper node) rather than packing more elements into the single deployment view.

## Upgrade Backlog

Each row carries an explicit **Revisit-if** list of observable conditions. When any trigger fires, the item is re-opened for evaluation — the deferral rationale is not self-refreshing, and the trigger column makes stale rationales detectable in seconds instead of months.

| # | Item | Status | Revisit-if (any trigger fires → re-open) | Notes |
|---|------|--------|-----------------------------------------|-------|
| 1 | Drop `tools.jackson.core:jackson-core` override | Re-verify before removal — override drifted past the BOM-parity claim | SB 4.0.6 BOM's `<jackson-bom.version>` is confirmed ≥ `3.1.3` — verify via `repo1.maven.org/maven2/org/springframework/boot/spring-boot-dependencies/4.0.6/spring-boot-dependencies-4.0.6.pom` | Module poms pin `tools.jackson.core:jackson-core:3.1.3` in `<dependencyManagement>` to fix **GHSA-2m67-wjpj-xhg9** (HIGH — Document length constraint bypass). Renovate has bumped the override past the original `3.1.1` fix floor, so the earlier "BOM ships an identical version" rationale no longer holds — re-confirm the SB 4.0.6 BOM ships ≥ `3.1.3` before deleting the `<dependency>` block from all 4 module poms. |
| 1b | Drop `org.apache.tomcat.embed:tomcat-embed-core` override | Re-verify before removal — override drifted past the BOM-parity claim | SB 4.0.6 BOM's `<tomcat.version>` is confirmed ≥ `11.0.22` — verify via the same SB 4.0.6 BOM lookup | Module poms pin `tomcat-embed-core:11.0.22` to fix **CVE-2026-34483 / -34486 / -34487** (all HIGH). Renovate has bumped the override past the original `11.0.21` fix floor; re-confirm the SB 4.0.6 BOM ships ≥ `11.0.22` before deleting. Paired with #1 — same PR removes both overrides. |
| 1d | Drop `org.bouncycastle:bcpkix/bcutil/bcprov-jdk18on` override | Blocked on upstream — wait for `io.kubernetes:client-java` | `io.kubernetes:client-java` (transitive via `spring-cloud-starter-kubernetes-client-all`) ships a release that pulls BouncyCastle ≥ `1.84` | Module poms pin `bcpkix-jdk18on` / `bcutil-jdk18on` / `bcprov-jdk18on` to `1.84` in `<dependencyManagement>` to fix **CVE-2026-5598** (HIGH — BC-JAVA private key leakage via a non-constant-time operation), pulled in transitively (affected up to and including `1.80`; PR #54, merged 2026-05-07). Renovate's `BouncyCastle` group keeps the three artifacts on the same version. Remove the override block from all 4 module poms once `client-java` pulls `1.84+` directly. |
| 1c | Remove `continue-on-error: true` from `cve-check` job's OWASP step | Blocked on upstream fix (dependency-check/DependencyCheck#8424) | - `jeremylong/open-vulnerability-clients#106` closed<br>- OWASP Dependency-Check releases a version > `12.2.2`<br>- NVD rolls back the 9-digit nanosecond timestamp change (check https://nvd.nist.gov/vuln/data-feeds)<br>- A full CI run passes with `continue-on-error` removed locally | **2026-04-15**: NVD changed its API `timestamp` field from 6-digit microsecond to 9-digit nanosecond precision. ODC's Jackson `ZonedDateTime` deserializer in `CveApiJson20` can't parse the new format; every `cve-check` run fails with `DateTimeParseException: unparsed text found at index 23`. Affects ODC 12.2.0 through 12.2.2 (the parent pom currently pins `12.2.2`; the `continue-on-error` flag is still required, so 12.2.2 did not fix the parser). Upstream maintainer's quote: *"ODC will be broken when using the NVD API for ever"* until the upstream client library is fixed and a new ODC release ships it. Coverage is not lost in the interim — the `image-scan` job runs Trivy with CRITICAL/HIGH blocking on every push across the 4-service matrix, and it catches the same class of CVEs at the image layer (Trivy caught CVE-2026-34483/34486/34487 in tomcat-embed-core 11.0.20 during the ship-it pipeline that introduced this backlog entry). Remove the `continue-on-error: true` flag on the "Run OWASP dependency check" step in `.github/workflows/ci.yml` when any trigger fires. |
| 2 | `actions/cache` Node 20 deprecation (transitive via `sigstore/cosign-installer`) | Blocked on upstream | - `sigstore/cosign-installer` releases a version past `v4.1.2`<br>- Current date ≥ 2026-08-16 (one month before runner enforcement) and upstream still hasn't shipped | Node 20 hard-removed from GitHub Actions runners **2026-09-16**. The cache action is a transitive dep inside `sigstore/cosign-installer` — ci.yml now pins `v4.1.2` (Renovate bumped it from v4.1.1). Re-check whether `v4.1.2` still bundles the Node-20 `actions/cache`; if it does, this stays a wait-for-upstream item. Renovate ships each new cosign-installer release automatically. Track so it doesn't surprise us before the 2026-09-16 enforcement. |
| 3 | Java 25 → Java 29 LTS migration | Optional — Java 25 is LTS, no forced deadline; revisit ~Q4 2027 | - Java 29 GA announced (target 2027-09)<br>- A Java 29 language/API feature the project wants becomes compelling | Java 25 is a **Long-Term-Support release** (Oracle/Temurin moved to a 2-year LTS cadence: 17, 21, 25, 29 — Java 25 is supported into 2033). This migration is therefore a "move to the next LTS when convenient", not a deadline. Temurin 25 receives security backports for years; the `eclipse-temurin:25.0.3_9-jre-noble@sha256:…` digest is re-pinned by Renovate when new patches ship. Plan the Java 29 bump when `.java-version`, each module pom's `<java.version>` (the parent `pom.xml` has no such property — each of the 4 module poms carries its own), the `java = "25"` pin in `.mise.toml`, and `JAVA_MAJOR` in the Makefile move together. |
| 4 | Spring Boot 4.0 → 4.1 migration | Planned for Q3 2026 | - Spring Boot 4.1 GA announced on https://spring.io/projects/spring-boot (`4.1.0-RC1` is on Maven Central as of 2026-05-01)<br>- Current date ≥ 2026-09-01 (≥ 4 months before EOL)<br>- Spring Boot 4.0 receives a final maintenance release | Spring Boot 4.0 line **EOL 2026-12-31**. Currently on `4.0.6` (latest patch). Track 4.1 GA via Renovate's Spring Boot group; when available, plan migration that updates parent pom version, audits any new deprecations, and re-renders C4 diagrams (Container labels reference `Spring Boot 4.0`). Major migration — read 4.0 → 4.1 release notes for binding changes before the bump. |
| 5 | MongoDB 8.x cadence — pin `mongo:8.0` LTS or keep riding the quarterly line | Decision pending | - Renovate opens a `mongo:8.4.x` PR (next quarterly-line bump)<br>- The current `8.3` line nears its EOL | `k8s/mongodb-deployment.yaml` now pins `mongo:8.3.2@sha256:…` — Renovate has already moved it 8.2.7 → 8.3.1 → 8.3.2, so the earlier "8.2 → 8.3 bump" trigger has fired. MongoDB quarterly "rapid release" lines are short-lived; **`mongo:8.0`** is the LTS line (EOL **2029-10-31**). Two paths: (a) re-pin to `mongo:8.0` LTS — less churn, always supported (then update Renovate to follow `8.0.*` only); (b) keep accepting the 8.x quarterly cadence and let Renovate keep us current (more churn, always near a line EOL). Decision is style — both are safe. The `MongoDB` Renovate group (added 2026-05-22) now lands the manifest + Testcontainers + docs bumps in one PR. |
| 6 | `opentelemetry-semconv` 1.37.0 transitive CVEs (CVE-2026-29181, -39883, -39882) | Tracking — wait for Renovate | - Renovate bumps `micrometer-tracing-bridge-otel` (or its transitive `opentelemetry-semconv`) past 1.37.0 with the fixes<br>- Trivy/OWASP severity escalates to CRITICAL on subsequent scans (currently HIGH per `make ci` output) — pin override at that point | Surfaced by `make cve-check` 2026-05-03. `opentelemetry-semconv-1.37.0` is a transitive dep via `micrometer-tracing-bridge-otel`. No direct override possible without pinning the upstream `io.micrometer:micrometer-tracing-bridge-otel` version (which Spring Boot manages). Coverage at the image layer: `image-scan` job's Trivy CRITICAL/HIGH gate catches the same class of CVEs every push. Same deferral rationale as #1c — `cve-check` is `continue-on-error: true` while transitive fixes propagate from upstream. |
| 7 | `swagger-ui-5.32.2` bundled DOMPurify@3.3.2 CVEs (CVE-2026-41240, -41238, -41239, GHSA-39q2-94rc-95cp) | Tracking — wait for upstream | - `org.springdoc:springdoc-openapi-starter-webmvc-ui` releases a version past `3.0.3` (Renovate-tracked) with an updated `swagger-ui` bundle<br>- A user-facing XSS exploit is reported against an exposed Swagger UI on a public endpoint — escalate to immediate suppression / disable | Surfaced by `make cve-check` 2026-05-03. DOMPurify is a JS dep bundled inside the `swagger-ui-5.32.2.jar` static assets — NOT directly overridable via Maven `<dependencyManagement>` (the override would need to be on `springdoc-openapi-starter-webmvc-ui` itself, which is already pinned to the latest `3.0.3`). Risk is low for this project: Swagger UI is dev-facing, served only behind the gateway LoadBalancer on local KinD; not exposed publicly. Real fix lands when Springdoc bundles a newer swagger-ui (typically follows swagger-api/swagger-ui upstream within weeks). |
| 8 | OSS Index Analyzer auth migration to "Sonatype Guide" | Tracking — wait for upstream | - `org.owasp:dependency-check-maven` releases a version that supports Sonatype Guide auth (Renovate-tracked)<br>- The `[WARNING] Sonatype OSS Index Analyzer disabled due to missing credentials. Authentication with token is now required` message disappears from `make cve-check` output even with `OSS_INDEX_USER` + `OSS_INDEX_TOKEN` set | Surfaced by `make cve-check` 2026-05-03. Sonatype announced OSS Index migration to Sonatype Guide; the existing settings.xml `<server id="ossindex">` form may no longer match the new auth path. Coverage gap: while OSS Index Analyzer is disabled, OWASP relies on the NVD analyzer alone for CVE data — slightly weaker. NVD analyzer still runs (the `nvd` server entry from `maven-settings-ossindex` provides the API key via the safe `nvdApiServerId` pattern). Trivy image scan in `image-scan` job catches the gap at runtime. |
| 9 | `repo.spring.release` 401 on BouncyCastle metadata | Tracking — investigate when convenient | - The `[WARNING] Could not transfer metadata org.bouncycastle:bc{util,prov}-jdk18on/maven-metadata.xml ... status code: 401` warning disappears from `make ci` / `make e2e` output<br>- Spring's repository policy changes (gates `release` repo behind auth) | Surfaced repeatedly during `make ci` and `make e2e` 2026-05-03. Module poms include a `<repository>repository.spring.release</repository>` block; BouncyCastle is on Maven Central but Maven tries Spring's `release` repo first per declaration order and gets 401. Possibly fixable by reordering so Maven Central is consulted first, or removing the Spring `release` repo if no Spring artefacts actually require it (Spring Boot 4.0.6 GA artefacts are on Maven Central; `release` repo is mainly for non-GA milestones). Cost of doing nothing: noisy build output (4× per `make ci`), no functional impact (Maven falls through to Central). |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
