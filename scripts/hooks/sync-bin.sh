#!/usr/bin/env bash
# sync-bin.sh — hook SessionStart pluginu: kopiuje narzędzia wglądu do stałej ścieżki.
#
# Katalog pluginu (${CLAUDE_PLUGIN_ROOT}) zmienia się z każdą wersją, a statusLine
# w ~/.claude/settings.json potrzebuje stałej ścieżki. ${CLAUDE_PLUGIN_DATA} przetrwa aktualizacje,
# więc statusline.sh i session-tokens.sh trafiają do ${CLAUDE_PLUGIN_DATA}/bin/ — tylko gdy się różnią.
#
# Użycie (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/sync-bin.sh"
# Kod wyjścia: zawsze 0. Nic nie pisze na stdout — stdout hooka SessionStart trafia do kontekstu.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
DATA=${CLAUDE_PLUGIN_DATA:-}
[ -n "$DATA" ] || { echo "sync-bin.sh: brak CLAUDE_PLUGIN_DATA" >&2; exit 0; }
mkdir -p "$DATA/bin" 2>/dev/null || { echo "sync-bin.sh: nie można utworzyć $DATA/bin" >&2; exit 0; }

for f in statusline.sh session-tokens.sh; do
  src="$ROOT/scripts/$f"
  dst="$DATA/bin/$f"
  [ -f "$src" ] || continue
  cmp -s "$src" "$dst" && continue
  # kopia przez plik tymczasowy — działająca statusline nigdy nie czyta połowy pliku
  cp "$src" "$dst.tmp.$$" && chmod +x "$dst.tmp.$$" && mv -f "$dst.tmp.$$" "$dst"
done
exit 0
