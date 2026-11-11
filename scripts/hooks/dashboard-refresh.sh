#!/usr/bin/env bash
# dashboard-refresh.sh — the plugin's hook that keeps the HTML board of an SDD project fresh.
#
# Starts `scripts/dashboard.sh --hook <event>` in the background and returns at once, so Claude Code does not
# wait for the build. Only in a project with ai/; elsewhere it exits before starting anything. The board lies
# at one path per project (~/.cache/regent/boards/<project>-<checksum>/index.html), and every session of the
# project refreshes it: dashboard.sh builds one at a time and throttles "tool" to one build per 20 s.
# When the last session of the project ends, nothing is left running — the board keeps its last state.
#
# Usage (hooks/hooks.json):  bash "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/dashboard-refresh.sh" <start|turn|tool>
#   start — SessionStart   turn — Stop, SubagentStop   tool — PostToolUse (file and shell tools)
# Exit code: always 0. Writes nothing to stdout — a SessionStart hook's stdout goes to the context.

set -u

ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}
event=${1:-}
case "$event" in start|turn|tool) ;; *) echo "dashboard-refresh.sh: usage: <start|turn|tool>" >&2; exit 0 ;; esac
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
[ -d ai ] || exit 0

# detached from the hook's stdin/stdout, so the hook ends now and the build carries on
( "$BASH" "$ROOT/scripts/dashboard.sh" --hook "$event" </dev/null >/dev/null 2>&1 & )
exit 0
