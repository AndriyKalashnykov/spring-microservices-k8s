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

- **ci.yml** -- `changes` (dorny/paths-filter gate that drives every downstream `needs:`/`if:`), `static-check` (composite quality gate incl. PlantUML `diagrams-check`), `build`, `test` (coverage), `integration-test` (Failsafe `**/*IT.java`), `cve-check` (OWASP, **tag pushes + dispatch only** — the weekly schedule was removed 2026-07-20; OFF the per-push path: slow NVD feed + `continue-on-error`, per-push dep-CVE coverage is Trivy `trivy-fs` inside `static-check`), `image-scan` (**tag-gated since 2026-07-20**; per-service Trivy + Spring Boot smoke test + container-structure-test — was ~50% of every push's billed minutes, and `e2e` already builds and boots all 4 images per push), `e2e` (Kind-based full stack on every push), `docker` (tag-gated, 4-service matrix with multi-arch + cosign keyless signing; **`needs:` `image-scan`** so a CRITICAL finding blocks the push — it did not until 2026-07-20; SLSA provenance + SBOM disabled until a downstream verifier exists), `ci-pass` (branch-protection aggregator)
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

## Upgrade Backlog

Each row carries an explicit **Revisit-if** list of observable conditions. When any trigger fires, the item is re-opened for evaluation — the deferral rationale is not self-refreshing, and the trigger column makes stale rationales detectable in seconds instead of months.

| # | Item | Status | Revisit-if (any trigger fires → re-open) | Notes |
|---|------|--------|-----------------------------------------|-------|
| 1c | Remove `continue-on-error: true` from `cve-check` job's OWASP step | Blocked on upstream fix (dependency-check/DependencyCheck#8424) | - `jeremylong/open-vulnerability-clients#106` closed<br>- OWASP Dependency-Check releases a version > `12.2.2`<br>- NVD rolls back the 9-digit nanosecond timestamp change (check https://nvd.nist.gov/vuln/data-feeds)<br>- A full CI run passes with `continue-on-error` removed locally<br>- **`cve-check` emits the `OWASP scan incomplete` `::warning::` on 2+ consecutive weekly runs** — the job is then GREEN while providing zero coverage (the step cap absorbs the timeout by design); at that point the NVD download is permanently too slow and the job needs re-scoping, not a bigger budget | **2026-04-15**: NVD changed its API `timestamp` field from 6-digit microsecond to 9-digit nanosecond precision. ODC's Jackson `ZonedDateTime` deserializer in `CveApiJson20` can't parse the new format; every `cve-check` run fails with `DateTimeParseException: unparsed text found at index 23`. Affects ODC 12.2.0 through 12.2.2 (the parent pom currently pins `12.2.2`; the `continue-on-error` flag is still required, so 12.2.2 did not fix the parser). Upstream maintainer's quote: *"ODC will be broken when using the NVD API for ever"* until the upstream client library is fixed and a new ODC release ships it. Coverage is not lost in the interim — `trivy-fs` (inside `static-check`) blocks on CRITICAL/HIGH dependency CVEs on **every push**, and `image-scan` blocks at **tag** time across the 4-service matrix, catching the same class at the image layer (Trivy caught CVE-2026-34483/34486/34487 in tomcat-embed-core 11.0.20 during the ship-it pipeline that introduced this backlog entry). Remove the `continue-on-error: true` flag on the "Run OWASP dependency check" step in `.github/workflows/ci.yml` when any trigger fires. **2026-07-20**: the step also gained `timeout-minutes: 35` — a *job*-level timeout reports `cancelled`, which `continue-on-error` does NOT absorb and `ci-pass` explicitly fails on, so a slow NVD feed was reddening otherwise-green weekly runs. |
| 1d | Drop `org.bouncycastle:bcpkix/bcutil/bcprov-jdk18on` override | Blocked on upstream — wait for `io.kubernetes:client-java` | `io.kubernetes:client-java` (transitive via `spring-cloud-starter-kubernetes-client-all`) ships a release that pulls BouncyCastle ≥ `1.84` | Module poms pin `bcpkix-jdk18on` / `bcutil-jdk18on` / `bcprov-jdk18on` to `1.84` in `<dependencyManagement>` to fix **CVE-2026-5598** (HIGH — BC-JAVA private key leakage via a non-constant-time operation), pulled in transitively (affected up to and including `1.80`; PR #54, merged 2026-05-07). Renovate's `BouncyCastle` group keeps the three artifacts on the same version. Remove the override block from all 4 module poms once `client-java` pulls `1.84+` directly. |
| 3 | Java 25 → Java 29 LTS migration | Optional — Java 25 is LTS, no forced deadline; revisit ~Q4 2027 | - Java 29 GA announced (target 2027-09)<br>- A Java 29 language/API feature the project wants becomes compelling | Java 25 is a **Long-Term-Support release** (Oracle/Temurin moved to a 2-year LTS cadence: 17, 21, 25, 29 — Java 25 is supported into 2033). This migration is therefore a "move to the next LTS when convenient", not a deadline. Temurin 25 receives security backports for years; the `eclipse-temurin:25.0.3_9-jre-noble@sha256:…` digest is re-pinned by Renovate when new patches ship. Plan the Java 29 bump when `.java-version`, each module pom's `<java.version>` (the parent `pom.xml` has no such property — each of the 4 module poms carries its own), the `java = "25"` pin in `.mise.toml`, and `JAVA_MAJOR` in the Makefile move together. |
| 6 | `opentelemetry-semconv` 1.37.0 transitive CVEs (CVE-2026-29181, -39883, -39882) | Tracking — wait for Renovate | - Renovate bumps `micrometer-tracing-bridge-otel` (or its transitive `opentelemetry-semconv`) past 1.37.0 with the fixes<br>- Trivy/OWASP severity escalates to CRITICAL on subsequent scans (currently HIGH per `make ci` output) — pin override at that point | Surfaced by `make cve-check` 2026-05-03. `opentelemetry-semconv-1.37.0` is a transitive dep via `micrometer-tracing-bridge-otel`. No direct override possible without pinning the upstream `io.micrometer:micrometer-tracing-bridge-otel` version (which Spring Boot manages). Coverage: `trivy-fs` (in `static-check`) blocks on this class every push; `image-scan`'s Trivy gate catches it at the image layer at tag time. Same deferral rationale as #1c — `cve-check` is `continue-on-error: true` while transitive fixes propagate from upstream. |
| 7 | `swagger-ui-5.32.2` bundled DOMPurify@3.3.2 CVEs (CVE-2026-41240, -41238, -41239, GHSA-39q2-94rc-95cp) | Tracking — wait for upstream | - `org.springdoc:springdoc-openapi-starter-webmvc-ui` releases a version past `3.0.3` (Renovate-tracked) with an updated `swagger-ui` bundle<br>- A user-facing XSS exploit is reported against an exposed Swagger UI on a public endpoint — escalate to immediate suppression / disable | Surfaced by `make cve-check` 2026-05-03. DOMPurify is a JS dep bundled inside the `swagger-ui-5.32.2.jar` static assets — NOT directly overridable via Maven `<dependencyManagement>` (the override would need to be on `springdoc-openapi-starter-webmvc-ui` itself, which is already pinned to the latest `3.0.3`). Risk is low for this project: Swagger UI is dev-facing, served only behind the gateway LoadBalancer on local KinD; not exposed publicly. Real fix lands when Springdoc bundles a newer swagger-ui (typically follows swagger-api/swagger-ui upstream within weeks). |
| 8 | OSS Index Analyzer auth migration to "Sonatype Guide" | Tracking — wait for upstream | - `org.owasp:dependency-check-maven` releases a version that supports Sonatype Guide auth (Renovate-tracked)<br>- The `[WARNING] Sonatype OSS Index Analyzer disabled due to missing credentials. Authentication with token is now required` message disappears from `make cve-check` output even with `OSS_INDEX_USER` + `OSS_INDEX_TOKEN` set | Surfaced by `make cve-check` 2026-05-03. Sonatype announced OSS Index migration to Sonatype Guide; the existing settings.xml `<server id="ossindex">` form may no longer match the new auth path. Coverage gap: while OSS Index Analyzer is disabled, OWASP relies on the NVD analyzer alone for CVE data — slightly weaker. NVD analyzer still runs (the `nvd` server entry from `maven-settings-ossindex` provides the API key via the safe `nvdApiServerId` pattern). `trivy-fs` covers the dependency layer every push, and the `image-scan` Trivy scan covers the image layer at tag time. |
| 9 | `repo.spring.release` 401 on BouncyCastle metadata | Tracking — investigate when convenient | - The `[WARNING] Could not transfer metadata org.bouncycastle:bc{util,prov}-jdk18on/maven-metadata.xml ... status code: 401` warning disappears from `make ci` / `make e2e` output<br>- Spring's repository policy changes (gates `release` repo behind auth) | Surfaced repeatedly during `make ci` and `make e2e` 2026-05-03. Module poms include a `<repository>repository.spring.release</repository>` block; BouncyCastle is on Maven Central but Maven tries Spring's `release` repo first per declaration order and gets 401. Possibly fixable by reordering so Maven Central is consulted first, or removing the Spring `release` repo if no Spring artefacts actually require it (Spring Boot 4.1.0 GA artefacts are on Maven Central; `release` repo is mainly for non-GA milestones). Cost of doing nothing: noisy build output (4× per `make ci`), no functional impact (Maven falls through to Central). |
| 11 | `make ci-run` (act) reproducibility — `-P` platform mapping + per-job serialization | Deferred — needs local `act` testing by maintainer | - You run `make ci-run` and it uses a wrong/default runner image (Maven/mise steps fail)<br>- A `~/.actrc` is the only thing making `ci-run` work today (non-reproducible) | Surfaced by the 2026-06-14 `/ship-it` Makefile review. `ci-run` invokes `act push` with **no `-P ubuntu-latest=catthehacker/ubuntu:<tag>` mapping** (the workflow is `runs-on: ubuntu-latest`); reproducibility relies on the maintainer's global `act` config. The portfolio convention is a Renovate-tracked `ACT_UBUNTU_VERSION := act-24.04` (`# renovate: datasource=docker depName=catthehacker/ubuntu versioning=loose`) + `--platform ubuntu-latest=catthehacker/ubuntu:$(ACT_UBUNTU_VERSION)`. **NOT applied this session** because it interacts with the existing `--pull=false` flag (the catthehacker image must be pre-pulled or `--pull=false` dropped) and `ci-run` can't be verified in this environment — apply + test locally. `GITHUB_TOKEN` forwarding to `act` (mise rate-limit guard) WAS added. Also deferred (MEDIUM): swap the 4 `upload-artifact` steps' `continue-on-error: true` for `if: ${{ always() && vars.ACT != 'true' }}` so genuine upload failures hard-fail on real runners while still skipping under act. |
| 14 | Weekly `schedule` trigger removed — `cve-check` is now tag+dispatch only, and its NVD cache will be COLD at every tag | Accepted trade (2026-07-20); **re-open together with #1c** | - #1c's upstream fix lands (ODC parses NVD again) — at which point cve-check produces real findings and the cold-cache problem below starts to matter<br>- A CVE lands on an unchanged dependency during a quiet period and is missed until the next tag<br>- You want the between-release safety net back (restore `schedule:` in `on:` **and** the `schedule` arm of cve-check's `if:` — both were removed) | **2026-07-20**: `cve-check` was the `schedule` trigger's ONLY consumer, so every Monday the full pipeline ran (~20 billed min) to reach one advisory job that is broken upstream (#1c) and was timing out (45m16s → `cancelled` → red master). Removed. **Second-order consequence, recorded because it is not obvious:** GitHub evicts caches unused for 7 days, so with no weekly run the ~2 GB NVD DB is cold at every tag — a full download that will likely exceed the step's 35-min cap, leaving `cve-check` green-but-empty (it emits the `OWASP scan incomplete` warning). That is harmless *today* (ODC produces nothing anyway) but means **fixing #1c alone will NOT restore working coverage** — the cache lifetime has to be solved too (restore the schedule, or seed the DB at tag time). Per-push dependency-CVE coverage meanwhile is `trivy-fs`, which blocks on CRITICAL/HIGH against a continuously-updated Trivy DB. |
| 13 | `image-scan` moved to tag-only — image CVE + Dockerfile-contract checks now shift right to release time | Accepted trade (2026-07-20) | - A Dockerfile / base-image / image-CVE defect reaches a tag that a per-push `image-scan` would have caught (i.e. you are debugging it mid-release)<br>- `trivy-fs`'s package-count floor starts firing spuriously, weakening the per-push dependency-CVE gate it now solely provides<br>- Billed CI minutes stop being a constraint | **2026-07-20**: `image-scan` (4-service matrix: docker build + Trivy + smoke test + container-structure-test) was ~9m55s of ~20m billed minutes on **every** push. Its build-and-boot half is duplicated by `e2e`, which already builds all 4 images and runs them in KinD per push — so tag-gating loses no "does it work" coverage. What it *does* shift right: the **Trivy image scan** (base-image CVEs, which `trivy-fs` cannot see — it scans poms, not the runtime image) and **container-structure-test** (non-root USER, EXPOSE, WORKDIR, ENTRYPOINT). Made safe by adding `image-scan` to the `docker` job's `needs:` in the same change — the two previously ran in **parallel** on a tag, so a CRITICAL finding failed the run only *after* the image was pushed to GHCR and cosign-signed. If per-push image coverage is wanted back cheaply, the middle option is a per-service paths-filter (scan only services whose files changed) rather than reverting to all-4-every-push. **Verification status (stated because a green is not a proof):** the `docker`→`image-scan` dependency is verified **structurally** — `actionlint` validates the job reference, `needs:` is core Actions semantics, and `if: !failure()` is used identically by every other job here — but it has **NOT** been proven behaviourally, because doing so requires a tag run and the `docker` job sets `flavor: latest=true`, so a throwaway tag would move `latest` for all 4 services (published public GHCR versions are hard to delete). **The next genuine `vX.Y.Z` release is the proof**: confirm `docker` starts only after all four `image-scan` matrix legs report success, and record it here. Until then, treat "a CRITICAL finding blocks the release" as designed-and-reviewed, not demonstrated. |
| 12 | `container-structure-test` Docker image frozen at `v1.16.0` (image-only pin; binary releases continue to 1.22.x) | Tracking — pinned to the real published image max | - You need a container-structure-test feature/fix only in a release > `1.16` (the standalone binaries reach `1.22.x`)<br>- `gcr.io/gcp-runtimes/container-structure-test` resumes publishing tags above `v1.16.0` (Renovate's `docker` datasource will surface it automatically) | **2026-06-24** (`/find-fix failing PR` session): upstream FROZE the Docker image — *"Container builds are currently not updated with new releases"* ([README](https://github.com/GoogleContainerTools/container-structure-test)) — so `gcr.io/gcp-runtimes/container-structure-test` tops out at `v1.16.0` while the GitHub **binary** releases continue (`1.22.1`). The Makefile var AND the `ci.yml` image-scan literal both consume the **image**, so both are pinned to `1.16.0` and tracked via `datasource=docker` (the registry), NOT `github-releases` (which had bumped the Makefile var to `1.22.1` — a tag that does not exist as an image, silently breaking `make container-structure-test`; CI was unaffected only because it hardcoded `v1.16.0`). `v1.16.0`'s OCI-contract checks (non-root USER, EXPOSE, WORKDIR, ENTRYPOINT) are stable and sufficient. To get a newer CST, migrate both call sites from the frozen image to the binary-download path (download the `container-structure-test-linux-amd64` release asset + `chmod +x`); keep `datasource=github-releases` only if you make that migration. |

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
