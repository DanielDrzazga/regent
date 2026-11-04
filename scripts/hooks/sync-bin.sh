#!/usr/bin/env bash
# sync-bin.sh — the plugin's SessionStart hook: copies the insight tools to a stable path.
#
# The plugin directory (${CLAUDE_PLUGIN_ROOT}) changes with every version, while statusLine
# in ~/.claude/settings.json needs a stable path. ${CLAUDE_PLUGIN_DATA} survives updates,
# so statusline.sh and session-tokens.sh go to ${CLAUDE_PLUGIN_DATA}/bin/ — only when they differ.
#
# Usage (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/sync-bin.sh"
# Exit code: always 0. Writes nothing to stdout — a SessionStart hook's stdout goes to the context.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
DATA=${CLAUDE_PLUGIN_DATA:-}
[ -n "$DATA" ] || { echo "sync-bin.sh: CLAUDE_PLUGIN_DATA not set" >&2; exit 0; }
mkdir -p "$DATA/bin" 2>/dev/null || { echo "sync-bin.sh: cannot create $DATA/bin" >&2; exit 0; }

for f in statusline.sh session-tokens.sh; do
  src="$ROOT/scripts/$f"
  dst="$DATA/bin/$f"
  [ -f "$src" ] || continue
  cmp -s "$src" "$dst" && continue
  # copy via a temp file — a running statusline never reads half a file
  cp "$src" "$dst.tmp.$$" && chmod +x "$dst.tmp.$$" && mv -f "$dst.tmp.$$" "$dst"
done
exit 0
