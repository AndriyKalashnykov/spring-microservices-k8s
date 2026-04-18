# Architecture Decision Records

Short records of the architectural decisions made on this project, why, and what was considered and rejected. Format follows [Michael Nygard's ADR template](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

| # | Title | Status |
|---|-------|--------|
| [0001](0001-remove-configmap-property-sourcing.md) | Remove ConfigMap property sourcing via `spring.config.import` | Accepted |
| [0002](0002-remove-secret-file-mounts.md) | Remove Secret file mounts; use `valueFrom.secretKeyRef` | Accepted |
| [0003](0003-kind-over-minikube-k3d.md) | Kind + MetalLB for local Kubernetes | Superseded by [0006](0006-cloud-provider-kind-over-metallb.md) |
| [0004](0004-restclient-httpexchange-over-feign.md) | RestClient with `@HttpExchange` over OpenFeign | Accepted |
| [0005](0005-plantuml-c4-over-mermaid.md) | PlantUML + C4-PlantUML for structural architecture diagrams | Accepted |
| [0006](0006-cloud-provider-kind-over-metallb.md) | cloud-provider-kind over MetalLB for Kind LoadBalancer | Accepted |

## Writing a new ADR

1. Copy the structure of an existing ADR (Status / Date / Context / Decision / Alternatives considered / Consequences / References).
2. Number sequentially (`NNNN-kebab-title.md`).
3. Keep it under ~1 page — ADRs document a decision, not a design spec.
4. Cross-link from the relevant diagram or manifest when the ADR explains a choice visible there.
