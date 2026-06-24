SHELL := /bin/sh

TERRAFORM ?= terraform
TFLINT ?= tflint
CHECKOV ?= checkov
JQ ?= jq
TF_DIR ?=
PLAN_FILE ?= /tmp/aws-landing-zone.tfplan

TF_DIRS := $(shell find infra/environments -type f -name '*.tf' -exec dirname {} \; 2>/dev/null | sort -u)
TF_TEST_DIRS := $(shell find infra/modules -type f -name '*.tftest.hcl' -exec dirname {} \; 2>/dev/null | sed 's|/tests$$||' | sort -u)
POLICY_JSON := $(shell find infra/policies -type f -name '*.json' 2>/dev/null | sort)
SHELL_SCRIPTS := $(shell find scripts -type f -name '*.sh' 2>/dev/null | sort)

.DEFAULT_GOAL := help

.PHONY: help tools fmt fmt-check init validate lint security-scan plan policy-json script-syntax terraform-test test require-tf-dir

help:
	@printf '%s\n' \
	  'AWS landing zone scaffold targets:' \
	  '  make tools                       Show required tool availability' \
	  '  make fmt                         Format Terraform files under infra/' \
	  '  make fmt-check                   Check Terraform formatting' \
	  '  make init TF_DIR=<root>          Initialize one Terraform root without backend' \
	  '  make validate                    Validate discovered Terraform roots' \
	  '  make lint                        Run TFLint in discovered Terraform roots' \
	  '  make security-scan               Run Checkov against infra/' \
	  '  make terraform-test              Run mocked Terraform module plan tests' \
	  '  make plan TF_DIR=<root>          Create a saved plan outside the repository' \
	  '  make test                        Run safe local scaffold checks'

tools:
	@for tool in $(TERRAFORM) aws $(TFLINT) $(CHECKOV) $(JQ) pre-commit; do \
	  if command -v "$$tool" >/dev/null 2>&1; then \
	    printf '%-12s FOUND\n' "$$tool"; \
	  else \
	    printf '%-12s MISSING\n' "$$tool"; \
	  fi; \
	done

fmt:
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@$(TERRAFORM) fmt -recursive infra

fmt-check:
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@$(TERRAFORM) fmt -check -recursive infra

require-tf-dir:
	@test -n "$(TF_DIR)" || { echo 'TF_DIR is required, for example TF_DIR=infra/environments/development'; exit 2; }
	@test -d "$(TF_DIR)" || { echo "Terraform directory does not exist: $(TF_DIR)"; exit 2; }
	@find "$(TF_DIR)" -maxdepth 1 -type f -name '*.tf' | grep -q . || { echo "No Terraform configuration exists in $(TF_DIR); refusing to initialize or plan a placeholder"; exit 2; }

init: require-tf-dir
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@$(TERRAFORM) -chdir="$(TF_DIR)" init -backend=false -input=false

validate:
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@if test -z "$(TF_DIRS)"; then \
	  echo 'No Terraform roots exist yet; validation skipped.'; \
	else \
	  set -e; for dir in $(TF_DIRS); do \
	    echo "Validating $$dir"; \
	    $(TERRAFORM) -chdir="$$dir" init -backend=false -input=false -lockfile=readonly; \
	    $(TERRAFORM) -chdir="$$dir" validate; \
	  done; \
	fi

lint:
	@command -v $(TFLINT) >/dev/null 2>&1 || { echo 'tflint is required; see docs/versions.md'; exit 1; }
	@if test -z "$(TF_DIRS)"; then \
	  echo 'No Terraform roots exist yet; lint skipped.'; \
	else \
	  set -e; for dir in $(TF_DIRS); do \
	    echo "Linting $$dir"; \
	    $(TFLINT) --chdir="$$dir"; \
	  done; \
	fi

security-scan:
	@command -v $(CHECKOV) >/dev/null 2>&1 || { echo 'checkov is required; see docs/versions.md'; exit 1; }
	@$(CHECKOV) -d infra --quiet

plan: require-tf-dir
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@case "$(PLAN_FILE)" in "$(CURDIR)"/*) echo 'PLAN_FILE must be outside the repository'; exit 2;; esac
	@$(TERRAFORM) -chdir="$(TF_DIR)" plan -input=false -out="$(PLAN_FILE)"

policy-json:
	@command -v $(JQ) >/dev/null 2>&1 || { echo 'jq is required'; exit 1; }
	@if test -z "$(POLICY_JSON)"; then \
	  echo 'No JSON policies exist yet; policy validation skipped.'; \
	else \
	  set -e; for file in $(POLICY_JSON); do \
	    echo "Validating $$file"; \
	    $(JQ) empty "$$file"; \
	  done; \
	fi

script-syntax:
	@if test -z "$(SHELL_SCRIPTS)"; then \
	  echo 'No shell scripts exist yet; syntax validation skipped.'; \
	else \
	  set -e; for file in $(SHELL_SCRIPTS); do \
	    echo "Checking $$file"; \
	    bash -n "$$file"; \
	  done; \
	fi

terraform-test:
	@command -v $(TERRAFORM) >/dev/null 2>&1 || { echo 'terraform is required'; exit 1; }
	@if test -z "$(TF_TEST_DIRS)"; then \
	  echo 'No Terraform module tests exist; skipped.'; \
	else \
	  set -e; for dir in $(TF_TEST_DIRS); do \
	    echo "Testing $$dir"; \
	    $(TERRAFORM) -chdir="$$dir" init -backend=false -input=false -lockfile=readonly; \
	    $(TERRAFORM) -chdir="$$dir" test; \
	  done; \
	fi

test: fmt-check validate policy-json script-syntax terraform-test
