.DEFAULT_GOAL := help
PARALLEL ?= 1
export PARALLEL

# Common watchexec settings
WATCHEXEC_OPTS := -c -d '200ms' -o 'queue'

help: ## Display available commands
	@echo "Available targets:"
	@awk -F':' '/^[a-zA-Z0-9_-]+:/ { \
		target = $$1; \
		has_help = match($$0, /##[^#].*$$/); \
		if (has_help) { \
			help = substr($$0, RSTART + 2, RLENGTH - 2); \
		} else { \
			help = ""; \
		} \
		printf "\033[36m%-20s\033[0m %s\n", target, help; \
	}' $(MAKEFILE_LIST) | sort
.PHONY: help

install: ## Install the helm chart
	helm install gitlab-zoekt . --wait $(ARGS)
.PHONY: install

upgrade: ## Upgrade the helm chart
	helm upgrade gitlab-zoekt . --wait $(ARGS)
.PHONY: upgrade

uninstall: ## Uninstall the helm chart
	helm uninstall gitlab-zoekt
.PHONY: uninstall

integration: ## Run integration tests
	./spec/scripts/integration.sh
.PHONY: integration

test: ## Run rspec
	bundle exec rspec
.PHONY: test

watch-integration: check-watchexec ## Watch for changes and run integration tests
	watchexec $(WATCHEXEC_OPTS) -e 'yaml,tpl,sh' ./spec/scripts/integration.sh
.PHONY: watch-integration

watch-test: check-watchexec ## Watch for changes and run rspec
	watchexec $(WATCHEXEC_OPTS) -e 'yaml,tpl,rb' bundle exec rspec
.PHONY: watch-test

check-watchexec: ## Check watchexec is installed
ifeq (, $(shell which watchexec))
	$(error "No watchexec installed, consider running brew install watchexec")
endif
.PHONY: check-watchexec
