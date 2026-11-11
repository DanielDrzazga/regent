#!/usr/bin/env bash
# session-context.sh — the plugin's SessionStart / SubagentStart hook: injects one context/ file.
#
# A plugin does not load CLAUDE.md, so rules reach the context through hooks. One file per
# call: Claude Code truncates a single hook's output to 10,000 characters.
#   session  — plain stdout (Claude Code adds it to the session context)
#   subagent — JSON hookSpecificOutput.additionalContext; Explore and Plan skipped, because they
#              skip CLAUDE.md too
#   always   — always;  sdd — only in an SDD project (ai/docs/ exists in the project root)
#
# Usage (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-context.sh" <session|subagent> <always|sdd> <file>
#   e.g. session-context.sh session always role.md
# Input: hook JSON on stdin (subagent: the agent_type field). Exit code: always 0 — missing context
# must not block the session; wrong usage → message on stderr.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
PROJECT=${CLAUDE_PROJECT_DIR:-$PWD}
event=${1:-}; scope=${2:-}; file=${3:-}

usage() { echo "session-context.sh: $1 — usage: <session|subagent> <always|sdd> <file>" >&2; exit 0; }
case "$event" in session|subagent) ;; *) usage "unknown event '$event'" ;; esac
case "$scope" in always|sdd) ;; *) usage "unknown scope '$scope'" ;; esac
case "$file" in ''|*/*) usage "a context/ file name without a path" ;; esac
src="$ROOT/context/$file"
[ -f "$src" ] || usage "missing $src"

[ "$scope" = sdd ] && [ ! -d "$PROJECT/ai/docs" ] && exit 0

if [ "$event" = session ]; then
  cat "$src"
  exit 0
fi

# subagent: agent_type from the hook JSON without jq (first value of the key).
agent=$(cat | LC_ALL=C sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
case "$agent" in Explore|Plan) exit 0 ;; esac

# Content as a JSON string: \ → \\, " → \", tab → \t, CR removed, lines joined with \n.
TAB=$(printf '\t')
printf '{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"'
LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$TAB/\\\\t/g" -e "s/$(printf '\r')//g" "$src" \
  | LC_ALL=C awk 'BEGIN { nl = sprintf("%c", 92) "n" } { if (NR > 1) printf "%s", nl; printf "%s", $0 }'
printf '"}}\n'
exit 0
