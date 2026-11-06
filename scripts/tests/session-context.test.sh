#!/usr/bin/env bash
# Tests for scripts/hooks/session-context.sh — always/sdd scope, session and subagent format,
# skipping Explore and Plan, JSON escaping.
# Usage: bash scripts/tests/session-context.test.sh      (exit code 0 = all green)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/session-context.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/session-context.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugin/context" "$T/sdd/ai/docs" "$T/plain"
# the last line is a non-ASCII UTF-8 sample (Polish pangram) — test data for JSON escaping
printf 'Role "partner"\n\twith a tab and \\ a backslash\nzażółć gęślą jaźń\n' > "$T/plugin/context/role.md"
printf 'SDD rules\n' > "$T/plugin/context/sdd.md"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/    /'; }
# run <project> <arguments…> — stdin: $IN (hook JSON)
run() {
  p=$1; shift
  out=$(printf '%s' "$IN" | CLAUDE_PLUGIN_ROOT="$T/plugin" CLAUDE_PROJECT_DIR="$T/$p" "$BASH" "$HOOK" "$@" 2>&1)
  code=$?
}
expect_code()  { if [ "$code" -eq "$1" ]; then ok; else ko "code $code, expected $1"; fi; }
expect_has()   { if printf '%s' "$out" | grep -qF -- "$1"; then ok; else ko "missing: $1"; fi; }
expect_empty() { if [ -z "$out" ]; then ok; else ko "expected empty output"; fi; }
# expect_json <file> — output is valid JSON and the decoded additionalContext = file content
expect_json() {
  command -v python3 >/dev/null 2>&1 || { echo "SKIP [$name] no python3 — JSON decoding skipped"; return; }
  if printf '%s' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)["hookSpecificOutput"]
assert d["hookEventName"] == "SubagentStart"
assert d["additionalContext"] == open(sys.argv[1], encoding="utf-8").read().rstrip("\n")
' "$1" 2>/dev/null; then ok; else ko "invalid JSON or content differs from $1"; fi
}

SESSION='{"hook_event_name":"SessionStart","source":"startup"}'
sub() { printf '{"hook_event_name":"SubagentStart","agent_id":"a1","agent_type":"%s"}' "$1"; }

name="session always: file content in every project"
IN=$SESSION; run plain session always role.md; expect_code 0; expect_has 'Role "partner"'; expect_has 'zażółć gęślą jaźń'

name="session sdd: project without ai/docs — nothing"
IN=$SESSION; run plain session sdd sdd.md; expect_code 0; expect_empty

name="session sdd: SDD project — content"
IN=$SESSION; run sdd session sdd sdd.md; expect_code 0; expect_has 'SDD rules'

name="subagent always: JSON with escaped quote, tab, backslash and UTF-8"
IN=$(sub regent:architect); run plain subagent always role.md; expect_code 0
expect_has '"hookEventName":"SubagentStart"'; expect_has 'Role \"partner\"\n\twith a tab and \\ a backslash'
expect_json "$T/plugin/context/role.md"

name="subagent sdd: SDD project — JSON"
IN=$(sub regent:spec-writer); run sdd subagent sdd sdd.md; expect_code 0; expect_json "$T/plugin/context/sdd.md"

name="subagent sdd: project without ai/docs — nothing"
IN=$(sub regent:spec-writer); run plain subagent sdd sdd.md; expect_code 0; expect_empty

name="subagent Explore and Plan — skipped like CLAUDE.md"
IN=$(sub Explore); run sdd subagent always role.md; expect_code 0; expect_empty
IN=$(sub Plan); run sdd subagent always role.md; expect_code 0; expect_empty

name="wrong usage — code 0 and a message, session not blocked"
IN=$SESSION; run plain session always ../role.md; expect_code 0; expect_has 'usage'
IN=$SESSION; run plain session always missing.md; expect_code 0; expect_has 'missing '
IN=$SESSION; run plain start always role.md; expect_code 0; expect_has 'unknown event'

echo "session-context tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
