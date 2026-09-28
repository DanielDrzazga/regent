#!/usr/bin/env bash
# session-context.sh — hook SessionStart / SubagentStart pluginu: wstrzykuje jeden plik context/.
#
# Plugin nie wczytuje CLAUDE.md, więc reguły trafiają do kontekstu przez hooki. Jeden plik na
# wywołanie: Claude Code obcina wyjście pojedynczego hooka do 10 000 znaków.
#   session  — zwykły stdout (Claude Code dodaje go do kontekstu sesji)
#   subagent — JSON hookSpecificOutput.additionalContext; Explore i Plan pomijane, bo pomijają
#              też CLAUDE.md
#   always   — zawsze;  sdd — tylko w projekcie SDD (jest ai/docs/ w korzeniu projektu)
#
# Użycie (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-context.sh" <session|subagent> <always|sdd> <plik>
#   np. session-context.sh session always role.md
# Wejście: JSON hooka na stdin (subagent: pole agent_type). Kod wyjścia: zawsze 0 — brak kontekstu
# nie może blokować sesji; błędne użycie → komunikat na stderr.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
PROJECT=${CLAUDE_PROJECT_DIR:-$PWD}
event=${1:-}; scope=${2:-}; file=${3:-}

usage() { echo "session-context.sh: $1 — użycie: <session|subagent> <always|sdd> <plik>" >&2; exit 0; }
case "$event" in session|subagent) ;; *) usage "nieznane zdarzenie '$event'" ;; esac
case "$scope" in always|sdd) ;; *) usage "nieznany zakres '$scope'" ;; esac
case "$file" in ''|*/*) usage "plik z context/ bez ścieżki" ;; esac
src="$ROOT/context/$file"
[ -f "$src" ] || usage "brak $src"

[ "$scope" = sdd ] && [ ! -d "$PROJECT/ai/docs" ] && exit 0

if [ "$event" = session ]; then
  cat "$src"
  exit 0
fi

# subagent: agent_type z JSON-a hooka bez jq (pierwsza wartość klucza).
agent=$(cat | LC_ALL=C sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
case "$agent" in Explore|Plan) exit 0 ;; esac

# Treść jako string JSON: \ → \\, " → \", tab → \t, CR usunięty, linie łączone przez \n.
TAB=$(printf '\t')
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"'
LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$TAB/\\\\t/g" -e "s/$(printf '\r')//g" "$src" \
  | LC_ALL=C awk 'BEGIN { nl = sprintf("%c", 92) "n" } { if (NR > 1) printf "%s", nl; printf "%s", $0 }'
printf '"}}\n'
exit 0
