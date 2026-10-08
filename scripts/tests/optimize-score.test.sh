#!/usr/bin/env bash
# Testy scripts/optimize-score.sh — linia wyniku z JSON-a `claude plugin eval` (mediany, tokeny ze
# śladów, oblane oceniacze, rozrzut) i reguła keep/discard. Bez modelu: JSON i ślady syntetyczne.
# Użycie: bash scripts/tests/optimize-score.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/../optimize-score.sh"
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP optimize-score.sh: brak jq"
  exit 0
fi
T=$(mktemp -d "${TMPDIR:-/tmp}/optimize-score.XXXXXX")
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "out: $out" | sed 's/^/    /'; }

# Ślad przebiegu: rekord result z modelUsage dwóch modeli (sesja główna i subagent).
trace() { # $1 katalog, $2 tokeny na model
  mkdir -p "$1/out"
  printf '{"type":"system","subtype":"init"}\n{"type":"result","modelUsage":{"a":{"inputTokens":%s,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0},"b":{"inputTokens":%s,"outputTokens":0,"cacheReadInputTokens":0,"cacheCreationInputTokens":0}}}\n' "$2" "$2" \
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

name="score: mediany, tokeny ze śladów, oblane oceniacze, prompt z --files"
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin" --files skills/apply/SKILL.md --keep-traces)
want="quality=0.875 cost=2.5 tokens=500 seconds=240 prompt=10 spread=1 cases=train-one:0.75,train-two:1 failed=g2:1/3 errors=0"
if [ "$out" = "$want" ]; then ok; else ko "linia"; echo "    want: $want"; fi
if [ -d "$T/claude-eval-a1" ]; then ok; else ko "--keep-traces usunął ślady"; fi

name="score bez --keep-traces usuwa sandboksy evala"
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin")
case "$out" in *"tokens=500 "*) ok ;; *) ko "tokeny liczone przed usunięciem" ;; esac
if [ ! -d "$T/claude-eval-a1" ] && [ ! -d "$T/claude-eval-b1" ]; then ok; else ko "sandboksy zostały"; fi
out=$(bash "$SCRIPT" score "$T/eval.json" --plugin "$T/plugin")
case "$out" in *"tokens=0 "*) ok ;; *) ko "bez śladów tokens=0" ;; esac

name="score: przebieg z błędem w errors"
printf '{"cases":[{"name":"x-c","arms":{"with":[{"score":0,"costUsd":0,"durationSeconds":1,"error":"timed out","graders":[]}]}}]}' > "$T/err.json"
out=$(bash "$SCRIPT" score "$T/err.json")
case "$out" in *"errors=1"*) ok ;; *) ko "errors" ;; esac

B="quality=0.9 cost=4.0 tokens=1000 seconds=600 prompt=1000 spread=0.05 cases=a:1,b:0.8 failed=- errors=0"
dec() { out=$(bash "$SCRIPT" decide "$B" "$1" --noise 0.05); code=$?; }

name="decide: koszt niżej ponad próg → keep"
dec "quality=0.9 cost=3.0 tokens=800 seconds=650 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: koszt -25%'; then ok; else ko "kod $code"; fi

name="decide: czas niżej, koszt w progu → keep"
dec "quality=0.9 cost=4.1 tokens=1000 seconds=400 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: czas'; then ok; else ko "kod $code"; fi

name="decide: koszt i czas w szumie, krótszy prompt → keep (prostota)"
dec "quality=0.9 cost=4.05 tokens=1000 seconds=590 prompt=900 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^keep: prostszy prompt'; then ok; else ko "kod $code"; fi

name="decide: koszt i czas w szumie, ten sam prompt → discard"
dec "quality=0.9 cost=3.9 tokens=1000 seconds=590 prompt=1000 spread=0 cases=a:1,b:0.8 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: koszt'; then ok; else ko "kod $code"; fi

name="decide: jakość niżej → discard mimo taniej"
dec "quality=0.85 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:1,b:0.7 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: jakość'; then ok; else ko "kod $code"; fi

name="decide: przypadek spada z 1.00 → discard mimo wyższej średniej"
dec "quality=0.95 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:0.9,b:1 failed=- errors=0"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: przypadek a'; then ok; else ko "kod $code"; fi

name="decide: errors > 0 → discard"
dec "quality=1 cost=1.0 tokens=100 seconds=100 prompt=10 spread=0 cases=a:1,b:1 failed=- errors=1"
if [ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^discard: przebiegi z błędem'; then ok; else ko "kod $code"; fi

name="błędne użycie → kod 2"
out=$(bash "$SCRIPT" nieznane 2>&1); code=$?
if [ "$code" -eq 2 ]; then ok; else ko "kod $code"; fi

echo "optimize-score.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
