#!/usr/bin/env bash
# Tests of scripts/eval-score.sh — the result line from `claude plugin eval` JSON (medians, tokens from
# traces, per-model tokens, failed graders, spread) and the keep/discard rule. No model: synthetic JSON
# and traces.
# Usage: bash scripts/tests/eval-score.test.sh      (exit 0 = all green)

set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/../eval-score.sh"
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP eval-score.sh: jq not found"
  exit 0
fi
T=$(mktemp -d "${TMPDIR:-/tmp}/eval-score.XXXXXX")
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "out: $out" | sed 's/^/    /'; }

# A run's trace: a result record with modelUsage of two models (main session and subagent).
trace() { # $1 dir, $2 tokens per model
  mkdir -p "$1/out"
  printf '{"type":"system","subtype":"init"}\n{"type":"result","modelUsage":{"claude-opus-test":{"inputTokens":%s,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0},"claude-sonnet-test":{"inputTokens":%s,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}\n' "$2" "$2" \
    > "$1/out/trace.jsonl"
}
trace "$T/claude-eval-a1" 100
trace "$T/claude-eval-a2" 300
trace "$T/claude-eval-b1" 50
mkdir -p "$T/plugin/skills/apply"
printf '0123456789' > "$T/plugin/skills/apply/SKILL.md"

cat > "$T/eval.json" <<EOF
{"cases":[
 {"name":"apply-train-one","arms":{"with":[
   {"score":1,"costUsd":1.0,"durationSeconds":100,"tracePath":"$T/claude-eval-a1/out/trace.jsonl",
    "graders":[{"name":"g1","passed":true},{"name":"g2","passed":true}]},
   {"score":0.5,"costUsd":3.0,"durationSeconds":300,"tracePath":"$T/claude-eval-a2/out/trace.jsonl",
    "graders":[{"name":"g1","passed":true},{"name":"g2","passed":false}]}]}},
 {"name":"apply-train-two","arms":{"with":[
   {"score":1,"costUsd":0.5,"durationSeconds":40,"tracePath":"$T/claude-eval-b1/out/trace.jsonl",
    "graders":[{"name":"g3","passed":true},{"name":"ind","passed":false,"scored":false}]}]}}
]}
EOF

name="score: medians, tokens from traces, per-model tokens, failed graders, prompt from --files"
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin" --files skills/apply/SKILL.md --keep-traces)
want="quality=0.875 cost=2.5 tokens=500 models=opus:250,sonnet:250 seconds=240 prompt=10 spread=0.8 tspread=0.83 cases=train-one:0.75,train-two:1 failed=g2:1/3 errors=0"
if [ "$out" = "$want" ]; then ok; else ko "line"; echo "    want: $want"; fi
if [ -d "$T/claude-eval-a1" ]; then ok; else ko "--keep-traces removed the traces"; fi

name="score without --keep-traces removes the eval sandboxes"
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin")
case "$out" in *"tokens=500 "*) ok ;; *) ko "tokens counted before removal" ;; esac
if [ ! -d "$T/claude-eval-a1" ] && [ ! -d "$T/claude-eval-b1" ]; then ok; else ko "sandboxes left behind"; fi
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin")
case "$out" in *"tokens=0 models=- "*) ok ;; *) ko "without traces tokens=0 models=-" ;; esac

name="score: an errored run counts in errors"
printf '{"cases":[{"name":"x-c","arms":{"with":[{"score":0,"costUsd":0,"durationSeconds":1,"error":"timed out","graders":[]}]}}]}' > "$T/err.json"
out=$(bash "$SCRIPT" score "$T/err.json")
case "$out" in *"errors=1"*) ok ;; *) ko "errors" ;; esac

B="quality=0.9 cost=4.0 tokens=1000 seconds=600 prompt=1000 spread=0.05 cases=a:1,b:0.8 failed=- errors=0"
dec() { out=$(bash "$SCRIPT" decide "$B" "$1" --noise 0.05); code=$?; }

name="decide: cost lower beyond the threshold → keep"
dec "quality=0.9 cost=3.0 tokens=800 seconds=650 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: cost -25%'; then ok; else ko "exit $code"; fi

name="decide: time lower, cost within the threshold → keep"
dec "quality=0.9 cost=4.1 tokens=1000 seconds=400 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: time'; then ok; else ko "exit $code"; fi

name="decide: cost and time within noise, shorter prompt → keep (simplicity)"
dec "quality=0.9 cost=4.05 tokens=1000 seconds=590 prompt=900 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: simpler prompt'; then ok; else ko "exit $code"; fi

name="decide: time +15% within its own --tnoise 0.2, shorter prompt → keep"
out=$(bash "$SCRIPT" decide "$B" "quality=0.9 cost=4.05 tokens=1000 seconds=690 prompt=900 spread=0 cases=a:1,b:0.8 failed=- errors=0" --noise 0.05 --tnoise 0.2); code=$?
if [ "$code" -eq 0 ] && printf "%s" "$out" | grep -q "^keep: simpler prompt"; then ok; else ko "exit $code"; fi

name="decide: time +15% without --tnoise (threshold = --noise) → discard"
dec "quality=0.9 cost=4.05 tokens=1000 seconds=690 prompt=900 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 1 ]; then ok; else ko "exit $code"; fi

name="decide: cost and time within noise, same prompt → discard"
dec "quality=0.9 cost=3.9 tokens=1000 seconds=590 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: cost'; then ok; else ko "exit $code"; fi

name="decide: lower quality → discard even when cheaper"
dec "quality=0.85 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:1,b:0.7 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: quality'; then ok; else ko "exit $code"; fi

name="decide: a case drops from 1.00 → discard despite a higher mean"
dec "quality=0.95 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:0.9,b:1 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: case a'; then ok; else ko "exit $code"; fi

name="decide: errors > 0 → discard"
dec "quality=1 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:1,b:1 failed=- errors=1"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: runs with errors'; then ok; else ko "exit $code"; fi

name="wrong usage → exit 2"
out=$(bash "$SCRIPT" unknown 2>&1); code=$?
if [ "$code" -eq 2 ]; then ok; else ko "exit $code"; fi

echo "eval-score.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
