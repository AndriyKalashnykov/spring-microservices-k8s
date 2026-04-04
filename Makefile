.PHONY: help build clean test package docker-build \
       cluster-start cluster-setup cluster-stop cluster-destroy \
       deploy undeploy populate gateway-open \
       lint ci

SHELL := /bin/bash

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build: package ## Build all modules (alias for package)

package: ## Build all modules with Maven
	mvn clean package

clean: ## Clean all build artifacts
	mvn clean

test: ## Run tests
	mvn test

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

docker-build: package ## Build Docker images for all services
	docker build -t gateway-debug:latest -f gateway-service/Dockerfile.debug gateway-service/
	docker build -t employee-debug:latest -f employee-service/Dockerfile.debug employee-service/
	docker build -t organization-debug:latest -f organization-service/Dockerfile.debug organization-service/
	docker build -t department-debug:latest -f department-service/Dockerfile.debug department-service/

# ---------------------------------------------------------------------------
# Cluster lifecycle
# ---------------------------------------------------------------------------

cluster-start: ## Start Minikube cluster
	./scripts/start-cluster.sh

cluster-setup: ## Configure cluster (namespaces, RBAC)
	./scripts/setup-cluster.sh

cluster-stop: ## Stop Minikube cluster
	./scripts/stop-cluster.sh

cluster-destroy: ## Remove cluster configuration
	./scripts/destroy-cluster.sh

# ---------------------------------------------------------------------------
# Application lifecycle
# ---------------------------------------------------------------------------

deploy: ## Deploy all services to Kubernetes
	./scripts/install-all.sh

undeploy: ## Undeploy all services from Kubernetes
	./scripts/delete-all.sh

populate: ## Populate test data
	./scripts/populate-data.sh

gateway-open: ## Open Swagger UI in browser
	./scripts/gateway-open.sh

# ---------------------------------------------------------------------------
# CI helpers
# ---------------------------------------------------------------------------

lint: ## Lint Maven project (validate phase)
	mvn validate

ci: clean test ## Run local CI pipeline (clean + test)
