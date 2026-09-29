#!/usr/bin/env bash
# task-sync.sh — hook SessionStart i Stop pluginu: zadania Regenta z artefaktów SDD.
#
# W projekcie SDD (ai/docs/ w korzeniu gita katalogu `cwd` z JSON-a hooka) woła przez regent.sh
# `regent task sync --source hook --session-id <id> --transcript-path <plik>`: stan zmian
# z ai/changes/, taski z tasks.md i transkrypt sesji do wykrywania utknięcia. Poza projektem SDD
# nie startuje Node.
#
# Użycie (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/task-sync.sh"
# Wejście: JSON hooka na stdin — pola cwd, session_id, transcript_path, hook_event_name (bez jq).
# Kod wyjścia: zawsze 0. Nic na stdout — stdout hooka SessionStart trafia do kontekstu. Brak CLI
# (regent.sh → kod 3) → cisza; inny błąd CLI → linia w hook.log obok bazy zadań.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}

# Wartość pierwszego klucza JSON-a jako tekst (bez jq/pythona); \" \\ \/ \n \t w stringu rozwinięte.
field() {
  printf '%s' "$1" | LC_ALL=C awk -v key="\"$2\"" '
    { s = s $0 "\n" }
    END {
      i = index(s, key)
      if (!i) exit
      s = substr(s, i + length(key))
      if (!sub(/^[ \t\r\n]*:[ \t\r\n]*"/, "", s)) exit
      esc = 0; n = length(s)
      for (j = 1; j <= n; j++) {
        c = substr(s, j, 1)
        if (esc) { printf "%s", (c == "n") ? "\n" : (c == "t") ? "\t" : (c == "r") ? "" : c; esc = 0; continue }
        if (c == "\\") { esc = 1; continue }
        if (c == "\"") break
        printf "%s", c
      }
    }'
}

input=$(cat)
dir=$(field "$input" cwd)
[ -n "$dir" ] || dir=${CLAUDE_PROJECT_DIR:-$PWD}
[ -d "$dir" ] || exit 0

# Korzeń projektu jak w CLI: pierwszy katalog z .git w górę; poza repo — sam katalog.
root=$dir
d=${dir%/}
while [ -n "$d" ]; do
  if [ -e "$d/.git" ]; then root=$d; break; fi
  d=${d%/*}
done
[ -d "$root/ai/docs" ] || exit 0

session=$(field "$input" session_id)
transcript=$(field "$input" transcript_path)
event=$(field "$input" hook_event_name)

set -- task sync --source hook
if [ -n "$session" ]; then
  set -- "$@" --session-id "$session"
  [ -n "$transcript" ] && set -- "$@" --transcript-path "$transcript"
fi
# stdout CLI do /dev/null, stderr do zmiennej — na wypadek błędu
err=$(cd "$root" && "$BASH" "$ROOT/scripts/regent.sh" "$@" 2>&1 >/dev/null)
code=$?
case "$code" in 0|3) exit 0 ;; esac

db=${REGENT_DB:-${XDG_STATE_HOME:-${HOME:-}/.local/state}/regent/regent.db}
case "$db" in */*) logdir=${db%/*} ;; *) logdir=. ;; esac
log="$logdir/hook.log"
mkdir -p "$logdir" 2>/dev/null || exit 0
# log nie rośnie bez końca: powyżej 256 KB poprzedni idzie do hook.log.1
if [ -f "$log" ] && [ "$(($(wc -c < "$log")))" -gt 262144 ]; then mv -f "$log" "$log.1" 2>/dev/null; fi
printf '%s %s %s: kod %s — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${event:-hook}" "$root" "$code" \
  "$(printf '%s' "$err" | tr '\n' ' ')" >> "$log" 2>/dev/null
exit 0
