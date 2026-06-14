.DEFAULT_GOAL := help

APP_NAME      := spring-microservices-k8s
CURRENTTAG    := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

SHELL         := /bin/bash

# Tools installed by deps-* targets land in $HOME/.local/bin (no sudo needed).
# Mise installs shims into $HOME/.local/share/mise/shims (java, mvn, node, …) —
# exporting it here means recipes work without the user having
# `eval "$(mise activate bash)"` in their shell.
# Required for `make ci-run` (act) which uses $HOME/.local/bin tools too.
export PATH := $(HOME)/.local/share/mise/shims:$(HOME)/.local/bin:$(PATH)

KIND_CLUSTER_NAME := spring-microservices-k8s
SERVICES          := employee department organization gateway
IMAGE_TAG         := local
SA_NAME           := api-service-account

# Pin every kubectl call to OUR cluster's context. Defends against multi-session
# host conflicts where a parallel `make` from another KinD-using project runs
# `kubectl config use-context` and steals our default context mid-recipe. Each
# kubectl call carries the explicit `--context` so the kubeconfig's current
# context never matters. e2e-test.sh receives the cluster name via env (see
# the e2e-test recipe).
KUBECTL := kubectl --context=kind-$(KIND_CLUSTER_NAME)

# Detect macOS for 'open' vs 'xdg-open'
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

# Semver regex for release validation
SEMVER_RE := ^[0-9]+\.[0-9]+\.[0-9]+$$

# === Tool Versions ===
# Java, Maven, Node, kind, act, hadolint, gitleaks, trivy, actionlint,
# shellcheck are pinned in .mise.toml (single source of truth, Renovate-tracked
# there via inline comments). .java-version and .nvmrc remain the secondary
# sources for CI tooling that reads them directly (mise reads both natively).
#
# Intentionally NOT Renovate-tracked: kindest/node is version-LOCKED to the
# pinned kind CLI — it must be one of the pre-built images that kind ships, so
# it cannot bump independently of `kind` (per the kind <-> kindest/node catalog
# pairing rule). kind 0.32.0 ships: v1.36.1, v1.35.5 (default), v1.34.8,
# v1.33.12. Bump this image ONLY together with the kind CLI in .mise.toml, to a
# version in the NEW catalog (re-read the target kind release notes each time).
# Digest-pinned for image immutability (the manifest-list digest covers both
# linux/amd64 and linux/arm64 variants).
KIND_NODE_IMAGE   := kindest/node:v1.35.5@sha256:ce977ae6d65918d0b58a5f8b5e940429c2ce42fa3a5619ec2bbc60b949c0ac95
# renovate: datasource=github-releases depName=kubernetes-sigs/cloud-provider-kind extractVersion=^v(?<version>.*)$
CLOUD_PROVIDER_KIND_VERSION := 0.10.0
# renovate: datasource=github-releases depName=google/google-java-format extractVersion=^v(?<version>.*)$
GJF_VERSION       := 1.35.0
# Source of truth: .nvmrc (major version only, e.g., "22"); not Renovate-trackable.
# Pinned in .mise.toml too; mise reads .nvmrc natively.
NODE_VERSION      := $(shell cat .nvmrc 2>/dev/null || echo 22)
# renovate: datasource=docker depName=plantuml/plantuml
PLANTUML_VERSION    := 1.2026.6
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.15.0
# renovate: datasource=github-releases depName=GoogleContainerTools/container-structure-test extractVersion=^v(?<version>.*)$
CONTAINER_STRUCTURE_TEST_VERSION := 1.22.1

# Source of truth: .java-version (read by CI via java-version-file); not Renovate-trackable.
# Used by deps target to verify the installed Java major matches the project.
JAVA_MAJOR        := $(shell cat .java-version 2>/dev/null || echo 25)

# Service ports used when building LoadBalancer URLs in recipes below. These
# MIRROR the k8s Service manifest ports (gateway: k8s/gateway-deployment.yaml,
# jaeger UI: k8s/jaeger-deployment.yaml) — change them there too if you retune.
# `?=` lets an operator override without editing recipes.
GATEWAY_PORT      ?= 8080
JAEGER_UI_PORT    ?= 16686

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-30s\033[0m - %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

#deps: @ Ensure mise + the toolchain pinned in .mise.toml are installed
deps:
	@# Local bootstrap: install mise if missing (CI pre-installs via jdx/mise-action)
	@if [ -z "$$CI" ] && ! command -v mise >/dev/null 2>&1; then \
		echo "Installing mise (https://mise.jdx.dev/)..."; \
		curl -fsSL https://mise.run | sh; \
		echo ""; \
		echo "mise installed. Activate it in your shell, then re-run 'make deps':"; \
		echo '  bash: echo '\''eval "$$(~/.local/bin/mise activate bash)"'\'' >> ~/.bashrc'; \
		echo '  zsh:  echo '\''eval "$$(~/.local/bin/mise activate zsh)"'\''  >> ~/.zshrc'; \
		exit 0; \
	fi
	@# Install the toolchain declared in .mise.toml (idempotent; no-op if up to date)
	@command -v mise >/dev/null 2>&1 && mise install --yes || { \
		echo "Error: mise required. Install via 'curl https://mise.run | sh' or use jdx/mise-action in CI."; \
		exit 1; \
	}

#deps-install: @ Alias for 'deps' (kept for backwards compatibility)
deps-install: deps

#deps-check: @ Show required tools and installation status
deps-check:
	@echo "--- Tool status ---"
	@for tool in java mvn docker kubectl kind act hadolint gitleaks trivy actionlint shellcheck node; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done
	@echo "--- mise ---"
	@command -v mise >/dev/null 2>&1 && echo "  installed ($$(mise --version))" || echo "  NOT installed (run: make deps)"

#deps-docker: @ Check Docker (used by diagrams, mermaid-lint, image-build, Testcontainers)
deps-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker required. See https://docs.docker.com/get-docker/"; exit 1; }

#deps-kubectl: @ Check kubectl (required for Kind cluster targets)
deps-kubectl:
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl required. See https://kubernetes.io/docs/tasks/tools/"; exit 1; }

#deps-kind: @ Ensure kind toolchain (mise installs kind; docker + kubectl verified)
deps-kind: deps deps-docker deps-kubectl

#deps-act: @ Ensure act toolchain (mise installs act; docker verified)
deps-act: deps deps-docker

#deps-updates: @ Print project dependencies updates
deps-updates: deps
	@mvn -B versions:display-dependency-updates

#deps-update: @ Update project dependencies to latest releases
deps-update: deps-updates
	@mvn -B versions:use-latest-releases
	@mvn -B versions:commit

#deps-prune: @ Check for unused Maven dependencies
deps-prune: deps
	@mvn -B dependency:analyze -DignoreNonCompile=true 2>&1 | grep -E 'Unused|Used undeclared' || echo "No unused dependencies found."

#deps-prune-check: @ Fail if unused or undeclared Maven dependencies are present (CI gate)
deps-prune-check: deps
	@out=$$(mvn -B dependency:analyze -DignoreNonCompile=true -DfailOnWarning=false 2>&1); \
	if echo "$$out" | grep -qE '\[WARNING\] (Unused declared|Used undeclared) dependencies'; then \
		echo "$$out" | grep -A20 -E '\[WARNING\] (Unused declared|Used undeclared) dependencies'; \
		echo "ERROR: prunable Maven dependencies found. Run 'make deps-prune' for details."; \
		exit 1; \
	fi
	@echo "No prunable dependencies found."

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

#clean: @ Clean all build artifacts
clean: deps
	@mvn -B clean -q

#build: @ Build all modules with Maven (skip tests)
build: deps
	@mvn -B install -Dmaven.test.skip=true -Ddependency-check.skip=true

#test: @ Run tests
test: deps
	@mvn -B test -Ddependency-check.skip=true

#integration-test: @ Run integration tests (Testcontainers + WireMock, tens of seconds)
integration-test: deps deps-docker
	@mvn -B verify -P integration-test -Ddependency-check.skip=true

#lint: @ Run Maven validate, compiler warnings-as-errors, and Checkstyle (google_checks.xml)
lint: deps
	@mvn -B validate -Ddependency-check.skip=true
	@mvn -B compile -Dmaven.compiler.failOnWarning=true -Ddependency-check.skip=true -q
	@mvn -B checkstyle:check -Dcheckstyle.config.location=google_checks.xml

GJF_JAR := $(HOME)/.cache/google-java-format/google-java-format-$(GJF_VERSION)-all-deps.jar
GJF_URL := https://github.com/google/google-java-format/releases/download/v$(GJF_VERSION)/google-java-format-$(GJF_VERSION)-all-deps.jar

# JDK-internal compiler packages google-java-format needs exported (JDK 16+).
# Shared verbatim by the `format` and `format-check` recipes.
GJF_EXPORTS := --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
	--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
	--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
	--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
	--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED

$(GJF_JAR):
	@mkdir -p $(dir $(GJF_JAR))
	@echo "Downloading google-java-format $(GJF_VERSION)..."
	@curl -sSfL -o $(GJF_JAR) $(GJF_URL)

#format: @ Auto-format Java source code (Google style)
format: deps $(GJF_JAR)
	@find . -path '*/src/main/java/*.java' -o -path '*/src/test/java/*.java' | \
		xargs java $(GJF_EXPORTS) -jar $(GJF_JAR) --replace
	@echo "Formatted all Java files with Google style."

#format-check: @ Verify code formatting (CI gate)
format-check: deps $(GJF_JAR)
	@find . -path '*/src/main/java/*.java' -o -path '*/src/test/java/*.java' | \
		xargs java $(GJF_EXPORTS) -jar $(GJF_JAR) --set-exit-if-changed --dry-run > /dev/null

# ---------------------------------------------------------------------------
# Code Quality
# ---------------------------------------------------------------------------

#lint-docker: @ Lint all Dockerfiles with hadolint
lint-docker: deps
	@for svc in $(SERVICES); do \
		echo "Linting $$svc-service/Dockerfile..."; \
		hadolint $$svc-service/Dockerfile; \
	done

#secrets: @ Scan for hardcoded secrets
secrets: deps
	@gitleaks detect --source . --verbose --redact --no-git

#trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
trivy-fs: deps
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH \
		--skip-dirs target --skip-dirs .git .

#trivy-config: @ Scan Kubernetes manifests for security misconfigurations (KSV-*)
trivy-config: deps
	@trivy config --severity CRITICAL,HIGH k8s/

DIAGRAM_DIR := docs/diagrams
DIAGRAM_SRC := $(wildcard $(DIAGRAM_DIR)/*.puml)
DIAGRAM_OUT := $(patsubst $(DIAGRAM_DIR)/%.puml,$(DIAGRAM_DIR)/out/%.png,$(DIAGRAM_SRC))

#diagrams: @ Render PlantUML architecture diagrams to PNG
diagrams: deps-docker $(DIAGRAM_OUT)

$(DIAGRAM_DIR)/out/%.png: $(DIAGRAM_DIR)/%.puml
	@mkdir -p $(DIAGRAM_DIR)/out
	@docker run --rm -v "$(CURDIR)/$(DIAGRAM_DIR):/work" -w /work \
		-e HOME=/tmp -e _JAVA_OPTIONS=-Duser.home=/tmp \
		plantuml/plantuml:$(PLANTUML_VERSION) \
		-tpng -o out $(notdir $<)
	@docker run --rm -v "$(CURDIR)/$(DIAGRAM_DIR):/work" --entrypoint /bin/sh \
		plantuml/plantuml:$(PLANTUML_VERSION) \
		-c "chown -R $$(id -u):$$(id -g) /work/out" >/dev/null 2>&1 || true

#diagrams-check: @ Verify committed diagram PNGs match current .puml source (CI drift check)
diagrams-check: diagrams
	@git diff --exit-code -- $(DIAGRAM_DIR)/out >/dev/null || { \
		echo "ERROR: Diagram source changed but rendered PNGs not updated. Run 'make diagrams' and commit docs/diagrams/out/."; \
		exit 1; \
	}
	@echo "Diagrams in sync with source."

#diagrams-clean: @ Remove rendered diagram PNGs
diagrams-clean:
	@rm -rf $(DIAGRAM_DIR)/out

#mermaid-lint: @ Validate Mermaid diagrams in markdown files (used for sequence/flow diagrams)
mermaid-lint: deps-docker
	@set -euo pipefail; \
	MD_FILES=$$(grep -lF '```mermaid' README.md CLAUDE.md docs/*.md docs/**/*.md 2>/dev/null || true); \
	if [ -z "$$MD_FILES" ]; then \
		echo "No Mermaid blocks found — skipping."; \
		exit 0; \
	fi; \
	IMAGE=minlag/mermaid-cli:$(MERMAID_CLI_VERSION); \
	echo "Pre-pulling $$IMAGE (3-attempt retry to absorb Docker Hub anonymous-pull flakes)..."; \
	pulled=0; \
	for attempt in 1 2 3; do \
		if docker pull "$$IMAGE" >/dev/null 2>&1; then pulled=1; break; fi; \
		[ "$$attempt" -lt 3 ] && sleep $$((attempt * 5)); \
	done; \
	[ "$$pulled" -eq 1 ] || { echo "  ✗ Failed to pull $$IMAGE after 3 attempts."; exit 1; }; \
	FAILED=0; \
	for md in $$MD_FILES; do \
		echo "Validating Mermaid blocks in $$md..."; \
		LOG=$$(mktemp); \
		if docker run --rm -v "$$PWD:/data:ro" \
			"$$IMAGE" \
			-i "/data/$$md" -o "/tmp/$$(basename $$md .md).svg" >"$$LOG" 2>&1; then \
			echo "  ✓ All blocks rendered cleanly."; \
		else \
			echo "  ✗ Parse error in $$md:"; \
			sed 's/^/    /' "$$LOG"; \
			FAILED=$$((FAILED + 1)); \
		fi; \
		rm -f "$$LOG"; \
	done; \
	if [ "$$FAILED" -gt 0 ]; then \
		echo "Mermaid lint: $$FAILED file(s) had parse errors."; \
		exit 1; \
	fi

#lint-ci: @ Lint GitHub Actions workflows with actionlint (uses shellcheck)
lint-ci: deps
	@actionlint

#maven-settings-ossindex: @ Write ~/.m2/settings.xml with OSS Index and/or NVD API credentials when their env vars are set
# `printf` is a bash builtin — values stay in shell memory, never enter argv.
# Each `<server>` block is referenced by its id from the OWASP plugin: `ossindex`
# is read by the OSS Index analyzer (default convention); `nvd` is referenced
# explicitly via `-DnvdApiServerId=nvd` in the cve-check recipe so the API key
# value never crosses argv.
maven-settings-ossindex:
	@if [ -n "$$OSS_INDEX_USER$$OSS_INDEX_TOKEN" ] || [ -n "$$NVD_API_KEY" ]; then \
		mkdir -p ~/.m2; \
		{ \
			printf '<settings>\n  <servers>\n'; \
			if [ -n "$$OSS_INDEX_USER" ] && [ -n "$$OSS_INDEX_TOKEN" ]; then \
				printf '    <server>\n      <id>ossindex</id>\n      <username>%s</username>\n      <password>%s</password>\n    </server>\n' "$$OSS_INDEX_USER" "$$OSS_INDEX_TOKEN"; \
			fi; \
			if [ -n "$$NVD_API_KEY" ]; then \
				printf '    <server>\n      <id>nvd</id>\n      <password>%s</password>\n    </server>\n' "$$NVD_API_KEY"; \
			fi; \
			printf '  </servers>\n</settings>\n'; \
		} > ~/.m2/settings.xml; \
	fi

#cve-check: @ Run OWASP dependency vulnerability scan
# `-DnvdApiServerId=nvd` references the literal id of the `<server>` block
# written by maven-settings-ossindex; the API key value lives in settings.xml
# only — never in argv. Safe even on multi-user hosts (`ps -ef`, `/proc/<pid>/cmdline`).
#
# TODO(workaround): the CI `cve-check` job carries `continue-on-error: true` because
# OWASP dependency-check 12.2.x cannot parse NVD's 9-digit nanosecond timestamps
# (DateTimeParseException). Upstream: dependency-check/DependencyCheck#8424 and
# jeremylong/open-vulnerability-clients#106. Remove the `continue-on-error` flag in
# ci.yml and this note when ODC ships a release with the NVD-timestamp fix. See
# CLAUDE.md upgrade-backlog item #1c for the full deferral rationale and triggers.
cve-check: deps maven-settings-ossindex
	@mvn -B org.owasp:dependency-check-maven:check \
		$$([ -n "$$NVD_API_KEY" ] && echo "-DnvdApiServerId=nvd")

#coverage-generate: @ Generate code coverage report
coverage-generate: deps
	@mvn -B test -Ddependency-check.skip=true org.jacoco:jacoco-maven-plugin:report

#coverage-check: @ Verify code coverage meets minimum threshold (BUNDLE INSTRUCTION >= 30%)
coverage-check: coverage-generate
	@mvn -B org.jacoco:jacoco-maven-plugin:check@check -Ddependency-check.skip=true

#coverage-open: @ Open code coverage report in browser
coverage-open:
	@$(OPEN_CMD) ./employee-service/target/site/jacoco/index.html

#static-check: @ Run all quality and security checks
# `deps` is listed explicitly so a cold checkout reaches the mise toolchain
# without relying on it being pulled transitively via format-check's prereqs.
static-check: deps format-check diagrams-check mermaid-lint lint-ci lint lint-docker secrets trivy-fs trivy-config
	@echo "Static check passed."

# ---------------------------------------------------------------------------
# Docker Images
# ---------------------------------------------------------------------------

#image-build: @ Build Docker images for all services
image-build: deps-docker build
	@for svc in $(SERVICES); do \
		echo "Building $$svc:$(IMAGE_TAG)..."; \
		BUILDX_BUILDER=default docker buildx build --load -t $$svc:$(IMAGE_TAG) -f $$svc-service/Dockerfile $$svc-service/; \
	done

#container-structure-test: @ Validate Dockerfile contracts (USER, EXPOSE, ENTRYPOINT) on built images
# Mirrors the CI `image-scan` step. The shared .container-structure-test.yaml config
# applies to all 4 services because their Dockerfiles follow the same shape.
container-structure-test: deps-docker image-build
	@for svc in $(SERVICES); do \
		echo "Container structure test: $$svc"; \
		docker run --rm \
			-v /var/run/docker.sock:/var/run/docker.sock \
			-v "$(CURDIR)/.container-structure-test.yaml:/test.yaml:ro" \
			gcr.io/gcp-runtimes/container-structure-test:v$(CONTAINER_STRUCTURE_TEST_VERSION) \
			test --image $$svc:$(IMAGE_TAG) --config /test.yaml; \
	done

#image-load: @ Load Docker images into KinD cluster
image-load: deps-kind
	@for svc in $(SERVICES); do \
		echo "Loading $$svc:$(IMAGE_TAG) into cluster..."; \
		kind load docker-image $$svc:$(IMAGE_TAG) --name $(KIND_CLUSTER_NAME); \
	done

# ---------------------------------------------------------------------------
# KinD Cluster
# ---------------------------------------------------------------------------

#kind-create: @ Create local KinD cluster with cloud-provider-kind LoadBalancer controller
kind-create: deps-kind
	@if kind get clusters 2>/dev/null | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "KinD cluster '$(KIND_CLUSTER_NAME)' already exists..."; \
		kubectl config use-context kind-$(KIND_CLUSTER_NAME); \
	else \
		echo "Creating KinD cluster with node image $(KIND_NODE_IMAGE)..."; \
		kind create cluster \
			--config=k8s/kind-config.yaml \
			--name $(KIND_CLUSTER_NAME) \
			--image=$(KIND_NODE_IMAGE) \
			--wait 60s; \
	fi
	@# cloud-provider-kind runs host-side (not in the cluster). It watches
	@# Services of type LoadBalancer and allocates IPs on the `kind` Docker
	@# network. Kind-team maintained (kubernetes-sigs/cloud-provider-kind),
	@# so new kindest/node images are supported day-one. See ADR-0006.
	@echo "Starting cloud-provider-kind $(CLOUD_PROVIDER_KIND_VERSION)..."
	@docker rm -f cloud-provider-kind >/dev/null 2>&1 || true
	@docker run --rm -d \
		--name cloud-provider-kind \
		--network kind \
		-v /var/run/docker.sock:/var/run/docker.sock \
		registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v$(CLOUD_PROVIDER_KIND_VERSION) >/dev/null
	@echo "cloud-provider-kind is running; LoadBalancer Services will receive IPs automatically."

#kind-setup: @ Create namespaces, RBAC, service accounts, and deploy MongoDB
kind-setup: deps-docker deps-kubectl
	@echo "Creating namespaces..."
	@for ns in department employee gateway organization mongo observability; do \
		$(KUBECTL) create namespace $$ns --dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	done
	@echo "Applying RBAC cluster role..."
	@$(KUBECTL) apply -f k8s/rbac-cluster-role.yaml
	@echo "Creating service accounts and role bindings..."
	@for ns in department employee gateway organization mongo observability; do \
		$(KUBECTL) create serviceaccount $(SA_NAME) -n $$ns --dry-run=client -o yaml | $(KUBECTL) apply -f -; \
		$(KUBECTL) create clusterrolebinding $(SA_NAME)-$$ns \
			--clusterrole=microservices-kubernetes-namespace-reader \
			--serviceaccount=$$ns:$(SA_NAME) \
			--dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	done
	@echo "Deploying MongoDB..."
	@$(KUBECTL) apply -f k8s/mongodb-configmap.yaml -n mongo
	@$(KUBECTL) apply -f k8s/mongodb-secret.yaml -n mongo
	@$(KUBECTL) apply -f k8s/mongodb-deployment.yaml -n mongo
	@echo "Deploying Jaeger (tracing backend)..."
	@$(KUBECTL) apply -f k8s/jaeger-config.yaml -n observability
	@$(KUBECTL) apply -f k8s/jaeger-deployment.yaml -n observability
	@echo "Waiting for MongoDB rollout..."
	@$(KUBECTL) rollout status deployment/mongodb -n mongo --timeout=120s
	@echo "Waiting for Jaeger rollout..."
	@$(KUBECTL) rollout status deployment/jaeger -n observability --timeout=120s

#kind-deploy: @ Build, load images, deploy all services, and wait for rollout
kind-deploy: kind-create kind-setup image-build
	@# Re-assert $(KUBECTL) context immediately before the deploy loop. Multi-session
	@# host conflict guard: a parallel `make` from another KinD-using project
	@# can run `kubectl config use-context` and steal our context between
	@# kind-setup and the deploy recipe. Real incident 2026-05-03.
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME) >/dev/null
	@$(MAKE) image-load
	@echo "Deploying services..."
	@for svc in employee department organization; do \
		echo "Deploying $$svc..."; \
		$(KUBECTL) apply -f k8s/$$svc-configmap.yaml -n $$svc; \
		$(KUBECTL) apply -f k8s/$$svc-secret.yaml -n $$svc; \
		$(KUBECTL) apply -f k8s/$$svc-deployment.yaml -n $$svc; \
	done
	@echo "Deploying gateway..."
	@$(KUBECTL) apply -f k8s/gateway-configmap.yaml -n gateway
	@$(KUBECTL) apply -f k8s/gateway-deployment.yaml -n gateway
	@echo "Waiting for deployments..."
	@for svc in $(SERVICES); do \
		echo "Waiting for $$svc rollout..."; \
		$(KUBECTL) rollout status deployment/$$svc -n $$svc --timeout=300s; \
	done
	@echo "Waiting for gateway LoadBalancer IP..."
	@for i in $$(seq 1 30); do \
		EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
		if [ -n "$$EXTERNAL_IP" ] && [ "$$EXTERNAL_IP" != "<pending>" ]; then \
			echo "Gateway available at http://$$EXTERNAL_IP:$(GATEWAY_PORT)"; \
			break; \
		fi; \
		echo "  waiting for LoadBalancer IP... ($$i/30)"; \
		sleep 2; \
	done

#kind-undeploy: @ Remove all services from KinD cluster
kind-undeploy: deps-docker deps-kubectl
	@for svc in employee department organization; do \
		echo "Removing $$svc..."; \
		$(KUBECTL) delete -f k8s/$$svc-deployment.yaml -n $$svc --ignore-not-found=true; \
		$(KUBECTL) delete -f k8s/$$svc-secret.yaml -n $$svc --ignore-not-found=true; \
		$(KUBECTL) delete -f k8s/$$svc-configmap.yaml -n $$svc --ignore-not-found=true; \
	done
	@echo "Removing gateway..."
	@$(KUBECTL) delete -f k8s/gateway-deployment.yaml -n gateway --ignore-not-found=true
	@$(KUBECTL) delete -f k8s/gateway-configmap.yaml -n gateway --ignore-not-found=true

#kind-redeploy: @ Undeploy then deploy all services
kind-redeploy: kind-undeploy kind-deploy

#kind-destroy: @ Delete KinD cluster and stop cloud-provider-kind
kind-destroy: deps-kind
	@docker rm -f cloud-provider-kind 2>/dev/null || true
	@# Prune cloud-provider-kind's per-Service `kindccm-<hash>` Envoy sidecars.
	@# Removing the controller above does NOT remove them; orphans hold IPs in the
	@# kind Docker subnet and a later kind-up can inherit a stale Envoy config
	@# (pointed at dead pods) -> "Connection reset by peer" on first e2e curl.
	@docker ps -aq --filter name=kindccm- | xargs -r docker rm -f 2>/dev/null || true
	@kind delete cluster --name $(KIND_CLUSTER_NAME) 2>/dev/null || true
	@echo "KinD cluster '$(KIND_CLUSTER_NAME)' deleted."

#kind-up: @ Full cluster lifecycle (create + setup + deploy) — docker-compose-style alias for kind-deploy
kind-up: kind-deploy

#kind-down: @ Tear down the Kind cluster — docker-compose-style alias for kind-destroy
kind-down: kind-destroy

# ---------------------------------------------------------------------------
# E2E
# ---------------------------------------------------------------------------

#e2e: @ Run full end-to-end test cycle (create, setup, deploy, test, destroy)
# kind-deploy already chains kind-create → kind-setup → image-build → image-load,
# so listing them as separate prereqs is redundant.
e2e: kind-deploy e2e-test
	@$(MAKE) kind-destroy

#e2e-test: @ Run end-to-end test script
e2e-test: deps-kubectl
	@KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) ./e2e/e2e-test.sh

#populate: @ Populate test data via gateway
populate: deps-docker deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	BASE_URL="http://$$EXTERNAL_IP:$(GATEWAY_PORT)"; \
	echo "Gateway URL: $$BASE_URL"; \
	echo "Adding employees..."; \
	curl -sf -X POST "$$BASE_URL/employee/" -H "Content-Type: application/json" \
		-d '{"age":25,"departmentId":1,"name":"Smith","organizationId":1,"position":"engineer"}'; \
	echo ""; \
	curl -sf -X POST "$$BASE_URL/employee/" -H "Content-Type: application/json" \
		-d '{"age":45,"departmentId":1,"name":"Johns","organizationId":1,"position":"manager"}'; \
	echo ""; \
	echo "Adding department..."; \
	curl -sf -X POST "$$BASE_URL/department/" -H "Content-Type: application/json" \
		-d '{"name":"RD Dept.","organizationId":1}'; \
	echo ""; \
	echo "Adding organization..."; \
	curl -sf -X POST "$$BASE_URL/organization/" -H "Content-Type: application/json" \
		-d '{"name":"MegaCorp","address":"Main Street"}'; \
	echo ""

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

#gateway-url: @ Print gateway LoadBalancer URL
gateway-url: deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "http://$$EXTERNAL_IP:$(GATEWAY_PORT)"

#gateway-open: @ Open Swagger UI in browser
gateway-open: deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	$(OPEN_CMD) "http://$$EXTERNAL_IP:$(GATEWAY_PORT)/swagger-ui.html"

#jaeger-open: @ Open Jaeger tracing UI in browser
jaeger-open: deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc jaeger -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	$(OPEN_CMD) "http://$$EXTERNAL_IP:$(JAEGER_UI_PORT)/"

#logs-employee: @ Tail employee service logs
logs-employee: deps-kubectl
	@$(KUBECTL) logs -f -l app=employee -n employee

#logs-department: @ Tail department service logs
logs-department: deps-kubectl
	@$(KUBECTL) logs -f -l app=department -n department

#logs-organization: @ Tail organization service logs
logs-organization: deps-kubectl
	@$(KUBECTL) logs -f -l app=organization -n organization

#logs-gateway: @ Tail gateway service logs
logs-gateway: deps-kubectl
	@$(KUBECTL) logs -f -l app=gateway -n gateway

# ---------------------------------------------------------------------------
# CI
# ---------------------------------------------------------------------------

#ci: @ Run full local CI pipeline
# `coverage-generate` runs the full unit suite (`mvn test` + jacoco:report), so a
# standalone `test` prereq would execute the whole suite a second time — omitted.
ci: deps static-check integration-test coverage-generate coverage-check build cve-check deps-prune-check
	@echo "=== CI Complete ==="

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@docker container prune -f 2>/dev/null || true
	@# Pick a random high port for the artifact server so concurrent
	@# `make ci-run` invocations across different repos don't race on
	@# act's default 34567. --artifact-server-path uses a per-run temp
	@# dir for the same reason (default /tmp/act-artifacts is host-global).
	@ACT_PORT=$$(shuf -i 40000-59999 -n 1); \
	secret_args=(); \
	[ -n "$$NVD_API_KEY" ] && secret_args+=(--secret NVD_API_KEY); \
	[ -n "$$OSS_INDEX_USER" ] && secret_args+=(--secret OSS_INDEX_USER); \
	[ -n "$$OSS_INDEX_TOKEN" ] && secret_args+=(--secret OSS_INDEX_TOKEN); \
	if [ -z "$$GITHUB_TOKEN" ] && command -v gh >/dev/null 2>&1; then \
		export GITHUB_TOKEN="$$(gh auth token 2>/dev/null)"; \
	fi; \
	[ -n "$$GITHUB_TOKEN" ] && secret_args+=(--secret GITHUB_TOKEN); \
	act push --container-architecture linux/amd64 \
		--pull=false \
		--artifact-server-port "$$ACT_PORT" \
		--artifact-server-path "$$(mktemp -d -t act-artifacts.XXXXXX)" \
		--var ACT=true \
		"$${secret_args[@]}"

#release: @ Create a release (usage: make release VERSION=x.y.z)
release: deps
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required (e.g., make release VERSION=1.0.0)"; \
		exit 1; \
	fi
	@if ! echo "$(VERSION)" | grep -qE '$(SEMVER_RE)'; then \
		echo "Error: VERSION must be valid semver (e.g., 1.0.0 -> creates tag v1.0.0)"; \
		exit 1; \
	fi
	@echo "Releasing version $(VERSION) (current: $(CURRENTTAG))..."
	@echo -n "Proceed? [y/N] " && read ans && [ "$${ans:-N}" = y ] || { echo "Aborted."; exit 1; }
	@git tag v$(VERSION)
	@git push origin v$(VERSION)
	@git push
	@echo "Release $(VERSION) complete."

# ---------------------------------------------------------------------------
# Renovate
# ---------------------------------------------------------------------------

#renovate-bootstrap: @ Install mise + Node ($(NODE_VERSION) per .nvmrc) for renovate-validate
renovate-bootstrap:
	@if [ -z "$$CI" ] && ! command -v mise >/dev/null 2>&1; then \
		echo "Installing mise (https://mise.jdx.dev/)..."; \
		curl -fsSL https://mise.run | sh; \
	fi
	@command -v node >/dev/null 2>&1 || { \
		command -v mise >/dev/null 2>&1 || { echo "Error: node and mise unavailable (CI skips mise bootstrap)"; exit 1; }; \
		echo "Installing Node $(NODE_VERSION) via mise..."; \
		mise install node; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@[ -f renovate.json ] || { echo "Error: renovate.json not found"; exit 1; }
	@if [ -n "$$GH_ACCESS_TOKEN" ]; then \
		GITHUB_COM_TOKEN=$$GH_ACCESS_TOKEN npx --yes renovate@latest --platform=local; \
	else \
		echo "Warning: GH_ACCESS_TOKEN not set, some dependency lookups may fail"; \
		npx --yes renovate@latest --platform=local; \
	fi

.PHONY: help \
	deps deps-install deps-check deps-docker deps-kubectl deps-kind deps-act \
	deps-updates deps-update deps-prune deps-prune-check \
	clean build test integration-test lint format format-check \
	lint-ci lint-docker secrets trivy-fs trivy-config \
	diagrams diagrams-check diagrams-clean mermaid-lint \
	maven-settings-ossindex cve-check \
	coverage-generate coverage-check coverage-open static-check \
	image-build image-load container-structure-test \
	kind-create kind-setup kind-deploy kind-undeploy kind-redeploy kind-destroy kind-up kind-down \
	e2e e2e-test populate \
	gateway-url gateway-open jaeger-open \
	logs-employee logs-department logs-organization logs-gateway \
	ci ci-run release \
	renovate-bootstrap renovate-validate
