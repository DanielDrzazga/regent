#!/usr/bin/env bash
# Tests for scripts/hooks/sync-bin.sh — copy to ${CLAUDE_PLUGIN_DATA}/bin, no needless overwrite,
# silence on stdout.
# Usage: bash scripts/tests/sync-bin.test.sh      (exit code 0 = all green)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/sync-bin.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/sync-bin.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugin/scripts"
printf '#!/usr/bin/env bash\necho statusline\n' > "$T/plugin/scripts/statusline.sh"
printf '#!/usr/bin/env bash\necho tokens\n' > "$T/plugin/scripts/session-tokens.sh"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; }
run() { out=$(CLAUDE_PLUGIN_ROOT="$T/plugin" CLAUDE_PLUGIN_DATA="${DATA-}" "$BASH" "$HOOK" 2>/dev/null); code=$?; }

name="first run: executable copies, empty stdout"
DATA="$T/data"; run
if [ "$code" -eq 0 ]; then ok; else ko "code $code"; fi
if [ -z "$out" ]; then ok; else ko "stdout not empty: $out"; fi
for f in statusline.sh session-tokens.sh; do
  if cmp -s "$T/plugin/scripts/$f" "$DATA/bin/$f"; then ok; else ko "no copy of $f"; fi
  if [ -x "$DATA/bin/$f" ]; then ok; else ko "$f not executable"; fi
done

name="source unchanged: file not overwritten"
touch -t 200001010000 "$DATA/bin/statusline.sh"; touch -t 200101010000 "$T/ref"; run
if [ "$DATA/bin/statusline.sh" -nt "$T/ref" ]; then ko "file overwritten although unchanged"; else ok; fi

name="source changed: copy refreshed"
printf 'echo new\n' >> "$T/plugin/scripts/statusline.sh"; run
if cmp -s "$T/plugin/scripts/statusline.sh" "$DATA/bin/statusline.sh"; then ok; else ko "copy not refreshed"; fi
if ls "$DATA/bin/" | grep -q '\.tmp\.'; then ko "temp file left behind"; else ok; fi

name="no CLAUDE_PLUGIN_DATA: code 0, creates nothing"
unset DATA; run
if [ "$code" -eq 0 ] && [ -z "$out" ]; then ok; else ko "code $code, stdout: $out"; fi

echo "sync-bin tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
