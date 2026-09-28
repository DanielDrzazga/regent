#!/usr/bin/env bash
# Testy scripts/hooks/session-context.sh — zakres always/sdd, format sesji i subagenta,
# pominięcie Explore i Plan, escaping JSON-a.
# Użycie: bash scripts/tests/session-context.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/session-context.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/session-context.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugin/context" "$T/sdd/ai/docs" "$T/plain"
printf 'Rola "partner"\n\tz tabem i \\ backslashem\nzażółć gęślą jaźń\n' > "$T/plugin/context/role.md"
printf 'Reguły SDD\n' > "$T/plugin/context/sdd.md"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/    /'; }
# run <projekt> <argumenty…> — stdin: $IN (JSON hooka)
run() {
  p=$1; shift
  out=$(printf '%s' "$IN" | CLAUDE_PLUGIN_ROOT="$T/plugin" CLAUDE_PROJECT_DIR="$T/$p" "$BASH" "$HOOK" "$@" 2>&1)
  code=$?
}
expect_code()  { if [ "$code" -eq "$1" ]; then ok; else ko "kod $code, oczekiwano $1"; fi; }
expect_has()   { if printf '%s' "$out" | grep -qF -- "$1"; then ok; else ko "brak: $1"; fi; }
expect_empty() { if [ -z "$out" ]; then ok; else ko "oczekiwano pustego wyjścia"; fi; }
# expect_json <plik> — wyjście to poprawny JSON, a additionalContext po dekodowaniu = treść pliku
expect_json() {
  command -v python3 >/dev/null 2>&1 || { echo "SKIP [$name] brak python3 — dekodowanie JSON pominięte"; return; }
  if printf '%s' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)["hookSpecificOutput"]
assert d["hookEventName"] == "SubagentStart"
assert d["additionalContext"] == open(sys.argv[1], encoding="utf-8").read().rstrip("\n")
' "$1" 2>/dev/null; then ok; else ko "JSON niepoprawny albo treść różna od $1"; fi
}

SESSION='{"hook_event_name":"SessionStart","source":"startup"}'
sub() { printf '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"%s"}' "$1"; }

name="session always: treść pliku w każdym projekcie"
IN=$SESSION; run plain session always role.md; expect_code 0; expect_has 'Rola "partner"'; expect_has 'zażółć gęślą jaźń'

name="session sdd: projekt bez ai/docs — nic"
IN=$SESSION; run plain session sdd sdd.md; expect_code 0; expect_empty

name="session sdd: projekt SDD — treść"
IN=$SESSION; run sdd session sdd sdd.md; expect_code 0; expect_has 'Reguły SDD'

name="subagent always: JSON z escapingiem cudzysłowu, taba, backslasha i UTF-8"
IN=$(sub regent:architect); run plain subagent always role.md; expect_code 0
expect_has '"hookEventName":"SubagentStart"'; expect_has 'Rola \"partner\"\n\tz tabem i \\ backslashem'
expect_json "$T/plugin/context/role.md"

name="subagent sdd: projekt SDD — JSON"
IN=$(sub regent:spec-writer); run sdd subagent sdd sdd.md; expect_code 0; expect_json "$T/plugin/context/sdd.md"

name="subagent sdd: projekt bez ai/docs — nic"
IN=$(sub regent:spec-writer); run plain subagent sdd sdd.md; expect_code 0; expect_empty

name="subagent Explore i Plan — pomijane jak CLAUDE.md"
IN=$(sub Explore); run sdd subagent always role.md; expect_code 0; expect_empty
IN=$(sub Plan); run sdd subagent always role.md; expect_code 0; expect_empty

name="błędne użycie — kod 0 i komunikat, bez blokowania sesji"
IN=$SESSION; run plain session always ../role.md; expect_code 0; expect_has 'użycie'
IN=$SESSION; run plain session always brak.md; expect_code 0; expect_has 'brak '
IN=$SESSION; run plain start always role.md; expect_code 0; expect_has 'nieznane zdarzenie'

echo "session-context tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
