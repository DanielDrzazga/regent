# Makefile — Regent (plugin Claude Code: Markdown + bash)
# Wygenerowany przez /init-sdd. Cele to kontrakt frameworka SDD: skille wołają `make <cel>`.
# Zgodny z GNU Make 3.81 (macOS) i 4.x (Fedora): bez .ONESHELL, $(file …), .RECIPEPREFIX.
# Recepty w /bin/sh; skrypty uruchamiane bashem.
#
# Użycie:          make help
# Szybka pętla:    make test-unit PATTERN=git-guard SHELLS=bash

# Interpretery do składni i testów: /bin/bash (3.2 na macOS) + bash z PATH, bez duplikatów ścieżek.
SHELLS := $(shell { [ -x /bin/bash ] && echo /bin/bash; command -v bash; } 2>/dev/null | awk '!seen[$$0]++')
# PATTERN zawęża testy do scripts/tests/*PATTERN*.test.sh
PATTERN ?=
# Poziom shellcheck, gdy zainstalowany: error | warning | info | style
SHELLCHECK_SEVERITY ?= error
# --strict: ostrzeżenia walidatora pluginu traktowane jak błędy
VALIDATE_FLAGS ?= --strict

SCRIPTS   := $(wildcard scripts/*.sh scripts/hooks/*.sh)
ALL_TESTS := $(wildcard scripts/tests/*.test.sh)
TESTS     := $(wildcard scripts/tests/*$(PATTERN)*.test.sh)

.DEFAULT_GOAL := help
.PHONY: help install lint type-check format test test-unit test-integration test-coverage \
        check build deps-outdated deps-audit

help: ## Pokaż dostępne cele
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN { FS = ":.*## " } { printf "  %-18s %s\n", $$1, $$2 }'

# === Zależności ===
install: ## Sprawdź narzędzia (plugin nie ma zależności pakietowych — nic nie instaluje)
	@rc=0; \
	for t in bash git awk sed grep; do \
	  if command -v $$t >/dev/null 2>&1; then echo "OK    $$t"; else echo "ERROR brak $$t (wymagane)"; rc=1; fi; \
	done; \
	for t in claude jq shellcheck; do \
	  if command -v $$t >/dev/null 2>&1; then echo "OK    $$t"; else echo "INFO  brak $$t (opcjonalne: claude → type-check, jq → statusline, shellcheck → lint)"; fi; \
	done; \
	echo "INFO  sesja testowa z pluginem: claude --plugin-dir ."; \
	exit $$rc

deps-outdated: ## Brak zależności pakietowych — pokazuje wersje narzędzi
	@echo "INFO  brak zależności pakietowych; wersje narzędzi:"
	@for sh in $(SHELLS); do printf '  %-26s %s\n' "$$sh" "$$("$$sh" -c 'echo $$BASH_VERSION')"; done
	@for t in claude git jq; do command -v $$t >/dev/null 2>&1 && printf '  %-26s %s\n' "$$t" "$$($$t --version 2>&1 | head -1)"; done; true

deps-audit: ## N/A — brak zależności zewnętrznych do audytu
	@echo "INFO  deps-audit: N/A — plugin nie ma package managera ani zależności zewnętrznych"

# === Jakość ===
lint: ## Spójność frameworka (framework-lint.sh, uruchamia też testy skryptów) + shellcheck, gdy jest
	bash scripts/framework-lint.sh
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck -s bash -S $(SHELLCHECK_SEVERITY) $(SCRIPTS) $(ALL_TESTS); \
	else echo "INFO  shellcheck niezainstalowany — pominięto"; fi

type-check: ## Składnia skryptów w każdym bashu + walidacja pluginu (claude plugin validate)
	@[ -n "$(SCRIPTS)" ] || { echo "ERROR brak skryptów w scripts/"; exit 1; }
	@for sh in $(SHELLS); do for f in $(SCRIPTS) $(ALL_TESTS); do \
	  "$$sh" -n "$$f" || { echo "ERROR $$f: błąd składni w $$sh"; exit 1; }; \
	done; done; \
	echo "OK    składnia: $(words $(SCRIPTS) $(ALL_TESTS)) plików w: $(SHELLS)"
	@if command -v claude >/dev/null 2>&1; then claude plugin validate $(VALIDATE_FLAGS) .; \
	else echo "WARN  brak claude — pominięto claude plugin validate"; fi

format: ## N/A — brak formattera; styl ręczny (ai/docs/conventions/code-style.md)
	@echo "INFO  format: N/A — styl ręczny; auto-formatter zniszczyłby wyrównane kolumny w skryptach"

# === Testy ===
test: test-unit test-integration ## Wszystkie testy

test-unit: ## Testy skryptów w każdym bashu (make test-unit PATTERN=git-guard SHELLS=bash)
	@[ -n "$(TESTS)" ] || { echo "ERROR brak testów scripts/tests/*$(PATTERN)*.test.sh"; exit 1; }
	@rc=0; for sh in $(SHELLS); do for t in $(TESTS); do \
	  out=$$("$$sh" "$$t" 2>&1); code=$$?; \
	  printf '%s [%s] %s\n' "$$t" "$$sh" "$$(printf '%s\n' "$$out" | tail -1)"; \
	  [ $$code -eq 0 ] || { printf '%s\n' "$$out"; rc=1; }; \
	done; done; exit $$rc

test-integration: ## N/A — brak automatycznych testów pluginu w Claude Code
	@echo "INFO  test-integration: N/A — ładowanie pluginu sprawdza make type-check; smoke ręcznie: claude --plugin-dir ."

test-coverage: ## N/A — brak narzędzia pokrycia dla bash w stacku
	@echo "INFO  test-coverage: N/A — kompletność pilnują przypadki w scripts/tests/ i reguły regresji framework-lint.sh"

# === Bramki ===
check: ## Bramka SDD: type-check + lint + test
	@$(MAKE) --no-print-directory type-check
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory test

build: ## N/A — plugin nie ma kroku budowania
	@echo "INFO  build: N/A — Claude Code ładuje pliki wprost z repo; gotowość manifestu: make type-check"
