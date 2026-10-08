# Cele stackowe (kontrakt make): PATTERN zawęża testy do plików test/*PATTERN*.test.js.
PATTERN ?=
TESTS = $(if $(PATTERN),$(wildcard test/*$(PATTERN)*.test.js),)

.PHONY: check test test-unit lint type-check

check: lint type-check test

test:
	node --test

test-unit:
	node --test $(TESTS)

lint:
	@for f in src/*.js src/db/*.js migrations/*.js test/*.js; do node --check "$$f" || exit 1; done
	@echo "lint: OK"

type-check:
	@echo "type-check: n/d (JavaScript bez typów)"
