#!/usr/bin/env bash
# regent.sh — wywołanie CLI rdzenia zadań (tools/regent) ze skilli i hooków pluginu.
#
# Szuka zbudowanego CLI: najpierw ${CLAUDE_PLUGIN_ROOT}/tools/regent/dist/cli.js (przez node),
# potem polecenia `regent` w PATH (npm link). Nie ma żadnego → kod 3 i jedna linia na stderr;
# skill pracuje wtedy jak dotąd, na plikach, a hook milczy. REGENT_NO_CLI=1 wymusza ten tryb
# (zestaw evali sprawdza nim ścieżkę bez CLI — evals/apply/).
#
# Użycie:  bash ${CLAUDE_PLUGIN_ROOT}/scripts/regent.sh task <polecenie> [argumenty]
# Kod wyjścia: kod CLI (0 — ok, 1 — odrzucone przejście, 2 — błędne użycie, 4 — błąd bazy)
# albo 3 — brak CLI.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
CLI="$ROOT/tools/regent/dist/cli.js"

if [ "${REGENT_NO_CLI:-}" = 1 ]; then
  echo "regent.sh: CLI wyłączone (REGENT_NO_CLI=1)" >&2
  exit 3
fi

if [ -f "$CLI" ] && command -v node >/dev/null 2>&1; then
  exec node "$CLI" "$@"
fi
if command -v regent >/dev/null 2>&1; then
  exec regent "$@"
fi
echo "regent.sh: brak CLI regent — zbuduj tools/regent (npm install) albo dodaj regent do PATH" >&2
exit 3
