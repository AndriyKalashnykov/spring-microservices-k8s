# ADR-0001: Remove ConfigMap property sourcing via `spring.config.import`

- **Status**: Accepted
- **Date**: 2026-04-10
- **Context**: Spring Boot 4.0 / Spring Cloud 2025.1 / Spring Cloud Kubernetes 5.x upgrade

## Decision

Stop using `spring.config.import: "optional:kubernetes:"` to pull ConfigMap values into Spring's property source. Inject all ConfigMap values directly into the Deployment via `envFrom` / `valueFrom.configMapKeyRef`.

## Context

Earlier revisions used Spring Cloud Kubernetes' `kubernetes:` config-import source, which asks the controller to load ConfigMap data into the Spring environment before other beans initialize. Under SC Kubernetes 5.x the informer-based loader does not publish the PropertySource before the `MongoClient` bean is instantiated — `spring.mongodb.*` properties silently fall back to defaults, and MongoDB connectivity appears to work against `localhost:27017` in Kind but fails in any non-trivial topology.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| Keep `spring.config.import: "optional:kubernetes:"` | Rejected — broken under SC Kubernetes 5.x informer timing |
| Use `bootstrap.yml` to pre-load ConfigMaps | Rejected — deprecated in Spring Boot 4 |
| Inject via `envFrom` on the Deployment manifest | **Chosen** — simpler, explicit, no timing dependency, works with any Spring version |

## Consequences

- Configuration is now declared twice: once in the ConfigMap YAML, once as `envFrom` references in the Deployment. Minor duplication, large reliability gain.
- ConfigMap changes still require a pod restart. Not a regression — the previous informer-based sourcing technically supported hot reload but wasn't firing under SB 4.
- The `spring.cloud.kubernetes.config.*` properties are now unused. Removed from all application.yml files.

## References

- See `k8s/employee-configmap.yaml` + `k8s/employee-deployment.yaml` for the current pattern
- See `docs/reference-architecture.md` "Spring Cloud Kubernetes" section for the full rationale
