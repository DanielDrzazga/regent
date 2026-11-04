#!/usr/bin/env bash
# Statusline: context counter with a warning threshold.
# Input: JSON on stdin (Claude Code passes context_window.* precomputed).

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
IN=$(echo "$input"  | jq -r '.context_window.total_input_tokens  // 0')
OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
MAX=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# effort: statusline JSON (when CC provides it) → env CLAUDE_EFFORT → settings.json modelSettings[id].effortLevel
EFFORT=$(echo "$input" | jq -r '(.effort.level // .effort // .model.effort) | strings' 2>/dev/null)
[ -z "$EFFORT" ] && EFFORT="$CLAUDE_EFFORT"
if [ -z "$EFFORT" ]; then
  MODEL_ID=$(echo "$input" | jq -r '.model.id // empty' | sed 's/\[.*\]$//')
  EFFORT=$(jq -r --arg id "$MODEL_ID" '.modelSettings[$id].effortLevel // .effortLevel // empty' \
    "$HOME/.claude/settings.json" 2>/dev/null)
fi
[ -n "$EFFORT" ] && MODEL="$MODEL · $EFFORT"

TOTAL=$((IN + OUT))

# Cumulative session total from the transcript (main session + subagents), dedup by message.id.
# NEW = input + cache write + output (truly new tokens), ALL = including cache read.
# Per-prompt details: ${CLAUDE_PLUGIN_ROOT}/scripts/session-tokens.sh
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
NEW=0; ALL=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  files=("$TRANSCRIPT")
  for s in "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do [ -f "$s" ] && files+=("$s"); done
  # cache: recount only when some file grew (wc -c — stat -f/-c differs between BSD and GNU)
  key=$(for f in "${files[@]}"; do wc -c < "$f"; done | tr -d ' ' | tr '\n' ' ')
  cache="${TMPDIR:-/tmp}/claude-statusline-$(basename "$TRANSCRIPT" .jsonl)"
  if [ -f "$cache" ] && [ "$(head -1 "$cache")" = "$key" ]; then
    read -r NEW ALL < <(sed -n 2p "$cache")
  else
    read -r NEW ALL < <(grep -h '"usage"' "${files[@]}" \
      | jq -r 'select(.type == "assistant" and .message.usage != null) | .message
               | "\(.id) \((.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens // 0) + (.usage.output_tokens // 0)) \(.usage.cache_read_input_tokens // 0)"' 2>/dev/null \
      | awk '!seen[$1]++ { n += $2; c += $3 } END { printf "%d %d\n", n, n + c }')
    printf '%s\n%s %s\n' "$key" "${NEW:-0}" "${ALL:-0}" > "$cache" 2>/dev/null
  fi
fi

# tokens in short form (k)
fmt() { local n=${1:-0}
  if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n/1000000)) $((n%1000000/100000))
  elif [ "$n" -ge 1000 ];    then echo "$((n/1000))k"
  else echo "$n"; fi; }
TOTAL_H=$(fmt "$TOTAL")
MAX_H=$(fmt "$MAX")

# color + label by the ABSOLUTE token count (not window % — at 1M the % warns too late).
# <150k green | 150-250k yellow (watch) | >250k red (time to /clear)
if   [ "$TOTAL" -ge 250000 ]; then C="\033[31m"; TAG="⛔ time to /clear"
elif [ "$TOTAL" -ge 150000 ]; then C="\033[33m"; TAG="⚠ watch"
else                               C="\033[32m"; TAG=""
fi
R="\033[0m"; DIM="\033[2m"

printf "${DIM}%s${R} ${C}ctx %s%% (%s/%s)${R} ${C}%s${R} ${DIM}tokens %s (with cache %s)${R} ${DIM}\$%.2f${R}" \
  "$MODEL" "$USED_PCT" "$TOTAL_H" "$MAX_H" "$TAG" "$(fmt "$NEW")" "$(fmt "$ALL")" "$COST"
