[![CI](https://github.com/AndriyKalashnykov/spring-microservices-k8s/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/AndriyKalashnykov/spring-microservices-k8s/actions/workflows/ci.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/spring-microservices-k8s.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/spring-microservices-k8s/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/spring-microservices-k8s)

# Java Microservices with Spring Boot and Spring Cloud Kubernetes

This reference architecture demonstrates design, development, and deployment of Spring Boot microservices on Kubernetes. It implements a hierarchical domain model (Organization > Department > Employee) with four services deployed across isolated namespaces, using Spring Cloud Kubernetes for service discovery, configuration, and secrets management.

| Component | Technology |
|-----------|-----------|
| Language | Java 25 |
| Framework | Spring Boot 3.5, Spring Cloud 2025.0 |
| API Gateway | Spring Cloud Gateway MVC |
| Inter-service | RestClient with `@HttpExchange` |
| Service Discovery | Spring Cloud Kubernetes |
| Database | MongoDB 8.0 (official `mongo` image, non-root UID 999, version-pinned) |
| API Docs | SpringDoc OpenAPI 2.8 / Swagger UI |
| Tracing | Micrometer Tracing (Brave) |
| Testing | Testcontainers (integration), Kind e2e |
| Containers | Eclipse Temurin 25, multi-arch (amd64+arm64) |
| Local K8s | Kind + MetalLB |
| CI/CD | GitHub Actions, Renovate, GHCR |
| Code Quality | Google Java Format, Checkstyle, hadolint, gitleaks, Trivy |

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'primaryColor': '#1e40af',
  'primaryTextColor': '#ffffff',
  'primaryBorderColor': '#1e3a5f',
  'lineColor': '#3b82f6',
  'secondaryColor': '#dbeafe',
  'tertiaryColor': '#f0f9ff',
  'fontFamily': 'arial'
}}}%%
graph TB
    Client([👤 Client]):::client --> Gateway[🌐 Gateway Service<br/>Spring Cloud Gateway MVC<br/>LoadBalancer via MetalLB]

    Gateway -->|/employee/**| Employee[👤 Employee Service]
    Gateway -->|/department/**| Department[🏢 Department Service]
    Gateway -->|/organization/**| Organization[🏛️ Organization Service]

    Department -.->|RestClient| Employee
    Organization -.->|RestClient| Employee
    Organization -.->|RestClient| Department

    Employee --> MongoDB[(🗄️ MongoDB 8)]
    Department --> MongoDB
    Organization --> MongoDB

    classDef client fill:#f59e0b,stroke:#d97706,color:#000
    classDef gateway fill:#2563eb,stroke:#1e40af,color:#fff
    classDef service fill:#059669,stroke:#047857,color:#fff
    classDef db fill:#7c3aed,stroke:#6d28d9,color:#fff

    class Client client
    class Gateway gateway
    class Employee,Department,Organization service
    class MongoDB db
```

## Quick Start

```bash
make deps          # check required tools
make build         # build all modules with Maven
make kind-create   # create local Kind cluster with MetalLB
make kind-setup    # configure namespaces, RBAC, deploy MongoDB
make kind-deploy   # build images, load into Kind, deploy services
make e2e-test      # run end-to-end API tests
make gateway-open  # open Swagger UI in browser
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [GNU Make](https://www.gnu.org/software/make/) | 3.81+ | Build orchestration |
| [Git](https://git-scm.com/) | 2.0+ | Version control |
| [JDK](https://adoptium.net/) | 25 | Java runtime and compiler (source of truth: [`.java-version`](.java-version)) |
| [Maven](https://maven.apache.org/) | 3.9+ | Build and dependency management (pinned: `MAVEN_VER` in [Makefile](Makefile)) |
| [Docker](https://www.docker.com/) | 20.10+ | Container runtime |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.24+ | Kubernetes CLI |
| [Kind](https://kind.sigs.k8s.io/) | 0.31+ | Local Kubernetes clusters (auto-installed by `make deps-kind`) |
| [SDKMAN](https://sdkman.io/) | latest | Java/Maven version management (optional, used by `make deps-install`) |

Verify required tools are installed:

```bash
make deps
```

To install Java 25 and Maven via SDKMAN automatically:

```bash
make deps-install
```

## Available Make Targets

Run `make help` to see all available targets.

### Build & Run

| Target | Description |
|--------|-------------|
| `make build` | Build all modules with Maven (skip tests) |
| `make clean` | Clean all build artifacts |
| `make test` | Run tests |
| `make format` | Auto-format Java source code (Google style) |
| `make format-check` | Verify code formatting (CI gate) |

### Code Quality

| Target | Description |
|--------|-------------|
| `make static-check` | Run all quality and security checks (format-check, lint-ci, lint, lint-docker, secrets, trivy-fs, trivy-config) |
| `make lint` | Run Maven validate, compiler warnings-as-errors, and Checkstyle (google_checks.xml) |
| `make lint-ci` | Lint GitHub Actions workflows with actionlint (uses shellcheck) |
| `make lint-docker` | Lint all Dockerfiles with hadolint |
| `make secrets` | Scan for hardcoded secrets |
| `make trivy-fs` | Scan filesystem for vulnerabilities, secrets, and misconfigurations |
| `make trivy-config` | Scan Kubernetes manifests for security misconfigurations (KSV-*) |
| `make cve-check` | Run OWASP dependency vulnerability scan |
| `make coverage-generate` | Generate code coverage report |
| `make coverage-check` | Verify code coverage meets minimum threshold |
| `make coverage-open` | Open code coverage report in browser |

### Docker

| Target | Description |
|--------|-------------|
| `make image-build` | Build Docker images for all services |
| `make image-load` | Load Docker images into KinD cluster |

### Kind Cluster

| Target | Description |
|--------|-------------|
| `make kind-create` | Create local KinD cluster with MetalLB |
| `make kind-setup` | Create namespaces, RBAC, service accounts, and deploy MongoDB |
| `make kind-deploy` | Build, load images, deploy all services, and wait for rollout |
| `make kind-undeploy` | Remove all services from KinD cluster |
| `make kind-redeploy` | Undeploy then deploy all services |
| `make kind-destroy` | Delete KinD cluster |

### E2E Testing

| Target | Description |
|--------|-------------|
| `make e2e` | Run full end-to-end test cycle (create, setup, deploy, test, destroy) |
| `make e2e-test` | Run end-to-end test script |
| `make populate` | Populate test data via gateway |

### Utilities

| Target | Description |
|--------|-------------|
| `make help` | List all available targets |
| `make gateway-url` | Print gateway LoadBalancer URL |
| `make gateway-open` | Open Swagger UI in browser |
| `make logs-employee` | Tail employee service logs |
| `make logs-department` | Tail department service logs |
| `make logs-organization` | Tail organization service logs |
| `make logs-gateway` | Tail gateway service logs |

### CI

| Target | Description |
|--------|-------------|
| `make ci` | Run full local CI pipeline (deps, static-check, coverage, build, deps-prune-check) |
| `make ci-run` | Run GitHub Actions workflow locally via [act](https://github.com/nektos/act) |
| `make release VERSION=x.y.z` | Create a release (usage: `make release VERSION=x.y.z`) |
| `make maven-settings-ossindex` | Create Maven settings for OSS Index credentials |

### Dependencies

| Target | Description |
|--------|-------------|
| `make deps` | Check required tools (java 25, mvn) |
| `make deps-install` | Install Java and Maven via SDKMAN |
| `make deps-maven` | Install Maven if not present (for CI containers) |
| `make deps-check` | Show required tools and installation status |
| `make deps-docker` | Check Docker and kubectl |
| `make deps-kind` | Install KinD for local Kubernetes testing |
| `make deps-act` | Install act for local CI runs |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-gitleaks` | Install gitleaks for secret scanning |
| `make deps-trivy` | Install Trivy for vulnerability and misconfig scanning |
| `make deps-actionlint` | Install actionlint for GitHub Actions linting |
| `make deps-shellcheck` | Install shellcheck (used by actionlint) |
| `make deps-updates` | Print project dependencies updates |
| `make deps-update` | Update project dependencies to latest releases |
| `make deps-prune` | Check for unused Maven dependencies |
| `make deps-prune-check` | Fail if unused/undeclared Maven dependencies are present (CI gate) |

### Renovate

| Target | Description |
|--------|-------------|
| `make renovate-bootstrap` | Install nvm and npm for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## Architecture

> See the full [Reference Architecture](docs/reference-architecture.md) for detailed diagrams and configuration.

This architecture follows Cloud Native best practices and [The 12 Factor App](https://12factor.net/) methodology. Key concerns addressed:

- **Externalized configuration** using ConfigMaps, Secrets, and PropertySource
- **Kubernetes API access** using ServiceAccounts, Roles, and RoleBindings
- **Health checks** using readiness, liveness, and startup probes
- **Application state** reported via Spring Boot Actuators
- **Service discovery** across namespaces using Spring Cloud Kubernetes DiscoveryClient
- **Inter-service communication** via RestClient (`@HttpExchange`)
- **API documentation** exposed via Swagger UI
- **Docker images** built with layered JARs using the Spring Boot plugin
- **Observability** via Prometheus exporters
- **Static analysis** via Checkstyle, hadolint, and gitleaks

### Service Communication

```
Client -> Gateway (Spring Cloud Gateway MVC, LoadBalancer via MetalLB)
  |-- /employee/**     -> Employee Service (MongoDB)
  |-- /department/**   -> Department Service (MongoDB, calls Employee via RestClient)
  +-- /organization/** -> Organization Service (MongoDB, calls Department + Employee via RestClient)
```

Each service runs in its own Kubernetes namespace with dedicated service accounts and RBAC role bindings for cross-namespace discovery.

## CI/CD

GitHub Actions runs on every push to `master`, tags `v*`, and pull requests.

| Job | Triggers | Steps |
|-----|----------|-------|
| **lint** | push, PR | `make static-check` (format-check, lint-ci, lint, lint-docker, secrets, trivy-fs, trivy-config) |
| **builds** | after lint | Build all modules with Maven |
| **tests** | after lint | Run Testcontainers integration tests + coverage (non-blocking) |
| **cve-check** | push to master only (skipped under `act`) | OWASP dependency vulnerability scan |
| **docker** | tag push only | Build and push multi-arch (amd64+arm64) Docker images to GHCR — fans out over the 4 services via matrix |

Integration tests use [Testcontainers](https://testcontainers.com/) with MongoDB for fast local testing via `make test`.
End-to-end tests validate the full stack on Kind via `make e2e`.

### Required Secrets and Variables

| Name | Type | Used by | How to obtain |
|------|------|---------|---------------|
| `NVD_API_KEY` | Secret | `cve-check` job | Free API key from [NIST NVD](https://nvd.nist.gov/developers/request-an-api-key). Without it, OWASP dependency-check is heavily rate-limited. |
| `OSS_INDEX_USER` | Secret | `cve-check` job | Free account at [Sonatype OSS Index](https://ossindex.sonatype.org/user/signin). Your email address. Optional — improves vulnerability data quality. |
| `OSS_INDEX_TOKEN` | Secret | `cve-check` job | API token from [OSS Index settings](https://ossindex.sonatype.org/user/settings). Optional — paired with `OSS_INDEX_USER`. |
| `ACT` | Variable | `cve-check` job | Set to `true` to skip the `cve-check` job during local `act` runs (set automatically by `make ci-run`). |

Set secrets via **Settings > Secrets and variables > Actions > New repository secret**.
Set variables via **Settings > Secrets and variables > Actions > Variables tab > New repository variable**.

A weekly [cleanup workflow](.github/workflows/cleanup-runs.yml) prunes old workflow runs and stale caches.

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## Stargazers over time

[![Stargazers over time](https://starchart.cc/AndriyKalashnykov/spring-microservices-k8s.svg?variant=adaptive)](https://starchart.cc/AndriyKalashnykov/spring-microservices-k8s)
