[![CI](https://github.com/AndriyKalashnykov/spring-microservices-k8s/actions/workflows/main.yml/badge.svg)](https://github.com/AndriyKalashnykov/spring-microservices-k8s/actions/workflows/main.yml)
[![Hits](https://hits.sh/github.com/AndriyKalashnykov/spring-microservices-k8s.svg?view=today-total&style=plastic)](https://hits.sh/github.com/AndriyKalashnykov/spring-microservices-k8s/)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](https://opensource.org/licenses/MIT)
[![Renovate enabled](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://app.renovatebot.com/dashboard#github/AndriyKalashnykov/spring-microservices-k8s)

# Java Microservices with Spring Boot and Spring Cloud Kubernetes

This reference architecture demonstrates design, development, and deployment of Spring Boot microservices on Kubernetes. It implements a hierarchical domain model (Organization > Department > Employee) with four services deployed across isolated namespaces, using Spring Cloud Kubernetes for service discovery, configuration, and secrets management.

The tech stack includes Java 21, Spring Boot 3.4, Spring Cloud Kubernetes (2024.0), Spring Cloud Gateway MVC, RestClient with @HttpExchange for inter-service communication, Micrometer Tracing for distributed tracing, MongoDB 7.0 for persistence, Testcontainers for integration testing, and Kind with MetalLB for local development.

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
| [JDK](https://adoptium.net/) | 21 | Java runtime and compiler |
| [Maven](https://maven.apache.org/) | 3.6+ | Build and dependency management |
| [Docker](https://www.docker.com/) | 20.10+ | Container runtime |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | 1.24+ | Kubernetes CLI |
| [Kind](https://kind.sigs.k8s.io/) | 0.31+ | Local Kubernetes clusters (auto-installed by `make deps-kind`) |

Install and verify required tools:

```bash
make deps
```

## Available Make Targets

### Build

| Target | Description |
|--------|-------------|
| `make build` | Build all modules with Maven (skip tests) |
| `make clean` | Clean all build artifacts |
| `make test` | Run tests |
| `make lint` | Run Checkstyle and compiler warning checks |
| `make format` | Auto-format Java source code |
| `make format-check` | Verify code formatting (CI gate) |

### Code Quality

| Target | Description |
|--------|-------------|
| `make static-check` | Run all quality and security checks |
| `make cve-check` | Run OWASP dependency vulnerability scan |
| `make lint-docker` | Lint all Dockerfiles with hadolint |
| `make secrets` | Scan for hardcoded secrets |
| `make coverage-generate` | Generate code coverage report |
| `make coverage-check` | Verify code coverage meets minimum threshold |
| `make coverage-open` | Open code coverage report in browser |
| `make deps-prune` | Check for unused Maven dependencies |

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
| `make ci` | Run full local CI pipeline |
| `make ci-run` | Run GitHub Actions workflow locally using act |
| `make release VERSION=x.y.z` | Create a semver release tag |
| `make deps` | Check required dependencies |
| `make deps-install` | Install Java and Maven via SDKMAN |
| `make deps-maven` | Install Maven if not present (for CI) |
| `make deps-check` | Show required tools and installation status |
| `make deps-docker` | Check Docker and kubectl |
| `make deps-kind` | Install KinD for local Kubernetes testing |
| `make deps-act` | Install act for local CI runs |
| `make deps-hadolint` | Install hadolint for Dockerfile linting |
| `make deps-gitleaks` | Install gitleaks for secret scanning |
| `make deps-updates` | Print project dependencies updates |
| `make deps-update` | Update project dependencies to latest releases |
| `make renovate-bootstrap` | Install nvm and npm for Renovate |
| `make renovate-validate` | Validate Renovate configuration |

## Architecture

See the full [Reference Architecture](docs/reference-architecture.md) document with diagrams.

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
| **lint** | push, PR | Format check, Checkstyle, Dockerfile lint, secret scan, Trivy |
| **builds** | after lint | Build all modules with Maven |
| **tests** | after lint | Run Testcontainers integration tests + coverage |
| **cve-check** | push to master | OWASP dependency vulnerability scan |
| **docker** | tag push only | Build and push multi-arch Docker images to GHCR |

Integration tests use [Testcontainers](https://testcontainers.com/) with MongoDB for fast local testing via `make test`.
End-to-end tests validate the full stack on Kind via `make e2e`.

### Required Secrets

| Secret | Used by | How to obtain |
|--------|---------|---------------|
| `NVD_API_KEY` | `cve-check` job | Free API key from [NIST NVD](https://nvd.nist.gov/developers/request-an-api-key). Without it, OWASP dependency-check is rate-limited and the job may time out. |

Set via **Settings > Secrets and variables > Actions > New repository secret**.

A weekly [cleanup workflow](.github/workflows/cleanup-runs.yml) prunes old workflow runs.

[Renovate](https://docs.renovatebot.com/) keeps dependencies up to date with platform automerge enabled.

## Stargazers over time

[![Stargazers over time](https://starchart.cc/AndriyKalashnykov/spring-microservices-k8s.svg?variant=adaptive)](https://starchart.cc/AndriyKalashnykov/spring-microservices-k8s)
