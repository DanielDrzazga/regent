#!/usr/bin/env bash
# Testy scripts/regent.sh — kolejność szukania CLI (dist/cli.js w pluginie, potem regent w PATH),
# brak CLI → kod 3 i jedna linia na stderr, argumenty i kod wyjścia CLI przechodzą bez zmian.
# Użycie: bash scripts/tests/regent.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
SCRIPT="$(cd "$(dirname "$0")" && pwd)/../regent.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/regent-sh.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugin/tools/regent/dist" "$T/empty" "$T/bin" "$T/nonode"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "out: $out" "err: $err" | sed 's/^/    /'; }
# run <plugin-root> <PATH> <argumenty…>
run() {
  root=$1; path=$2; shift 2
  out=$(CLAUDE_PLUGIN_ROOT="$root" PATH="$path" "$BASH" "$SCRIPT" "$@" 2>"$T/stderr"); code=$?
  err=$(cat "$T/stderr")
}

# Udawany regent w PATH: wypisuje argumenty, kończy kodem z REGENT_FAKE_CODE.
printf '#!/bin/sh\necho "path-regent $*"\nexit ${REGENT_FAKE_CODE:-0}\n' > "$T/bin/regent"
chmod +x "$T/bin/regent"
cp "$T/bin/regent" "$T/nonode/regent"

name="brak CLI: kod 3, jedna linia na stderr, pusty stdout"
run "$T/empty" "$T/empty"
if [ "$code" -eq 3 ]; then ok; else ko "kod $code"; fi
if [ -z "$out" ]; then ok; else ko "stdout niepusty"; fi
if [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" -eq 1 ] && printf '%s' "$err" | grep -q '^regent.sh: brak CLI regent'; then ok; else ko "stderr"; fi

name="bez dist/cli.js: regent z PATH z argumentami i jego kodem"
REGENT_FAKE_CODE=4 run "$T/empty" "$T/bin" task list --json
if [ "$code" -eq 4 ]; then ok; else ko "kod $code"; fi
if [ "$out" = "path-regent task list --json" ]; then ok; else ko "argumenty"; fi

NODE=$(command -v node 2>/dev/null)
if [ -z "$NODE" ]; then
  echo "SKIP [dist/cli.js] brak node — przypadki z CLI w pluginie pominięte"
else
  printf 'console.log("dist " + process.argv.slice(2).join(" ")); process.exitCode = Number(process.env.REGENT_FAKE_CODE ?? 0);\n' \
    > "$T/plugin/tools/regent/dist/cli.js"
  NODEBIN=$(dirname "$NODE")

  name="dist/cli.js w pluginie wygrywa z regent w PATH"
  run "$T/plugin" "$T/bin:$NODEBIN" task show 7
  if [ "$code" -eq 0 ] && [ "$out" = "dist task show 7" ]; then ok; else ko "kod $code"; fi

  name="kod wyjścia CLI przechodzi bez zmian"
  REGENT_FAKE_CODE=1 run "$T/plugin" "$NODEBIN" task take 1
  if [ "$code" -eq 1 ]; then ok; else ko "kod $code"; fi

  name="argumenty ze spacjami i cudzysłowami bez rozbicia"
  run "$T/plugin" "$NODEBIN" task done 3 --tests 'AC-1 → a b › "x"'
  if [ "$out" = 'dist task done 3 --tests AC-1 → a b › "x"' ]; then ok; else ko "argumenty"; fi
fi

name="dist/cli.js bez node w PATH: regent z PATH"
run "$T/plugin" "$T/nonode" task list
if [ "$out" = "path-regent task list" ]; then ok; else ko "kod $code"; fi

echo "regent.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
