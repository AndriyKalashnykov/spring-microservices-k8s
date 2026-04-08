.DEFAULT_GOAL := help

MVN               := $(shell command -v mvn 2>/dev/null || echo ./mvnw)
KIND_CLUSTER_NAME := spring-microservices-k8s
SERVICES          := employee department organization gateway
IMAGE_TAG         := local
SA_NAME           := api-service-account
# renovate: datasource=github-releases depName=kubernetes-sigs/kind
KIND_VERSION      := 0.31.0
# renovate: datasource=github-releases depName=metallb/metallb
METALLB_VERSION   := 0.15.3
# renovate: datasource=github-releases depName=nektos/act
ACT_VERSION       := 0.2.87
# renovate: datasource=github-releases depName=hadolint/hadolint
HADOLINT_VERSION  := 2.14.0
# renovate: datasource=github-releases depName=zricethezav/gitleaks
GITLEAKS_VERSION  := 8.30.1

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND"
	@echo "Commands :"
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-20s\033[0m - %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

#build: @ Build all modules with Maven (skip tests)
build:
	@$(MVN) clean package -DskipTests

#clean: @ Clean all build artifacts
clean:
	@$(MVN) clean

#test: @ Run tests
test:
	@$(MVN) test

#lint: @ Run Checkstyle static analysis
lint:
	@$(MVN) checkstyle:check -Dcheckstyle.failOnViolation=false

#format: @ Auto-format Java source code
format:
	@$(MVN) io.spring.javaformat:spring-javaformat-maven-plugin:apply

#format-check: @ Verify code formatting (CI gate)
format-check:
	@$(MVN) io.spring.javaformat:spring-javaformat-maven-plugin:validate

#vulncheck: @ Check for known vulnerabilities in dependencies
vulncheck:
	@$(MVN) org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=9

#deps-prune: @ Check for unused Maven dependencies
deps-prune:
	@$(MVN) dependency:analyze -DignoreNonCompile=true 2>&1 | grep -E 'Unused|Used undeclared' || echo "No unused dependencies found."

# ---------------------------------------------------------------------------
# Image
# ---------------------------------------------------------------------------

#image-build: @ Build Docker images for all services
image-build: build
	@for svc in $(SERVICES); do \
		echo "Building $$svc:$(IMAGE_TAG)..."; \
		BUILDX_BUILDER=default docker buildx build --load -t $$svc:$(IMAGE_TAG) -f $$svc-service/Dockerfile.debug $$svc-service/; \
	done

#image-load: @ Load Docker images into KinD cluster
image-load:
	@for svc in $(SERVICES); do \
		echo "Loading $$svc:$(IMAGE_TAG) into cluster..."; \
		kind load docker-image $$svc:$(IMAGE_TAG) --name $(KIND_CLUSTER_NAME); \
	done

# ---------------------------------------------------------------------------
# Deps
# ---------------------------------------------------------------------------

#deps: @ Check required dependencies
deps:
	@command -v java >/dev/null 2>&1 || { echo "Error: java required. See https://adoptium.net/"; exit 1; }
	@command -v mvn >/dev/null 2>&1 || test -x ./mvnw || { echo "Error: mvn or ./mvnw required. See https://maven.apache.org/install.html"; exit 1; }

#deps-docker: @ Check Docker and kubectl
deps-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker required. See https://docs.docker.com/get-docker/"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl required. See https://kubernetes.io/docs/tasks/tools/"; exit 1; }

#deps-kind: @ Install KinD for local Kubernetes testing
deps-kind: deps deps-docker
	@command -v kind >/dev/null 2>&1 || { echo "Installing kind $(KIND_VERSION)..."; \
		if command -v go >/dev/null 2>&1; then \
			go install sigs.k8s.io/kind@v$(KIND_VERSION); \
		else \
			curl -Lo ./kind https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind; \
		fi; \
	}

#deps-act: @ Install act for local CI runs
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#deps-hadolint: @ Install hadolint for Dockerfile linting
deps-hadolint:
	@command -v hadolint >/dev/null 2>&1 || { echo "Installing hadolint $(HADOLINT_VERSION)..."; \
		curl -sSfL -o /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-Linux-x86_64 && \
		install -m 755 /tmp/hadolint /usr/local/bin/hadolint && \
		rm -f /tmp/hadolint; \
	}

#deps-gitleaks: @ Install gitleaks for secret scanning
deps-gitleaks:
	@command -v gitleaks >/dev/null 2>&1 || { echo "Installing gitleaks $(GITLEAKS_VERSION)..."; \
		curl -sSfL https://github.com/zricethezav/gitleaks/releases/download/v$(GITLEAKS_VERSION)/gitleaks_$(GITLEAKS_VERSION)_linux_x64.tar.gz | \
		tar xz -C /usr/local/bin gitleaks; \
	}

#lint-docker: @ Lint all Dockerfiles with hadolint
lint-docker: deps-hadolint
	@for svc in $(SERVICES); do \
		echo "Linting $$svc-service/Dockerfile..."; \
		hadolint $$svc-service/Dockerfile; \
		echo "Linting $$svc-service/Dockerfile.debug..."; \
		hadolint $$svc-service/Dockerfile.debug; \
	done

#secrets: @ Scan for hardcoded secrets
secrets: deps-gitleaks
	@gitleaks detect --source . --verbose --redact --no-git

# ---------------------------------------------------------------------------
# KinD Cluster
# ---------------------------------------------------------------------------

#kind-create: @ Create local KinD cluster with MetalLB
kind-create: deps-kind
	@if kind get clusters 2>/dev/null | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "KinD cluster '$(KIND_CLUSTER_NAME)' already exists..."; \
		kubectl config use-context kind-$(KIND_CLUSTER_NAME); \
	else \
		echo "Creating KinD cluster..."; \
		kind create cluster --config=k8s/kind-config.yaml --name $(KIND_CLUSTER_NAME) --wait 60s; \
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
kind-setup:
	@echo "Creating namespaces..."
	@for ns in department employee gateway organization mongo; do \
		kubectl create namespace $$ns --dry-run=client -o yaml | kubectl apply -f -; \
	done
	@echo "Applying RBAC cluster role..."
	@kubectl apply -f k8s/rbac-cluster-role.yaml
	@echo "Creating service accounts and role bindings..."
	@for ns in department employee gateway organization mongo; do \
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
	@echo "Waiting for MongoDB rollout..."
	@kubectl rollout status deployment/mongodb -n mongo --timeout=120s

#kind-deploy: @ Build, load images, deploy all services, and wait for rollout
kind-deploy: image-build
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
kind-undeploy:
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
kind-destroy:
	@kind delete cluster --name $(KIND_CLUSTER_NAME) 2>/dev/null || true
	@echo "KinD cluster '$(KIND_CLUSTER_NAME)' deleted."

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
populate:
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
gateway-url:
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	echo "http://$$EXTERNAL_IP:8080"

#gateway-open: @ Open Swagger UI in browser
gateway-open:
	@EXTERNAL_IP=$$(kubectl get svc gateway -n gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'); \
	xdg-open "http://$$EXTERNAL_IP:8080/swagger-ui.html"

#logs-employee: @ Tail employee service logs
logs-employee:
	@kubectl logs -f -l app=employee -n employee

#logs-department: @ Tail department service logs
logs-department:
	@kubectl logs -f -l app=department -n department

#logs-organization: @ Tail organization service logs
logs-organization:
	@kubectl logs -f -l app=organization -n organization

#logs-gateway: @ Tail gateway service logs
logs-gateway:
	@kubectl logs -f -l app=gateway -n gateway

# ---------------------------------------------------------------------------
# Static Analysis
# ---------------------------------------------------------------------------

#static-check: @ Run all quality and security checks
static-check: format-check lint lint-docker secrets
	@echo "Static check passed."

# ---------------------------------------------------------------------------
# CI
# ---------------------------------------------------------------------------

#ci: @ Run full local CI pipeline
ci: deps clean build static-check test
	@echo "Local CI pipeline passed."

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@docker container prune -f 2>/dev/null || true
	@act push --container-architecture linux/amd64

# ---------------------------------------------------------------------------
# Renovate
# ---------------------------------------------------------------------------

#renovate-validate: @ Validate Renovate configuration
renovate-validate:
	@command -v npx >/dev/null 2>&1 || { echo "Error: npx required (install Node.js)"; exit 1; }
	@if [ -n "$$GH_ACCESS_TOKEN" ]; then \
		GITHUB_COM_TOKEN=$$GH_ACCESS_TOKEN npx --yes renovate --platform=local; \
	else \
		echo "Warning: GH_ACCESS_TOKEN not set, some dependency lookups may fail"; \
		npx --yes renovate --platform=local; \
	fi

.PHONY: help build clean test lint \
	format format-check vulncheck deps-prune \
	image-build image-load \
	deps deps-docker deps-kind deps-act deps-hadolint deps-gitleaks \
	lint-docker secrets static-check \
	kind-create kind-setup kind-deploy kind-undeploy kind-redeploy kind-destroy \
	e2e e2e-test populate \
	gateway-url gateway-open \
	logs-employee logs-department logs-organization logs-gateway \
	ci ci-run renovate-validate
