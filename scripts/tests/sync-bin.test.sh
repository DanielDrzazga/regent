#!/usr/bin/env bash
# Testy scripts/hooks/sync-bin.sh — kopia do ${CLAUDE_PLUGIN_DATA}/bin, brak zbędnego nadpisania,
# cisza na stdout.
# Użycie: bash scripts/tests/sync-bin.test.sh      (kod wyjścia 0 = wszystkie zielone)

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

name="pierwsze uruchomienie: kopie wykonywalne, stdout pusty"
DATA="$T/data"; run
if [ "$code" -eq 0 ]; then ok; else ko "kod $code"; fi
if [ -z "$out" ]; then ok; else ko "stdout niepusty: $out"; fi
for f in statusline.sh session-tokens.sh; do
  if cmp -s "$T/plugin/scripts/$f" "$DATA/bin/$f"; then ok; else ko "brak kopii $f"; fi
  if [ -x "$DATA/bin/$f" ]; then ok; else ko "$f bez prawa wykonania"; fi
done

name="bez zmian w źródle: plik nie jest nadpisywany"
touch -t 200001010000 "$DATA/bin/statusline.sh"; touch -t 200101010000 "$T/ref"; run
if [ "$DATA/bin/statusline.sh" -nt "$T/ref" ]; then ko "plik nadpisany mimo braku zmian"; else ok; fi

name="zmiana w źródle: kopia odświeżona"
printf 'echo nowa\n' >> "$T/plugin/scripts/statusline.sh"; run
if cmp -s "$T/plugin/scripts/statusline.sh" "$DATA/bin/statusline.sh"; then ok; else ko "kopia nieodświeżona"; fi
if ls "$DATA/bin/" | grep -q '\.tmp\.'; then ko "został plik tymczasowy"; else ok; fi

name="brak CLAUDE_PLUGIN_DATA: kod 0, nic nie tworzy"
unset DATA; run
if [ "$code" -eq 0 ] && [ -z "$out" ]; then ok; else ko "kod $code, stdout: $out"; fi

echo "sync-bin tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
