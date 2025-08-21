# Homelab Terraform Makefile

# Variables
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
# Set tofu command
TOFU := tofu
KUBECTL := kubectl
VAULT := bao
TF_PROJECT_ROOT := $(shell pwd)/terraform

# Extract Hetzner Cloud credentials
HCLOUD_TOKEN := $(shell grep hcloud_token "$(TF_PROJECT_ROOT)/terraform.tfvars" | cut -d '=' -f2 | tr -d '" ')

# Standard Tofu commands
# Allow targeting specific modules with MODULE=module_name
.PHONY: tf-init
tf-init: ## Initialize Terraform/OpenTofu configuration
	$(TOFU) -chdir=$(TF_PROJECT_ROOT) init $(if $(MODULE),-target=module.$(MODULE),)

.PHONY: tf-plan
tf-plan: ## Show planned changes to infrastructure
	$(TOFU) -chdir=$(TF_PROJECT_ROOT) plan $(if $(MODULE),-target=module.$(MODULE),)

.PHONY: tf-apply
tf-apply: ## Apply changes to infrastructure
	TF_CLI_ARGS_apply="-parallelism=5" $(TOFU) -chdir=$(TF_PROJECT_ROOT) apply $(if $(AUTO_APPROVE),-auto-approve,) $(if $(MODULE),-target=module.$(MODULE),)

.PHONY: tf-destroy
tf-destroy: ## Destroy infrastructure
	TF_CLI_ARGS_destroy="-parallelism=5" $(TOFU) -chdir=$(TF_PROJECT_ROOT) destroy $(if $(MODULE),-target=module.$(MODULE),)

.PHONY: tf-output
tf-output: ## Show Terraform outputs
	$(TOFU) -chdir=$(TF_PROJECT_ROOT) output $(if $(MODULE),module.$(MODULE),)

.PHONY: tf-validate
tf-validate: ## Validate Terraform syntax
	$(TOFU) -chdir=$(TF_PROJECT_ROOT) validate

# Extended Terraform/OpenTofu validation commands
.PHONY: tf-validate-full tf-validate-lint tf-validate-fmt tf-validate-docs tf-fmt
tf-validate-full: tf-validate tf-validate-lint tf-validate-fmt tf-validate-docs ## Run all validations (syntax, lint, format, docs)
	@echo "Full validation completed"

tf-fmt: ## Auto-format all Terraform files
	@echo "Auto-formatting Terraform files..."
	@$(TOFU) -chdir=$(TF_PROJECT_ROOT) fmt -recursive

tf-validate-lint: ## Run TFLint to check for issues
	@echo "Running TFLint..."
	@if command -v tflint >/dev/null 2>&1; then \
		tflint --recursive $(TF_PROJECT_ROOT) || echo "TFLint found issues"; \
	else \
		echo "TFLint not installed. Install with: brew install tflint"; \
		exit 1; \
	fi

tf-validate-fmt: ## Check Terraform files formatting
	@echo "Running OpenTofu fmt check..."
	@$(TOFU) -chdir=$(TF_PROJECT_ROOT) fmt -check -recursive

tf-validate-docs: ## Verify module documentation is up-to-date
	@echo "Checking modules documentation with terraform-docs..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		cd $(TF_PROJECT_ROOT) && find . -type d -name "*.terraform" -prune -o -type f -name "*.tf" -print | xargs dirname | sort -u | xargs -I{} terraform-docs md {} --output-check || echo "Some modules have outdated documentation"; \
	else \
		echo "terraform-docs not installed. Install with: brew install terraform-docs"; \
		exit 1; \
	fi
#
# Talos cluster configuration
# --------------------------
# Define talosctl command and config paths
TALOSCTL := talosctl
SCRIPTS_PATH := $(shell pwd)
TALOS_CONFIG_PATH := $(SCRIPTS_PATH)/generated/talosconfig
KUBE_CONFIG_PATH := $(SCRIPTS_PATH)/generated/kubeconfig

.PHONY: talos-bootstrap talos-prepare talos-install talos-generate-configs talos-apply-configs talos-bootstrap-cluster talos-get-kubeconfig talos-install-crds talos-reset-cluster talos-upgrade

talos-bootstrap: ## Bootstrap Talos cluster (TALOS_VERSION required)
	@if [ -z "$(TALOS_VERSION)" ]; then \
		echo "Usage: make talos-bootstrap TALOS_VERSION=<version>"; \
		echo "Example: make talos-bootstrap TALOS_VERSION=v1.7.1"; \
		exit 1; \
	fi
	@mkdir -p $(SCRIPTS_PATH)/generated
	@echo "Bootstrapping Talos cluster with version $(TALOS_VERSION)..."
	@# Use set +e to prevent make from exiting when the SSH connection is closed during reboots
	@set +e; \
	HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/bootstrap_cluster.sh $(TALOS_VERSION); \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "Bootstrap script exited with code $$EXIT_CODE"; \
		echo "This might be normal if SSH connections were closed during reboots."; \
		echo "Check the installed cluster with: make talos-health"; \
		echo "Or check individual nodes with: make talos CMD='version'"; \
	fi

# Stepped Talos bootstrap process (allows for step-by-step execution)
talos-prepare: ## Step 1: Prepare Talos environment (TALOS_VERSION required)
	@if [ -z "$(TALOS_VERSION)" ]; then \
		echo "Usage: make talos-prepare TALOS_VERSION=<version>"; \
		echo "Example: make talos-prepare TALOS_VERSION=v1.7.1"; \
		exit 1; \
	fi
	@mkdir -p $(SCRIPTS_PATH)/generated
	@echo "Step 1: Preparing environment for Talos installation with version $(TALOS_VERSION)..."
	@HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/1_prepare_environment.sh $(TALOS_VERSION)
	@echo "Environment preparation complete. You can now run 'make talos-install'."

talos-install:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run 'make talos-prepare TALOS_VERSION=<version>' first."; \
		exit 1; \
	fi
	@echo "Step 2: Installing Talos on all nodes..."
	@# Use set +e to prevent make from exiting when the SSH connection is closed during reboots
	@set +e; \
	HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/2_install_talos.sh; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -ne 0 ]; then \
		echo "Installation script exited with code $$EXIT_CODE"; \
		echo "This might be normal if SSH connections were closed during reboots."; \
	fi
	@echo "Talos installation complete. You can now run 'make talos-generate-configs'."

talos-generate-configs:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run 'make talos-prepare TALOS_VERSION=<version>' first."; \
		exit 1; \
	fi
	@echo "Step 3: Generating Talos configurations..."
	@REGENERATE_SECRETS=$(REGENERATE_SECRETS) $(SCRIPTS_PATH)/3_generate_configs.sh
	@echo "Configuration generation complete. You can now run 'make talos-apply-configs'."

talos-apply-configs:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run previous steps first."; \
		exit 1; \
	fi
	@if [ ! -f "$(SCRIPTS_PATH)/generated/controlplane.yaml" ]; then \
		echo "Error: controlplane.yaml not found. Run 'make talos-generate-configs' first."; \
		exit 1; \
	fi
	@echo "Step 4: Applying Talos configurations to all nodes..."
	@HCLOUD_TOKEN=$(HCLOUD_TOKEN) INSECURE=$(INSECURE) $(SCRIPTS_PATH)/4_apply_configs.sh
	@echo "Configuration application complete. You can now run 'make talos-bootstrap-cluster'."

talos-bootstrap-cluster:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run previous steps first."; \
		exit 1; \
	fi
	@echo "Step 5: Bootstrapping Talos cluster..."
	@HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/5_bootstrap_cluster.sh
	@echo "Cluster bootstrap complete. You can now run 'make talos-get-kubeconfig'."

talos-get-kubeconfig:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run previous steps first."; \
		exit 1; \
	fi
	@echo "Step 6: Retrieving kubeconfig and finalizing setup..."
	@HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/6_get_kubeconfig.sh
	@echo "Kubeconfig retrieved. You can now run 'make talos-install-crds'."

talos-reset-cluster:
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Run 'make talos-prepare TALOS_VERSION=<version>' first."; \
		exit 1; \
	fi
	@echo "WARNING: This will reset ALL nodes in your Talos cluster!"
	@echo "Running cluster reset script..."
	@HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/reset_cluster.sh

.PHONY: talos-config
talos-config:
	@if [ -f $(TALOS_CONFIG_PATH) ]; then \
		mkdir -p ~/.talos; \
		cp $(TALOS_CONFIG_PATH) ~/.talos/config; \
		echo "Talos config copied to ~/.talos/config"; \
	else \
		echo "No talosconfig found at $(TALOS_CONFIG_PATH). Run 'make apply MODULE=talos' first."; \
	fi

.PHONY: talos-merge-kubeconfig
talos-merge-kubeconfig:
	@if [ ! -f $(KUBE_CONFIG_PATH) ]; then \
		echo "No kubeconfig found at $(KUBE_CONFIG_PATH). Run 'make talos-get-kubeconfig' first."; \
		exit 1; \
	fi
	@echo "Processing Talos kubeconfig..."
	@mkdir -p ~/.kube
	@if [ ! -f ~/.kube/config ]; then \
		echo "No existing kubeconfig found. Creating a new one."; \
		cp $(KUBE_CONFIG_PATH) ~/.kube/config; \
		echo "Kubeconfig copied to ~/.kube/config"; \
		echo "Current available contexts:"; \
		kubectl config get-contexts; \
	else \
		BACKUP=~/.kube/config.backup.$$(date +%Y%m%d%H%M%S); \
		echo "Creating backup of existing kubeconfig at $$BACKUP"; \
		cp ~/.kube/config $$BACKUP; \
		echo "Merging configurations..."; \
		KUBECONFIG=~/.kube/config:$(KUBE_CONFIG_PATH) kubectl config view --flatten > ~/.kube/config.merged; \
		mv ~/.kube/config.merged ~/.kube/config; \
		echo "Kubeconfig merged successfully."; \
		echo "Current available contexts:"; \
		kubectl config get-contexts; \
	fi

.PHONY: talos
talos:
	@if [ -z "$(CMD)" ]; then \
		echo "Usage: make talos CMD='command [args]' [TALOS_NODE_IP=<node-ip>]"; \
		echo "Example: make talos CMD='version'"; \
		echo "Example: make talos CMD='dashboard'"; \
		echo "Example: make talos CMD='upgrade' TALOS_NODE_IP=10.0.0.1"; \
		echo "Example: make talos CMD='logs kubelet' TALOS_NODE_IP=10.0.0.1"; \
		exit 1; \
	fi
	@if [ ! -f $(TALOS_CONFIG_PATH) ]; then \
		echo "No talosconfig found at $(TALOS_CONFIG_PATH). Run 'make apply MODULE=talos' first."; \
		exit 1; \
	fi
	@if [ -n "$(TALOS_NODE_IP)" ]; then \
		echo "Running talosctl $(CMD) on node $(TALOS_NODE_IP) using config at $(TALOS_CONFIG_PATH)"; \
		TALOSCONFIG=$(TALOS_CONFIG_PATH) $(TALOSCTL) -n $(TALOS_NODE_IP) -e $(TALOS_NODE_IP) $(CMD); \
	else \
		echo "Running talosctl $(CMD) using config at $(TALOS_CONFIG_PATH)"; \
		TALOSCONFIG=$(TALOS_CONFIG_PATH) $(TALOSCTL) $(CMD); \
	fi

.PHONY: talos-health
talos-health:
	@if [ ! -f $(TALOS_CONFIG_PATH) ]; then \
		echo "No talosconfig found at $(TALOS_CONFIG_PATH). Run 'make apply MODULE=talos' first."; \
		exit 1; \
	fi
	@echo "Checking Talos cluster health..."
	@TALOSCONFIG=$(TALOS_CONFIG_PATH) HCLOUD_TOKEN=$(HCLOUD_TOKEN) $(SCRIPTS_PATH)/talos_health.sh

.PHONY: talos-etcd-snapshot
talos-etcd-snapshot: ## Create etcd snapshots for each control plane node
	@$(SCRIPTS_PATH)/etcd_snapshot.sh

talos-upgrade: ## Upgrade Talos cluster with custom image (TALOS_VERSION optional)
	@if [ ! -f "$(SCRIPTS_PATH)/generated/cluster_info.env" ]; then \
		echo "Error: cluster_info.env not found. Cluster must be configured first."; \
		exit 1; \
	fi
	@if [ ! -f $(TALOS_CONFIG_PATH) ]; then \
		echo "Error: talosconfig not found at $(TALOS_CONFIG_PATH). Cluster must be configured first."; \
		exit 1; \
	fi
	@echo "Upgrading Talos cluster with custom image..."
	@$(SCRIPTS_PATH)/upgrade_talos.sh $(TALOS_VERSION)

# Hetzner Cloud commands - ensure token is passed
.PHONY: hcloud
hcloud: ## Run Hetzner Cloud CLI commands
	@if [ -z "$(CMD)" ]; then \
		echo "Usage: make hcloud CMD='command [args]'"; \
		echo "Example: make hcloud CMD='server list'"; \
	else \
		HCLOUD_TOKEN=$(HCLOUD_TOKEN) hcloud $(CMD); \
	fi


# Auto-generated help system
.PHONY: help
help:
	@echo "Homelab Terraform Makefile"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Module targeting:"
	@echo "  make tf-plan MODULE=talos    - Target specific module"
	@echo "  make tf-apply MODULE=talos   - Target specific module"
	@echo "  make tf-output MODULE=talos  - Show outputs from specific module"
	@echo ""
	@echo "Auto-approve:"
	@echo "  make tf-apply AUTO_APPROVE=yes - Skip approval prompt"

.PHONY: validate-cilium-gateway
validate-cilium-gateway: ## Validate Cilium Gateway configuration
	@echo "Validating Cilium Gateway configuration..."
	@KUBECONFIG=$(KUBE_CONFIG_PATH) $(SCRIPTS_PATH)/validate-cilium-gateway.sh

# Default target
.DEFAULT_GOAL := help
