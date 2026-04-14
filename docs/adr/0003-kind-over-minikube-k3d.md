# ADR-0003: Kind + MetalLB for local Kubernetes

- **Status**: Accepted
- **Date**: 2026-04-08

## Decision

Use [Kind](https://kind.sigs.k8s.io/) with [MetalLB](https://metallb.universe.tf/) for the local Kubernetes environment. Reject Minikube, k3d, Docker Desktop Kubernetes, and OrbStack Kubernetes.

## Context

The project demonstrates Spring Cloud Kubernetes features that depend on real Kubernetes API behaviour — namespace-scoped service discovery, RBAC, ConfigMap/Secret references. A local environment that diverges from upstream Kubernetes behaviour would make the demo misleading.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| Minikube | Rejected — VM-based (slow startup on Apple Silicon), less-used by the Kubernetes maintainers themselves |
| k3d | Considered — lightweight k3s-in-Docker, but k3s strips/replaces parts of upstream K8s (Traefik default, klipper-lb). Too many "is this k3s or is this Kubernetes?" footguns for a learning-oriented reference |
| Docker Desktop Kubernetes | Rejected — couples the choice of Kubernetes distro to the choice of container runtime; users on Podman / OrbStack / Colima can't run it |
| OrbStack Kubernetes | Rejected — macOS-only; the project must work on Linux CI runners too |
| **Kind + MetalLB** | **Chosen** — kubeadm-provisioned upstream Kubernetes in Docker, multi-node capable, actively maintained by the K8s SIG. MetalLB gives `type: LoadBalancer` Services a reachable IP without ingress controllers. |

## Consequences

- Service type `LoadBalancer` works as it would in a real cluster. No `minikube tunnel`, no `kubectl port-forward` in the happy path.
- The Kind node image tag must track the Kind release (see `KIND_NODE_IMAGE` / `KIND_VERSION` in Makefile). Mismatched pairs produce cryptic errors — bumping Kind without bumping the node image is the #1 gotcha.
- MetalLB is configured in Layer-2 mode on a `/24` inside the Kind Docker network. Requires no external routing, works identically on Linux and macOS under Docker or Podman.

## References

- Makefile targets: `kind-create`, `kind-setup`, `kind-up`, `kind-down`
- MetalLB config: `k8s/metallb-config.yaml`
- Kind cluster config: `k8s/kind-config.yaml`
