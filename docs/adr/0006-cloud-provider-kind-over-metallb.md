# ADR-0006: cloud-provider-kind over MetalLB for Kind LoadBalancer

- **Status**: Accepted
- **Date**: 2026-04-18
- **Supersedes**: the MetalLB portion of [ADR-0003](0003-kind-over-minikube-k3d.md); Kind itself remains the chosen local distro.

## Decision

Replace MetalLB with [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) as the controller that allocates `type: LoadBalancer` IPs in the local Kind cluster.

## Context

ADR-0003 (2026-04-08) selected Kind + MetalLB for local Kubernetes. Two months later the portfolio-level `/makefile` skill flipped its BLOCKING default to `cloud-provider-kind` based on operational experience across ~30 repos. MetalLB's independent release cadence lagged behind Kind releases — MetalLB 0.15.3 has a known nftables regression that prevents it from reaching the Kubernetes API on `kindest/node:v1.35.0`, stranding projects on v1.34.x for months while waiting on an upstream fix. cloud-provider-kind lives in `kubernetes-sigs/` alongside Kind itself, so new `kindest/node` images are supported day-one.

## Alternatives considered

| Option | Verdict |
|--------|---------|
| **cloud-provider-kind** | **Chosen** — kind-team maintained; one `docker run` on the `kind` Docker network; allocates LoadBalancer IPs automatically from the network's subnet. No in-cluster controller, no DaemonSet, no IPAddressPool/L2Advertisement YAML. |
| Stay on MetalLB | Rejected — independent release cadence, regressions land on our combinations, larger in-cluster footprint, more Makefile machinery (apply manifest + wait for controller + wait for speaker + `docker network inspect \| awk` subnet carving + `sed`-substituted IP pool config). No project-specific reason to keep it: the manifests are tuned for a single-node local Kind cluster, no prod parity requirement with MetalLB, no MetalLB-specific feature testing (BGP, FRR, L2 announcements). |
| Ingress-nginx + `kubectl port-forward` | Rejected — changes the Service type contract (no longer `LoadBalancer`), makes `make gateway-url` return a loopback address instead of a cluster-external IP, poor fidelity with prod deployment patterns. |

## Consequences

- **Simpler `kind-create`** — replaces `kubectl apply -f metallb-native.yaml` + `kubectl rollout status controller` + `kubectl rollout status speaker` + `docker network inspect | awk` + `sed` + `kubectl apply -f metallb-config.yaml` with a single `docker run -d --network kind -v /var/run/docker.sock:/var/run/docker.sock registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v$(CLOUD_PROVIDER_KIND_VERSION)`.
- **No in-cluster footprint** — `metallb-system` namespace, Deployment, and DaemonSet are gone; `k8s/metallb-config.yaml` deleted.
- **`kind-destroy` must stop the host container** — `docker rm -f cloud-provider-kind` runs before `kind delete cluster`. Without this, the container keeps running until manually removed.
- **`CLOUD_PROVIDER_KIND_VERSION`** is pinned in the Makefile with a `# renovate:` inline comment; Renovate tracks it via the existing Makefile custom-manager regex.
- **IP allocation strategy is the same from the user's perspective** — `make gateway-url` still returns a cluster-external IP on the `kind` Docker network (e.g., `172.18.0.X`); `curl` works identically.
- **Kindest/node compatibility no longer gated on MetalLB release schedule** — future `KIND_VERSION` / `KIND_NODE_IMAGE` bumps are decoupled from LoadBalancer controller availability.

## References

- cloud-provider-kind: <https://github.com/kubernetes-sigs/cloud-provider-kind>
- Makefile targets: `kind-create`, `kind-destroy`, `kind-up`, `kind-down`
- Kind cluster config: `k8s/kind-config.yaml` (unchanged)
- Deleted: `k8s/metallb-config.yaml`
