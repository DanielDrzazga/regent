#!/usr/bin/env bash
# Tests for scripts/statusline.sh — line with the model and transcript tokens (dedup by message.id,
# subagents), cache refreshed when the transcript grows.
# Usage: bash scripts/tests/statusline.test.sh      (exit code 0 = all green)

set -u
SL="$(cd "$(dirname "$0")" && pwd)/../statusline.sh"
command -v jq >/dev/null 2>&1 || { echo "statusline tests: 0 passed, 0 failed (SKIP: no jq — statusline requires it)"; exit 0; }
T=$(mktemp -d "${TMPDIR:-/tmp}/statusline.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/tr/s1/subagents"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/    /'; }
msg() { printf '{"type":"assistant","message":{"id":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"output_tokens":%s,"cache_read_input_tokens":%s}}}\n' "$@"; }
run() {
  json=$(printf '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":12.5,"total_input_tokens":1000,"total_output_tokens":500,"context_window_size":200000},"cost":{"total_cost_usd":0.5},"transcript_path":"%s"}' "$T/tr/s1.jsonl")
  out=$(printf '%s' "$json" | TMPDIR="$T" HOME="$T" "$BASH" "$SL" 2>&1 | sed "s/$(printf '\033')\[[0-9;]*m//g")
}
expect_has() { if printf '%s' "$out" | grep -qF -- "$1"; then ok; else ko "missing: $1"; fi; }

# a: 10+20+5 new, 100 from cache; duplicate a skipped; b: 2000 new, 5000 from cache
{ msg a 10 20 5 100; msg a 10 20 5 100; msg b 2000 0 0 5000; } > "$T/tr/s1.jsonl"

name="model, context and cost from the JSON"
run; expect_has 'Opus'; expect_has 'ctx 12% (1k/200k)'; expect_has '$0.50'

name="transcript tokens deduped by message.id"
expect_has 'tokens 2k (with cache 7k)'

name="subagent and transcript growth refresh the cache"
msg c 3000 0 0 0 > "$T/tr/s1/subagents/x.jsonl"; msg d 1000 0 0 0 >> "$T/tr/s1.jsonl"
run; expect_has 'tokens 6k (with cache 11k)'

echo "statusline tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
