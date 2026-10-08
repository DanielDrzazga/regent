# Cele stackowe (kontrakt make): PATTERN zawęża testy do plików test/*PATTERN*.test.js.
PATTERN ?=
TESTS = $(if $(PATTERN),$(wildcard test/*$(PATTERN)*.test.js),)

.PHONY: check test test-unit test-component lint type-check

check: lint type-check test

test:
	node --test

test-unit:
	node --test $(TESTS)

# Testy komponentów UI: test/web-*PATTERN*.test.js (bez PATTERN — wszystkie test/web-*).
test-component:
	node --test $(if $(PATTERN),$(wildcard test/web-*$(PATTERN)*.test.js),$(wildcard test/web-*.test.js))

lint:
	@for f in src/*.js src/db/*.js migrations/*.js web/*.js test/*.js; do node --check "$$f" || exit 1; done
	@echo "lint: OK"

type-check:
	@echo "type-check: n/d (JavaScript bez typów)"
