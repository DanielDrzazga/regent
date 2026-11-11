# Makefile — Regent (SDD framework for Claude Code)
#
# Usage: make help

PLUGIN          := regent
MARKETPLACE     := regent
SCOPE           ?= user
# Remote marketplace on GitHub — the same source as templates/project-settings.json.template,
# so user and project entries match.
MARKETPLACE_URL ?= https://github.com/DanielDrzazga/regent.git
# Release: the remote that hosts main and the version from the manifest
REMOTE          ?= origin
VERSION_FILE    := .claude-plugin/plugin.json
CURRENT_VERSION  = $(shell python3 -c "import json;print(json.load(open('$(VERSION_FILE)'))['version'])")

.DEFAULT_GOAL := help

##@ Installation from GitHub (recommended)

.PHONY: install plugin-marketplace-add plugin-reinstall

install: plugin-marketplace-add plugin-install ## Register the GitHub marketplace and install the plugin (once per machine)

plugin-marketplace-add:     ## Register the GitHub repo as the "regent" marketplace (MARKETPLACE_URL)
	claude plugin marketplace add $(MARKETPLACE_URL)

plugin-reinstall: plugin-uninstall plugin-marketplace-remove plugin-marketplace-add plugin-install ## Full reset from GitHub (also switches from a local install)

##@ Installation from a local clone (plugin development)

.PHONY: install-local plugin-marketplace-add-local plugin-reinstall-local

install-local: plugin-marketplace-add-local plugin-install ## Register this clone as the "regent" marketplace and install the plugin

plugin-marketplace-add-local: ## Register this clone as the "regent" marketplace (installs the clone's commit)
	claude plugin marketplace add ./

plugin-reinstall-local: plugin-uninstall plugin-marketplace-remove plugin-marketplace-add-local plugin-install ## Full reset from this clone (also switches from a GitHub install)

##@ Plugin management (both sources)

.PHONY: plugin-install plugin-update plugin-status plugin-uninstall plugin-marketplace-remove

plugin-install:             ## Install the plugin (SCOPE=user|project|local, default: user)
	claude plugin install $(PLUGIN)@$(MARKETPLACE) --scope $(SCOPE) -y

plugin-update:              ## Fetch the latest release (local install: run git pull first)
	claude plugin marketplace update $(MARKETPLACE)
	claude plugin update $(PLUGIN)@$(MARKETPLACE)

plugin-status:              ## Show the installation status, the marketplace source and the latest release
	@claude plugin list | grep -A3 $(PLUGIN) || echo "$(PLUGIN) is not installed"
	@claude plugin marketplace list | grep -A2 $(MARKETPLACE) || true
	@v=$$(git ls-remote --tags --refs $(MARKETPLACE_URL) 'v*' 2>/dev/null | sed 's|.*refs/tags/||' | sort -V | tail -1); \
	  echo "Latest release: $${v:-unknown (no access to $(MARKETPLACE_URL))} — an older installed version: make plugin-update"

plugin-uninstall:           ## Uninstall the plugin (SCOPE=user|project|local, default: user)
	claude plugin uninstall $(PLUGIN)@$(MARKETPLACE) --scope $(SCOPE) -y

plugin-marketplace-remove:  ## Remove the registered "regent" marketplace (all scopes)
	claude plugin marketplace remove $(MARKETPLACE)

##@ Quality gate (run before every PR)

.PHONY: lint validate test check

lint:                       ## Framework consistency lint (also runs the script tests)
	bash scripts/framework-lint.sh

validate:                   ## Validate the plugin and marketplace manifests
	claude plugin validate .

test:                       ## Run only the script tests (scripts/tests/*.test.sh)
	@for t in scripts/tests/*.test.sh; do echo "== $$t"; bash "$$t" || exit 1; done

check: lint validate        ## Full gate: lint + manifest validation

##@ Release (see CONTRIBUTING.md → Releases)

.PHONY: bump release

bump:                       ## Set the plugin version in the PR (VERSION=x.y.z; needs its CHANGELOG.md entry)
	@test -n "$(VERSION)" || { echo "Usage: make bump VERSION=x.y.z"; exit 1; }
	@echo "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "VERSION must be semver x.y.z"; exit 1; }
	@grep -q '^## \[$(VERSION)\]' CHANGELOG.md || { echo "CHANGELOG.md has no '## [$(VERSION)]' entry"; exit 1; }
	@python3 -c "import json;p='$(VERSION_FILE)';d=json.load(open(p));d['version']='$(VERSION)';open(p,'w').write(json.dumps(d,indent=2,ensure_ascii=False)+'\n')"
	@echo "$(VERSION_FILE): $(VERSION)"

release:                    ## Tag merged main as v<version> and push the tag (REMOTE, default: origin)
	@test "$$(git branch --show-current)" = main || { echo "Run on main"; exit 1; }
	@test -z "$$(git status --porcelain)" || { echo "Working tree not clean"; exit 1; }
	git fetch $(REMOTE)
	@test "$$(git rev-parse HEAD)" = "$$(git rev-parse $(REMOTE)/main)" || { echo "main differs from $(REMOTE)/main — pull first"; exit 1; }
	@! git rev-parse -q --verify "refs/tags/v$(CURRENT_VERSION)" >/dev/null || { echo "Tag v$(CURRENT_VERSION) exists — bump the version first"; exit 1; }
	@grep -q '^## \[$(CURRENT_VERSION)\]' CHANGELOG.md || { echo "CHANGELOG.md has no '## [$(CURRENT_VERSION)]' entry"; exit 1; }
	git tag -a v$(CURRENT_VERSION) -m "Regent v$(CURRENT_VERSION)"
	git push $(REMOTE) v$(CURRENT_VERSION)

##@ Help

.PHONY: help

help:                       ## Show available targets
	@awk 'BEGIN { FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n" } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	  /^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
