# ADR-0002: Remove Secret file mounts; use `valueFrom.secretKeyRef`

- **Status**: Accepted
- **Date**: 2026-04-10
- **Context**: Spring Boot 4.0 / Spring Cloud Kubernetes 5.x upgrade

## Decision

Stop using `spring.cloud.kubernetes.secrets.paths` to mount Secrets as files on the filesystem. Inject Secret values directly as environment variables via `valueFrom.secretKeyRef` on each Deployment.

## Context

The previous pattern mounted Kubernetes Secrets as files under `/etc/secrets/` and relied on Spring Cloud Kubernetes to read them into the property source. Under SC Kubernetes 5.x this has the same timing issue as ConfigMap sourcing (see ADR-0001) — credentials aren't available before the `MongoClient` bean is wired.

Beyond the timing bug, file-mounted Secrets have a worse attack surface than env-var injection: any process that gains read access to the pod filesystem can cat the mount. Env vars are only visible to the process and its descendants.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| Keep file mounts via `spring.cloud.kubernetes.secrets.paths` | Rejected — broken under SC Kubernetes 5.x AND worse attack surface |
| External secrets operator (Vault, AWS Secrets Manager, etc.) | Deferred — overkill for a local-dev demo; valid for production |
| `valueFrom.secretKeyRef` on the Deployment | **Chosen** — native Kubernetes, no Spring dependency, works with any version |

## Consequences

- Rotating a credential requires re-rolling the Deployment (no hot reload). Acceptable trade-off — the previous "hot reload" was advertised but not actually firing under SB 4.
- Secret keys are visible in `kubectl describe pod` output (as `env: valueFrom.secretKeyRef` references, not values). Values remain secret.
- One less Spring Cloud feature we depend on — reduces SC Kubernetes surface to just `DiscoveryClient`.

## References

- See `k8s/mongodb-secret.yaml` + `k8s/employee-deployment.yaml` (`env:` section) for the current pattern
