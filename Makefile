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

# Detect macOS for 'open' vs 'xdg-open'
OPEN_CMD := $(if $(filter Darwin,$(shell uname -s)),open,xdg-open)

# Semver regex for release validation
SEMVER_RE := ^[0-9]+\.[0-9]+\.[0-9]+$$

# === Tool Versions (pinned) ===
# Java, Maven, and Node are pinned in .mise.toml (Renovate-tracked there via
# inline # renovate: comments). .java-version and .nvmrc remain the sources
# of truth for CI setup-java/setup-node actions.
# MAVEN_VER below is kept because `deps-maven` (CI containers without mise)
# still installs Maven via curl. The single pin is duplicated in .mise.toml
# and kept in sync by Renovate's maven PR updating both files together.
# renovate: datasource=github-tags depName=apache/maven extractVersion=^maven-(?<version>.*)$
MAVEN_VER    := 3.9.14
# renovate: datasource=github-releases depName=kubernetes-sigs/kind extractVersion=^v(?<version>.*)$
KIND_VERSION      := 0.31.0
# Not Renovate-tracked: must match a Kubernetes version shipped by the pinned KIND_VERSION.
# Kind 0.31.0 supports: v1.35.0 (default), v1.34.3, v1.33.7, v1.32.11, v1.31.14.
# Bump together with KIND_VERSION per kind release notes.
KIND_NODE_IMAGE   := v1.35.0
# renovate: datasource=github-releases depName=metallb/metallb extractVersion=^v(?<version>.*)$
METALLB_VERSION   := 0.15.3
# renovate: datasource=github-releases depName=nektos/act extractVersion=^v(?<version>.*)$
ACT_VERSION       := 0.2.87
# renovate: datasource=github-releases depName=hadolint/hadolint extractVersion=^v(?<version>.*)$
HADOLINT_VERSION  := 2.14.0
# renovate: datasource=github-releases depName=google/google-java-format extractVersion=^v(?<version>.*)$
GJF_VERSION       := 1.35.0
# renovate: datasource=github-releases depName=zricethezav/gitleaks extractVersion=^v(?<version>.*)$
GITLEAKS_VERSION  := 8.30.1
# renovate: datasource=github-releases depName=aquasecurity/trivy extractVersion=^v(?<version>.*)$
TRIVY_VERSION     := 0.69.3
# renovate: datasource=github-releases depName=rhysd/actionlint extractVersion=^v(?<version>.*)$
ACTIONLINT_VERSION := 1.7.12
# renovate: datasource=github-releases depName=koalaman/shellcheck extractVersion=^v(?<version>.*)$
SHELLCHECK_VERSION := 0.11.0
# Source of truth: .nvmrc (major version only, e.g., "22"); not Renovate-trackable.
# Pinned in .mise.toml too; mise reads .nvmrc natively.
NODE_VERSION      := $(shell cat .nvmrc 2>/dev/null || echo 22)
# renovate: datasource=docker depName=plantuml/plantuml
PLANTUML_VERSION    := 1.2026.2
# renovate: datasource=docker depName=minlag/mermaid-cli
MERMAID_CLI_VERSION := 11.12.0

# Source of truth: .java-version (read by CI via java-version-file); not Renovate-trackable.
# Used by deps target to verify the installed Java major matches the project.
JAVA_MAJOR        := $(shell cat .java-version 2>/dev/null || echo 25)

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

#deps: @ Check required tools (java, mvn)
deps:
	@java -version 2>&1 | grep -q '"$(JAVA_MAJOR)\.' || { echo "Error: Java $(JAVA_MAJOR) required. Run: make deps-install"; exit 1; }
	@command -v mvn >/dev/null 2>&1 || { echo "Error: Maven required. Run: make deps-install"; exit 1; }

#deps-maven: @ Install Maven if not present (for CI containers without mise)
deps-maven:
	@command -v mvn >/dev/null 2>&1 || { \
		echo "Installing Maven $(MAVEN_VER)..."; \
		mkdir -p $$HOME/.local/bin $$HOME/.local/opt; \
		curl -fsSL "https://archive.apache.org/dist/maven/maven-3/$(MAVEN_VER)/binaries/apache-maven-$(MAVEN_VER)-bin.tar.gz" | tar xz -C $$HOME/.local/opt; \
		ln -sf "$$HOME/.local/opt/apache-maven-$(MAVEN_VER)/bin/mvn" $$HOME/.local/bin/mvn; \
	}

#deps-install: @ Install mise and the toolchain pinned in .mise.toml (Java, Maven, Node)
deps-install:
	@if [ -z "$$CI" ] && ! command -v mise >/dev/null 2>&1; then \
		echo "Installing mise (https://mise.jdx.dev/)..."; \
		curl -fsSL https://mise.run | sh; \
	fi
	@command -v mise >/dev/null 2>&1 || { echo "Error: mise not available (CI skips bootstrap; use setup-java + deps-maven instead)"; exit 1; }
	@echo "Installing toolchain from .mise.toml..."
	@mise install
	@echo ""
	@echo "Toolchain installed. Shims are on PATH via the Makefile; for your"
	@echo "shell, add:  eval \"\$$(mise activate bash)\"   (or zsh/fish)"

#deps-check: @ Show required tools and installation status
deps-check:
	@echo "--- Tool status ---"
	@for tool in java mvn docker kubectl kind act hadolint gitleaks trivy actionlint shellcheck node; do \
		printf "  %-16s " "$$tool:"; \
		command -v $$tool >/dev/null 2>&1 && echo "installed" || echo "NOT installed"; \
	done
	@echo "--- mise ---"
	@command -v mise >/dev/null 2>&1 && echo "  installed ($$(mise --version))" || echo "  NOT installed (run: make deps-install)"

#deps-docker: @ Check Docker (used by diagrams, mermaid-lint, image-build, Testcontainers)
deps-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker required. See https://docs.docker.com/get-docker/"; exit 1; }

#deps-kubectl: @ Check kubectl (required for Kind cluster targets)
deps-kubectl:
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl required. See https://kubernetes.io/docs/tasks/tools/"; exit 1; }

#deps-kind: @ Install KinD for local Kubernetes testing
deps-kind: deps deps-docker deps-kubectl
	@command -v kind >/dev/null 2>&1 || { echo "Installing kind $(KIND_VERSION)..."; \
		if command -v go >/dev/null 2>&1; then \
			go install sigs.k8s.io/kind@v$(KIND_VERSION); \
		else \
			mkdir -p $$HOME/.local/bin && \
			curl -Lo $$HOME/.local/bin/kind https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-linux-amd64 && \
			chmod +x $$HOME/.local/bin/kind && \
			echo "Installed to $$HOME/.local/bin/kind — ensure ~/.local/bin is on PATH"; \
		fi; \
	}

#deps-act: @ Install act for local CI runs
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b $$HOME/.local/bin v$(ACT_VERSION); \
	}

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint $$HOME/.local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-gitleaks: @ Install gitleaks for secret scanning
deps-gitleaks:
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks $(GITLEAKS_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL https://github.com/zricethezav/gitleaks/releases/download/v$(GITLEAKS_VERSION)/gitleaks_$(GITLEAKS_VERSION)_linux_x64.tar.gz | \
		tar xz -C $$HOME/.local/bin gitleaks; \
	}

#deps-trivy: @ Install Trivy for vulnerability and misconfig scanning
deps-trivy:
	@command -v trivy >/dev/null 2>&1 || { echo "Installing trivy $(TRIVY_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $$HOME/.local/bin v$(TRIVY_VERSION) && \
		echo "Installed to $$HOME/.local/bin/trivy — ensure ~/.local/bin is on PATH"; \
	}

#deps-actionlint: @ Install actionlint for GitHub Actions linting
deps-actionlint:
	@command -v actionlint >/dev/null 2>&1 || { echo "Installing actionlint $(ACTIONLINT_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL -o /tmp/actionlint.tar.gz https://github.com/rhysd/actionlint/releases/download/v$(ACTIONLINT_VERSION)/actionlint_$(ACTIONLINT_VERSION)_linux_amd64.tar.gz && \
		tar -xzf /tmp/actionlint.tar.gz -C $$HOME/.local/bin actionlint && \
		rm -f /tmp/actionlint.tar.gz && \
		echo "Installed to $$HOME/.local/bin/actionlint — ensure ~/.local/bin is on PATH"; \
	}

#deps-shellcheck: @ Install shellcheck for shell script linting (used by actionlint)
deps-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Installing shellcheck $(SHELLCHECK_VERSION)..."; \
		mkdir -p $$HOME/.local/bin && \
		curl -sSfL -o /tmp/shellcheck.tar.xz https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).linux.x86_64.tar.xz && \
		tar -xJf /tmp/shellcheck.tar.xz -C /tmp && \
		install -m 755 /tmp/shellcheck-v$(SHELLCHECK_VERSION)/shellcheck $$HOME/.local/bin/shellcheck && \
		rm -rf /tmp/shellcheck-v$(SHELLCHECK_VERSION) /tmp/shellcheck.tar.xz && \
		echo "Installed to $$HOME/.local/bin/shellcheck — ensure ~/.local/bin is on PATH"; \
	}

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

$(GJF_JAR):
	@mkdir -p $(dir $(GJF_JAR))
	@echo "Downloading google-java-format $(GJF_VERSION)..."
	@curl -sSfL -o $(GJF_JAR) $(GJF_URL)

#format: @ Auto-format Java source code (Google style)
format: deps $(GJF_JAR)
	@find . -path '*/src/main/java/*.java' -o -path '*/src/test/java/*.java' | \
		xargs java --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
			-jar $(GJF_JAR) --replace
	@echo "Formatted all Java files with Google style."

#format-check: @ Verify code formatting (CI gate)
format-check: deps $(GJF_JAR)
	@find . -path '*/src/main/java/*.java' -o -path '*/src/test/java/*.java' | \
		xargs java --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
			--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
			-jar $(GJF_JAR) --set-exit-if-changed --dry-run > /dev/null

# ---------------------------------------------------------------------------
# Code Quality
# ---------------------------------------------------------------------------

#lint-docker: @ Lint all Dockerfiles with hadolint
lint-docker: deps-hadolint
	@for svc in $(SERVICES); do \
		echo "Linting $$svc-service/Dockerfile..."; \
		hadolint $$svc-service/Dockerfile; \
	done

#secrets: @ Scan for hardcoded secrets
secrets: deps-gitleaks
	@gitleaks detect --source . --verbose --redact --no-git

#trivy-fs: @ Scan filesystem for vulnerabilities, secrets, and misconfigurations
trivy-fs: deps-trivy
	@trivy fs --scanners vuln,secret,misconfig --severity CRITICAL,HIGH \
		--skip-dirs target --skip-dirs .git .

#trivy-config: @ Scan Kubernetes manifests for security misconfigurations (KSV-*)
trivy-config: deps-trivy
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
	FAILED=0; \
	for md in $$MD_FILES; do \
		echo "Validating Mermaid blocks in $$md..."; \
		LOG=$$(mktemp); \
		if docker run --rm -v "$$PWD:/data" \
			minlag/mermaid-cli:$(MERMAID_CLI_VERSION) \
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
lint-ci: deps-actionlint deps-shellcheck
	@actionlint

#maven-settings-ossindex: @ Create Maven settings for OSS Index credentials
maven-settings-ossindex:
	@if [ -n "$$OSS_INDEX_USER" ] && [ -n "$$OSS_INDEX_TOKEN" ]; then \
		mkdir -p ~/.m2 && \
		printf '<settings>\n  <servers>\n    <server>\n      <id>ossindex</id>\n      <username>%s</username>\n      <password>%s</password>\n    </server>\n  </servers>\n</settings>\n' "$$OSS_INDEX_USER" "$$OSS_INDEX_TOKEN" > ~/.m2/settings.xml; \
	fi

#cve-check: @ Run OWASP dependency vulnerability scan
cve-check: deps maven-settings-ossindex
	@mvn -B org.owasp:dependency-check-maven:check \
		$$([ -n "$$NVD_API_KEY" ] && echo "-DnvdApiKey=$$NVD_API_KEY")

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
static-check: format-check diagrams-check mermaid-lint lint-ci lint lint-docker secrets trivy-fs trivy-config
	@echo "Static check passed."

# ---------------------------------------------------------------------------
# Docker Images
# ---------------------------------------------------------------------------

#image-build: @ Build Docker images for all services
image-build: deps-docker build
	@for svc in $(SERVICES); do \
		echo "Building $$svc:$(IMAGE_TAG)..."; \
		BUILDX_BUILDER=default docker buildx build --load --build-arg VARIANT=debug -t $$svc:$(IMAGE_TAG) -f $$svc-service/Dockerfile $$svc-service/; \
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

#kind-create: @ Create local KinD cluster with MetalLB
kind-create: deps-kind
	@if kind get clusters 2>/dev/null | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "KinD cluster '$(KIND_CLUSTER_NAME)' already exists..."; \
		kubectl config use-context kind-$(KIND_CLUSTER_NAME); \
	else \
		echo "Creating KinD cluster with node image kindest/node:$(KIND_NODE_IMAGE)..."; \
		kind create cluster \
			--config=k8s/kind-config.yaml \
			--name $(KIND_CLUSTER_NAME) \
			--image=kindest/node:$(KIND_NODE_IMAGE) \
			--wait 60s; \
	fi
	@echo "Installing MetalLB $(METALLB_VERSION)..."
	@kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$(METALLB_VERSION)/config/manifests/metallb-native.yaml
	@echo "Waiting for MetalLB controller..."
	@kubectl rollout status deployment/controller -n metallb-system --timeout=180s
	@echo "Waiting for MetalLB speaker..."
	@kubectl rollout status daemonset/speaker -n metallb-system --timeout=180s
	@echo "Configuring MetalLB IP pool..."
	@ip_sub=$$(docker network inspect kind -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk -F. '{printf "%d.%d", $$1, $$2}'); \
	sed "s/METALLB_IP_SUB/$$ip_sub/g" k8s/metallb-config.yaml | kubectl apply -f -

#kind-setup: @ Create namespaces, RBAC, service accounts, and deploy MongoDB
kind-setup: deps-docker deps-kubectl
	@echo "Creating namespaces..."
	@for ns in department employee gateway organization mongo observability; do \
		kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f -; \
	done
	@echo "Applying RBAC cluster role..."
	@kubectl apply -f k8s/rbac-cluster-role.yaml
	@echo "Creating service accounts and role bindings..."
	@for ns in department employee gateway organization mongo observability; do \
		kubectl create serviceaccount $(SA_NAME) -n $$ns --dry-run=client -o yaml | kubectl apply -f -; \
		kubectl create clusterrolebinding $(SA_NAME)-$$ns \
			--clusterrole=microservices-kubernetes-namespace-reader \
			--serviceaccount=$$ns:$(SA_NAME) \
			--dry-run=client -o yaml | kubectl apply -f -; \
	done
	@echo "Deploying MongoDB..."
	@kubectl apply -f k8s/mongodb-configmap.yaml -n mongo
	@kubectl apply -f k8s/mongodb-secret.yaml -n mongo
	@kubectl apply -f k8s/mongodb-deployment.yaml -n mongo
	@echo "Deploying Jaeger (tracing backend)..."
	@kubectl apply -f k8s/jaeger-config.yaml -n observability
	@kubectl apply -f k8s/jaeger-deployment.yaml -n observability
	@echo "Waiting for MongoDB rollout..."
	@kubectl rollout status deployment/mongodb -n mongo --timeout=120s
	@echo "Waiting for Jaeger rollout..."
	@kubectl rollout status deployment/jaeger -n observability --timeout=120s

#kind-deploy: @ Build, load images, deploy all services, and wait for rollout
kind-deploy: kind-create kind-setup image-build
	@$(MAKE) image-load
	@echo "Deploying services..."
	@for svc in employee department organization; do \
		echo "Deploying $$svc..."; \
		kubectl apply -f k8s/$$svc-configmap.yaml -n $$svc; \
		kubectl apply -f k8s/$$svc-secret.yaml -n $$svc; \
		kubectl apply -f k8s/$$svc-deployment.yaml -n $$svc; \
	done
	@echo "Deploying gateway..."
	@kubectl apply -f k8s/gateway-configmap.yaml -n gateway
	@kubectl apply -f k8s/gateway-deployment.yaml -n gateway
	@echo "Waiting for deployments..."
	@for svc in $(SERVICES); do \
		echo "Waiting for $$svc rollout..."; \
		kubectl rollout status deployment/$$svc -n $$svc --timeout=300s; \
	done
	@echo "Waiting for gateway LoadBalancer IP..."
	@for i in $$(seq 1 30); do \
		EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); \
		if [ -n "$$EXTERNAL_IP" ] && [ "$$EXTERNAL_IP" != "<pending>" ]; then \
			echo "Gateway available at http://$$EXTERNAL_IP:8080"; \
			break; \
		fi; \
		echo "  waiting for LoadBalancer IP... ($$i/30)"; \
		sleep 2; \
	done

#kind-undeploy: @ Remove all services from KinD cluster
kind-undeploy: deps-docker deps-kubectl
	@for svc in employee department organization; do \
		echo "Removing $$svc..."; \
		kubectl delete -f k8s/$$svc-deployment.yaml -n $$svc --ignore-not-found=true; \
		kubectl delete -f k8s/$$svc-secret.yaml -n $$svc --ignore-not-found=true; \
		kubectl delete -f k8s/$$svc-configmap.yaml -n $$svc --ignore-not-found=true; \
	done
	@echo "Removing gateway..."
	@kubectl delete -f k8s/gateway-deployment.yaml -n gateway --ignore-not-found=true
	@kubectl delete -f k8s/gateway-configmap.yaml -n gateway --ignore-not-found=true

#kind-redeploy: @ Undeploy then deploy all services
kind-redeploy: kind-undeploy kind-deploy

#kind-destroy: @ Delete KinD cluster
kind-destroy: deps-kind
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
e2e: kind-create kind-setup kind-deploy e2e-test
	@$(MAKE) kind-destroy

#e2e-test: @ Run end-to-end test script
e2e-test:
	@./e2e/e2e-test.sh

#populate: @ Populate test data via gateway
populate: deps-docker deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	BASE_URL="http://$$EXTERNAL_IP:8080"; \
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
	echo "http://$$EXTERNAL_IP:8080"

#gateway-open: @ Open Swagger UI in browser
gateway-open: deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	$(OPEN_CMD) "http://$$EXTERNAL_IP:8080/swagger-ui.html"

#jaeger-open: @ Open Jaeger tracing UI in browser
jaeger-open: deps-kubectl
	@EXTERNAL_IP=$$(kubectl get svc jaeger -n observability -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	$(OPEN_CMD) "http://$$EXTERNAL_IP:16686/"

#logs-employee: @ Tail employee service logs
logs-employee: deps-kubectl
	@kubectl logs -f -l app=employee -n employee

#logs-department: @ Tail department service logs
logs-department: deps-kubectl
	@kubectl logs -f -l app=department -n department

#logs-organization: @ Tail organization service logs
logs-organization: deps-kubectl
	@kubectl logs -f -l app=organization -n organization

#logs-gateway: @ Tail gateway service logs
logs-gateway: deps-kubectl
	@kubectl logs -f -l app=gateway -n gateway

# ---------------------------------------------------------------------------
# CI
# ---------------------------------------------------------------------------

#ci: @ Run full local CI pipeline
ci: deps static-check test integration-test coverage-generate coverage-check build cve-check deps-prune-check
	@echo "=== CI Complete ==="

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@docker container prune -f 2>/dev/null || true
	@# Pick a random high port for the artifact server so concurrent
	@# `make ci-run` invocations across different repos don't race on
	@# act's default 34567. --artifact-server-path uses a per-run temp
	@# dir for the same reason (default /tmp/act-artifacts is host-global).
	@ACT_PORT=$$(shuf -i 40000-59999 -n 1); \
	act push --container-architecture linux/amd64 \
		--artifact-server-port "$$ACT_PORT" \
		--artifact-server-path "$$(mktemp -d -t act-artifacts.XXXXXX)" \
		--var ACT=true \
		$$([ -n "$$NVD_API_KEY" ] && echo "--secret NVD_API_KEY=$$NVD_API_KEY") \
		$$([ -n "$$OSS_INDEX_USER" ] && echo "--secret OSS_INDEX_USER=$$OSS_INDEX_USER") \
		$$([ -n "$$OSS_INDEX_TOKEN" ] && echo "--secret OSS_INDEX_TOKEN=$$OSS_INDEX_TOKEN")

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
		GITHUB_COM_TOKEN=$$GH_ACCESS_TOKEN npx --yes renovate --platform=local; \
	else \
		echo "Warning: GH_ACCESS_TOKEN not set, some dependency lookups may fail"; \
		npx --yes renovate --platform=local; \
	fi

.PHONY: help \
	deps deps-maven deps-install deps-check deps-docker deps-kubectl deps-kind deps-act \
	deps-hadolint deps-gitleaks deps-trivy deps-actionlint deps-shellcheck \
	deps-updates deps-update deps-prune deps-prune-check \
	clean build test integration-test lint format format-check \
	lint-ci lint-docker secrets trivy-fs trivy-config \
	diagrams diagrams-check diagrams-clean mermaid-lint \
	maven-settings-ossindex cve-check \
	coverage-generate coverage-check coverage-open static-check \
	image-build image-load \
	kind-create kind-setup kind-deploy kind-undeploy kind-redeploy kind-destroy kind-up kind-down \
	e2e e2e-test populate \
	gateway-url gateway-open jaeger-open \
	logs-employee logs-department logs-organization logs-gateway \
	ci ci-run release \
	renovate-bootstrap renovate-validate
