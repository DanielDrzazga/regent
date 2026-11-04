# Makefile — Regent (SDD framework for Claude Code)
#
# Usage: make help

PLUGIN      := regent
MARKETPLACE := regent
SCOPE       ?= user

.DEFAULT_GOAL := help

##@ Plugin installation (local marketplace from this clone)

.PHONY: plugin-marketplace-add plugin-install plugin-update plugin-status \
        plugin-uninstall plugin-marketplace-remove plugin-reinstall

plugin-marketplace-add:     ## Register this clone as the local "regent" marketplace (once per machine)
	claude plugin marketplace add ./

plugin-install:             ## Install the plugin (SCOPE=user|project|local, default: user)
	claude plugin install $(PLUGIN)@$(MARKETPLACE) --scope $(SCOPE) -y

plugin-update:              ## Refresh the installed copy after pulling main (the install is a commit copy, not a live clone)
	claude plugin marketplace update $(MARKETPLACE)
	claude plugin update $(PLUGIN)@$(MARKETPLACE)

plugin-status:              ## Show the installation status
	@claude plugin list | grep -A3 $(PLUGIN) || echo "$(PLUGIN) is not installed"

plugin-uninstall:           ## Uninstall the plugin (SCOPE=user|project|local, default: user)
	claude plugin uninstall $(PLUGIN)@$(MARKETPLACE) --scope $(SCOPE) -y

plugin-marketplace-remove:  ## Remove the registered marketplace (all scopes)
	claude plugin marketplace remove $(MARKETPLACE)

plugin-reinstall: plugin-uninstall plugin-marketplace-remove plugin-marketplace-add plugin-install ## Full reset: uninstall, re-register the marketplace, install again

##@ Quality gate (run before every MR)

.PHONY: lint validate test check

lint:                       ## Framework consistency lint (also runs the script tests)
	bash scripts/framework-lint.sh

validate:                   ## Validate the plugin and marketplace manifests
	claude plugin validate .

test:                       ## Run only the script tests (scripts/tests/*.test.sh)
	@for t in scripts/tests/*.test.sh; do echo "== $$t"; bash "$$t" || exit 1; done

check: lint validate        ## Full gate: lint + manifest validation

##@ Help

.PHONY: help

help:                       ## Show available targets
	@awk 'BEGIN { FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n" } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	  /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
