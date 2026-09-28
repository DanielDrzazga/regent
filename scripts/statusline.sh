#!/usr/bin/env bash
# Statusline: licznik kontekstu z progiem ostrzegawczym.
# Wejście: JSON na stdin (Claude Code przekazuje context_window.* gotowe policzone).

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
IN=$(echo "$input"  | jq -r '.context_window.total_input_tokens  // 0')
OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
MAX=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# effort: JSON statusline (gdy CC go poda) → env CLAUDE_EFFORT → settings.json modelSettings[id].effortLevel
EFFORT=$(echo "$input" | jq -r '(.effort.level // .effort // .model.effort) | strings' 2>/dev/null)
[ -z "$EFFORT" ] && EFFORT="$CLAUDE_EFFORT"
if [ -z "$EFFORT" ]; then
  MODEL_ID=$(echo "$input" | jq -r '.model.id // empty' | sed 's/\[.*\]$//')
  EFFORT=$(jq -r --arg id "$MODEL_ID" '.modelSettings[$id].effortLevel // .effortLevel // empty' \
    "$HOME/.claude/settings.json" 2>/dev/null)
fi
[ -n "$EFFORT" ] && MODEL="$MODEL · $EFFORT"

TOTAL=$((IN + OUT))

# Suma narastająca sesji z transkryptu (główna sesja + subagenci), dedup po message.id.
# NOWE = input + cache write + output (tokeny faktycznie nowe), ALL = z cache read.
# Szczegóły per prompt: ${CLAUDE_PLUGIN_ROOT}/scripts/session-tokens.sh
TRANSCRIPT=$(echo "$input" | jq -r '.transcript_path // empty')
NEW=0; ALL=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  files=("$TRANSCRIPT")
  for s in "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do [ -f "$s" ] && files+=("$s"); done
  # cache: licz ponownie tylko gdy któryś plik urósł (wc -c — stat -f/-c różni się między BSD a GNU)
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

# tokeny w skrócie (k)
fmt() { local n=${1:-0}
  if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n/1000000)) $((n%1000000/100000))
  elif [ "$n" -ge 1000 ];    then echo "$((n/1000))k"
  else echo "$n"; fi; }
TOTAL_H=$(fmt "$TOTAL")
MAX_H=$(fmt "$MAX")

# kolor + etykieta wg BEZWZGLĘDNEJ liczby tokenów (nie % okna — przy 1M % ostrzega za późno).
# <150k zielony | 150-250k żółty (obserwuj) | >250k czerwony (czas na /clear)
if   [ "$TOTAL" -ge 250000 ]; then C="\033[31m"; TAG="⛔ czas na /clear"
elif [ "$TOTAL" -ge 150000 ]; then C="\033[33m"; TAG="⚠ obserwuj"
else                               C="\033[32m"; TAG=""
fi
R="\033[0m"; DIM="\033[2m"

printf "${DIM}%s${R} ${C}ctx %s%% (%s/%s)${R} ${C}%s${R} ${DIM}tokens %s (z cache %s)${R} ${DIM}\$%.2f${R}" \
  "$MODEL" "$USED_PCT" "$TOTAL_H" "$MAX_H" "$TAG" "$(fmt "$NEW")" "$(fmt "$ALL")" "$COST"
