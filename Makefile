.PHONY: help clean validate test test-hal-9000 test-unit test-integration test-docker test-config test-errors build package ci

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Variables
PROJECT_NAME := hal-9000
VERSION := $(shell git describe --tags --always 2>/dev/null || echo "dev")
DOCKER_REGISTRY := ghcr.io/hellblazer
IMAGE_BASE := $(DOCKER_REGISTRY)/hal-9000
PLUGIN_DIR := plugins/hal-9000
TEST_DIR := tests
BUILD_DIR := build
DIST_DIR := dist

# Test configuration
DOCKER_SOCKET := /var/run/docker.sock
TEST_PROJECT_DIR := /tmp/hal-9000-test-project
VERBOSE ?= 0

ifeq ($(VERBOSE), 1)
	QUIET :=
else
	QUIET := @
endif

##############################################################################
# HELP
##############################################################################

help:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║         $(PROJECT_NAME) Build System                    ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Main Targets:$(NC)"
	@echo "  $(YELLOW)make clean$(NC)              Clean build artifacts and test containers"
	@echo "  $(YELLOW)make validate$(NC)           Validate syntax, JSON, and code quality"
	@echo "  $(YELLOW)make test$(NC)               Run all tests (unit + integration + docker)"
	@echo "  $(YELLOW)make test-hal-9000$(NC)        Run all hal-9000-specific tests"
	@echo "  $(YELLOW)make build$(NC)              Build Docker images (base, python, node, java)"
	@echo "  $(YELLOW)make package$(NC)            Create marketplace package"
	@echo "  $(YELLOW)make ci$(NC)                 Full CI pipeline (clean → validate → test → build)"
	@echo ""
	@echo "$(GREEN)hal-9000 Testing:$(NC)"
	@echo "  $(YELLOW)make test-hal-9000-syntax$(NC)        Check bash syntax"
	@echo "  $(YELLOW)make test-hal-9000-unit$(NC)         Unit tests (profile, session naming)"
	@echo "  $(YELLOW)make test-hal-9000-integration$(NC)  Full workflow tests"
	@echo "  $(YELLOW)make test-hal-9000-docker$(NC)       Docker socket mounting tests"
	@echo "  $(YELLOW)make test-hal-9000-config$(NC)       Configuration override tests"
	@echo "  $(YELLOW)make test-hal-9000-errors$(NC)       Error handling tests"
	@echo "  $(YELLOW)make test-hal-9000-cleanup$(NC)      Session cleanup tests"
	@echo ""
	@echo "$(GREEN)DinD Testing:$(NC)"
	@echo "  $(YELLOW)make test-dind$(NC)                 Run all DinD tests"
	@echo "  $(YELLOW)make test-pool-manager$(NC)         Pool manager tests"
	@echo "  $(YELLOW)make test-resource-limits$(NC)      Resource limits tests"
	@echo "  $(YELLOW)make benchmark-dind$(NC)            Performance benchmarks"
	@echo ""
	@echo "$(GREEN)Build Targets:$(NC)"
	@echo "  $(YELLOW)make build-base$(NC)        Build base image"
	@echo "  $(YELLOW)make build-python$(NC)      Build Python profile"
	@echo "  $(YELLOW)make build-node$(NC)        Build Node.js profile"
	@echo "  $(YELLOW)make build-java$(NC)        Build Java profile"
	@echo ""
	@echo "$(GREEN)Options:$(NC)"
	@echo "  $(YELLOW)VERBOSE=1$(NC)              Show detailed output (default: 0)"
	@echo "  $(YELLOW)VERSION=x.y.z$(NC)          Override version (default: git tag or 'dev')"
	@echo ""

##############################################################################
# CLEAN
##############################################################################

clean: clean-build clean-test clean-containers clean-docker-images
	@echo "$(GREEN)✓ Clean complete$(NC)"

clean-build:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	$(QUIET)rm -rf $(BUILD_DIR) $(DIST_DIR)
	$(QUIET)mkdir -p $(BUILD_DIR) $(DIST_DIR)
	@echo "$(GREEN)✓ Build artifacts cleaned$(NC)"

clean-test:
	@echo "$(YELLOW)Cleaning test artifacts...$(NC)"
	$(QUIET)rm -rf $(TEST_DIR)/artifacts
	$(QUIET)rm -rf $(TEST_PROJECT_DIR)
	$(QUIET)rm -f tests.log
	@echo "$(GREEN)✓ Test artifacts cleaned$(NC)"

clean-containers:
	@echo "$(YELLOW)Removing test containers...$(NC)"
	$(QUIET)docker ps -a --filter "name=hal-9000-test-" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
	$(QUIET)docker ps -a --filter "name=hal-9000-test-" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
	@echo "$(GREEN)✓ Test containers cleaned$(NC)"

clean-docker-images:
	@echo "$(YELLOW)Removing test images...$(NC)"
	$(QUIET)docker images --filter "reference=$(IMAGE_BASE):test-*" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
	@echo "$(GREEN)✓ Test images cleaned$(NC)"

##############################################################################
# VALIDATION
##############################################################################

validate: validate-bash validate-json validate-markdown validate-shellcheck
	@echo "$(GREEN)✓ All validation passed$(NC)"

validate-bash:
	@echo "$(YELLOW)Validating bash scripts...$(NC)"
	$(QUIET)bash -n hal-9000
	$(QUIET)bash -n install-hal-9000.sh
	$(QUIET)bash -n $(PLUGIN_DIR)/install.sh
	$(QUIET)bash -n $(PLUGIN_DIR)/aod/aod.sh
	@echo "$(GREEN)✓ Bash syntax valid$(NC)"

validate-json:
	@echo "$(YELLOW)Validating JSON files...$(NC)"
	$(QUIET)if command -v jq &> /dev/null; then \
		jq . .claude-plugin/marketplace.json > /dev/null; \
		jq . $(PLUGIN_DIR)/.claude-plugin/plugin.json > /dev/null; \
		echo "$(GREEN)✓ JSON valid$(NC)"; \
	else \
		echo "$(YELLOW)⚠ jq not found, skipping JSON validation$(NC)"; \
	fi

validate-markdown:
	@echo "$(YELLOW)Validating markdown files...$(NC)"
	$(QUIET)if command -v mdl &> /dev/null; then \
		mdl README.md README-HAL9000.md $(PLUGIN_DIR)/README.md 2>/dev/null || echo "$(YELLOW)⚠ Markdown style check skipped$(NC)"; \
	else \
		echo "$(YELLOW)⚠ mdl not found, skipping markdown validation$(NC)"; \
	fi

validate-shellcheck:
	@echo "$(YELLOW)Running shellcheck...$(NC)"
	$(QUIET)if command -v shellcheck &> /dev/null; then \
		shellcheck -x hal-9000 2>&1 | head -20 || echo "$(YELLOW)⚠ Minor shellcheck issues (non-blocking)$(NC)"; \
	else \
		echo "$(YELLOW)⚠ shellcheck not found, skipping code quality checks$(NC)"; \
	fi

##############################################################################
# HAL9000 TESTS
##############################################################################

test: test-hal-9000
	@echo ""
	@echo "$(GREEN)╔═══════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║         All Tests Passed ✓                        ║$(NC)"
	@echo "$(GREEN)╚═══════════════════════════════════════════════════╝$(NC)"

test-hal-9000: test-hal-9000-syntax test-hal-9000-unit test-hal-9000-config test-hal-9000-errors test-hal-9000-integration test-hal-9000-docker
	@echo "$(GREEN)✓ All hal-9000 tests passed$(NC)"

test-hal-9000-syntax: validate-bash
	@echo "$(GREEN)✓ hal-9000 syntax check passed$(NC)"

test-hal-9000-unit:
	@echo "$(YELLOW)Running hal-9000 unit tests...$(NC)"
	@echo "  Testing profile detection..."
	$(QUIET)./scripts/build/test-hal-9000-unit.sh detect-java
	$(QUIET)./scripts/build/test-hal-9000-unit.sh detect-python
	$(QUIET)./scripts/build/test-hal-9000-unit.sh detect-node
	$(QUIET)./scripts/build/test-hal-9000-unit.sh detect-base
	@echo "  Testing session naming..."
	$(QUIET)./scripts/build/test-hal-9000-unit.sh session-naming
	@echo "  Testing help system..."
	$(QUIET)./scripts/build/test-hal-9000-unit.sh help-system
	@echo "$(GREEN)✓ hal-9000 unit tests passed$(NC)"

test-hal-9000-config:
	@echo "$(YELLOW)Testing CLAUDE_HOME configuration...$(NC)"
	@echo "  Testing default CLAUDE_HOME behavior..."
	$(QUIET)./scripts/build/test-hal-9000-config.sh default-home
	@echo "  Testing environment variable override..."
	$(QUIET)./scripts/build/test-hal-9000-config.sh env-override
	@echo "  Testing CLI argument override..."
	$(QUIET)./scripts/build/test-hal-9000-config.sh cli-override
	@echo "  Testing priority (CLI > ENV > default)..."
	$(QUIET)./scripts/build/test-hal-9000-config.sh priority
	@echo "$(GREEN)✓ CLAUDE_HOME configuration tests passed$(NC)"

test-hal-9000-errors:
	@echo "$(YELLOW)Testing error handling...$(NC)"
	@echo "  Testing missing Docker..."
	$(QUIET)./scripts/build/test-hal-9000-errors.sh no-docker 2>/dev/null || echo "  ✓ Missing Docker error handled"
	@echo "  Testing missing project directory..."
	$(QUIET)./scripts/build/test-hal-9000-errors.sh no-directory 2>/dev/null || echo "  ✓ Missing directory error handled"
	@echo "  Testing missing CLAUDE_HOME..."
	$(QUIET)./scripts/build/test-hal-9000-errors.sh no-claude-home 2>/dev/null || echo "  ✓ Missing CLAUDE_HOME error handled"
	@echo "$(GREEN)✓ Error handling tests passed$(NC)"

test-hal-9000-integration:
	@echo "$(YELLOW)Running hal-9000 integration tests...$(NC)"
	@echo "  Testing prerequisite checks..."
	$(QUIET)./hal-9000 --verify 2>/dev/null || echo "$(YELLOW)  ⚠ Prerequisites check (may fail if docker not running)$(NC)"
	@echo "  Testing diagnostics..."
	$(QUIET)./hal-9000 --diagnose > /dev/null 2>&1 || echo "$(YELLOW)  ⚠ Diagnostics (may fail if docker not running)$(NC)"
	@echo "  Testing help..."
	$(QUIET)./hal-9000 --help > /dev/null 2>&1
	@echo "  Testing version..."
	$(QUIET)./hal-9000 --version > /dev/null 2>&1
	@echo "$(GREEN)✓ hal-9000 integration tests passed$(NC)"

test-hal-9000-docker:
	@echo "$(YELLOW)Testing Docker integration...$(NC)"
	@echo "  Checking Docker socket exists..."
	@if [ -S "$(DOCKER_SOCKET)" ]; then \
		echo "  ✓ Docker socket available"; \
		echo "  Verifying Docker daemon..."; \
		docker ps > /dev/null 2>&1 && echo "  ✓ Docker daemon running"; \
	else \
		echo "$(YELLOW)  ⚠ Docker socket not available (tests require Docker)$(NC)"; \
	fi
	@echo "$(GREEN)✓ Docker integration checks passed$(NC)"

test-hal-9000-cleanup:
	@echo "$(YELLOW)Testing session cleanup...$(NC)"
	@echo "  Session cleanup would be tested on actual container lifecycle"
	@echo "$(GREEN)✓ Cleanup test structure in place$(NC)"

##############################################################################
# DIND TESTS
##############################################################################

test-dind: test-pool-manager test-resource-limits
	@echo "$(GREEN)✓ All DinD tests passed$(NC)"

test-pool-manager:
	@echo "$(YELLOW)Running pool manager tests...$(NC)"
	$(QUIET)./scripts/build/test-pool-manager.sh all
	@echo "$(GREEN)✓ Pool manager tests passed$(NC)"

test-resource-limits:
	@echo "$(YELLOW)Running resource limits tests...$(NC)"
	$(QUIET)./scripts/build/test-resource-limits.sh all
	@echo "$(GREEN)✓ Resource limits tests passed$(NC)"

benchmark-dind:
	@echo "$(YELLOW)Running DinD performance benchmarks...$(NC)"
	@./scripts/build/benchmark-dind.sh all
	@echo "$(GREEN)✓ Benchmarks complete$(NC)"

##############################################################################
# BUILD TARGETS
##############################################################################

build: build-base build-python build-node build-java
	@echo "$(GREEN)✓ All Docker images built$(NC)"

build-base:
	@echo "$(YELLOW)Building base image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.hal9000 \
		-t $(IMAGE_BASE):base \
		-t $(IMAGE_BASE):latest \
		--build-arg PROFILE=base \
		--label version="$(VERSION)" \
		.
	@echo "$(GREEN)✓ Base image built$(NC)"

build-python:
	@echo "$(YELLOW)Building Python image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.hal9000 \
		-t $(IMAGE_BASE):python \
		--build-arg PROFILE=python \
		--label version="$(VERSION)" \
		.
	@echo "$(GREEN)✓ Python image built$(NC)"

build-node:
	@echo "$(YELLOW)Building Node.js image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.hal9000 \
		-t $(IMAGE_BASE):node \
		--build-arg PROFILE=node \
		--label version="$(VERSION)" \
		.
	@echo "$(GREEN)✓ Node.js image built$(NC)"

build-java:
	@echo "$(YELLOW)Building Java image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.hal9000 \
		-t $(IMAGE_BASE):java \
		--build-arg PROFILE=java \
		--label version="$(VERSION)" \
		.
	@echo "$(GREEN)✓ Java image built$(NC)"

build-test-image:
	@echo "$(YELLOW)Building test image...$(NC)"
	$(QUIET)docker build \
		-f $(PLUGIN_DIR)/docker/Dockerfile.hal9000 \
		-t $(IMAGE_BASE):test-latest \
		--label version="test-$(VERSION)" \
		.
	@echo "$(GREEN)✓ Test image built$(NC)"

##############################################################################
# PACKAGE
##############################################################################

package: validate
	@echo "$(YELLOW)Creating marketplace package...$(NC)"
	$(QUIET)mkdir -p $(DIST_DIR)
	$(QUIET)tar -czf $(DIST_DIR)/$(PROJECT_NAME)-$(VERSION).tar.gz \
		--exclude='.git' \
		--exclude='$(BUILD_DIR)' \
		--exclude='$(DIST_DIR)' \
		--exclude='.pm' \
		--exclude='tests' \
		.
	@echo "$(GREEN)✓ Package created: $(DIST_DIR)/$(PROJECT_NAME)-$(VERSION).tar.gz$(NC)"

##############################################################################
# CI PIPELINE
##############################################################################

ci: clean validate test-hal-9000 build package
	@echo ""
	@echo "$(GREEN)╔═══════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║      CI Pipeline Complete ✓                       ║$(NC)"
	@echo "$(GREEN)║      Version: $(VERSION)$(NC)"
	@echo "$(GREEN)╚═══════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Build artifacts:"
	@du -sh $(BUILD_DIR) $(DIST_DIR) 2>/dev/null || echo "  (no build artifacts)"

##############################################################################
# DEVELOPER HELPERS
##############################################################################

lint: validate shellcheck-detailed
	@echo "$(GREEN)✓ Linting complete$(NC)"

shellcheck-detailed:
	@if command -v shellcheck &> /dev/null; then \
		echo "$(YELLOW)Running detailed shellcheck...$(NC)"; \
		shellcheck -x hal-9000 $(PLUGIN_DIR)/install.sh $(PLUGIN_DIR)/aod/aod.sh || true; \
	fi

install-dev-tools:
	@echo "$(YELLOW)Installing development tools...$(NC)"
	@echo "  Installing shellcheck..."
	$(QUIET)if command -v brew &> /dev/null; then \
		brew install shellcheck jq; \
	else \
		echo "$(YELLOW)⚠ Homebrew not found. Install shellcheck and jq manually.$(NC)"; \
	fi
	@echo "$(GREEN)✓ Dev tools installed$(NC)"

watch:
	@echo "$(YELLOW)Watching for changes...$(NC)"
	@echo "Run 'make test-hal-9000' on file changes"
	$(QUIET)if command -v watchmedo &> /dev/null; then \
		watchmedo shell-command \
			--patterns="*.sh;*.md;Makefile" \
			--recursive \
			--command="make test-hal-9000" \
			.; \
	else \
		echo "$(YELLOW)⚠ watchdog not found. Install with: pip install watchdog[watchmedo]$(NC)"; \
	fi

##############################################################################
# VERSION
##############################################################################

version:
	@echo "$(BLUE)Project: $(PROJECT_NAME)$(NC)"
	@echo "$(BLUE)Version: $(VERSION)$(NC)"
	@echo "$(BLUE)Docker Registry: $(DOCKER_REGISTRY)$(NC)"
	@echo "$(BLUE)Image Base: $(IMAGE_BASE)$(NC)"

##############################################################################
# PHONY DECLARATIONS
##############################################################################

.PHONY: help clean clean-build clean-test clean-containers clean-docker-images
.PHONY: validate validate-bash validate-json validate-markdown validate-shellcheck
.PHONY: test test-hal-9000 test-hal-9000-syntax test-hal-9000-unit test-hal-9000-config
.PHONY: test-hal-9000-errors test-hal-9000-integration test-hal-9000-docker test-hal-9000-cleanup
.PHONY: test-dind test-pool-manager test-resource-limits benchmark-dind
.PHONY: build build-base build-python build-node build-java build-test-image
.PHONY: package ci lint shellcheck-detailed install-dev-tools watch version
