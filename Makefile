ENV ?= dev
ENV_DIR := environments/$(ENV)

.PHONY: fmt validate lint test init plan apply destroy

fmt:            ## Format all Terraform files
	terraform fmt -recursive

validate:       ## Validate every module and the environment
	@for d in modules/* $(ENV_DIR); do \
		echo "==> $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$d validate || exit 1; \
	done

lint:           ## Run tflint across the repo
	tflint --init && tflint --recursive --config "$(CURDIR)/.tflint.hcl"

test:           ## Run mocked terraform tests (no Azure access needed)
	terraform -chdir=$(ENV_DIR) init -backend=false -input=false >/dev/null
	terraform -chdir=$(ENV_DIR) test

init:           ## Init with the remote backend (needs backend.hcl)
	terraform -chdir=$(ENV_DIR) init -backend-config=backend.hcl

plan: init      ## Create a plan file
	terraform -chdir=$(ENV_DIR) plan -out=tfplan

apply:          ## Apply the saved plan
	terraform -chdir=$(ENV_DIR) apply tfplan

destroy: init   ## Tear everything down
	terraform -chdir=$(ENV_DIR) destroy
