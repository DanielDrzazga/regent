#!/usr/bin/env bash
# session-tokens.sh — token usage of a Claude Code session, broken down by prompt (read-only).
#
# Reads the transcript ~/.claude/projects/<project>/<session>.jsonl (+ subagents from <session>/subagents/)
# and sums message.usage of every API call. Calls are deduplicated by message.id
# (one model response may be written in several lines with the same usage).
#
# Usage:  bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-tokens.sh [session]
#   (no argument)       the latest session of the project in the current directory
#   <session-id>        the session with this ID (searched in all projects)
#   <file.jsonl>        the given transcript
#
# Columns (per user prompt, including subagents launched in that prompt):
#   calls   number of API calls (main session + subagents)
#   new     input + cache write — input tokens the model has not seen before
#   cache   cache read — context resent with every call (cheap, but counted)
#   out     output (including thinking)
#   total   new + cache + out  — what was actually processed
#   cumul.  running sum of "total" since the session start
#   ctx     main session context size after the prompt's last call
#
# Exit code: 0 = OK, 2 = wrong usage / no transcript.

set -u

usage() { sed -n '2,21p' "$0" | sed -E 's/^# ?//'; exit 2; }
command -v jq >/dev/null || { echo "ERROR jq not found (brew install jq)"; exit 2; }

PROJECTS="$HOME/.claude/projects"
arg="${1:-}"
case "$arg" in
  -h|--help) usage ;;
  "")
    dir="$PROJECTS/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
    file=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
    [ -n "$file" ] || { echo "ERROR no transcripts in $dir"; exit 2; } ;;
  *.jsonl) file="$arg" ;;
  *) file=$(ls "$PROJECTS"/*/"$arg".jsonl 2>/dev/null | head -1) ;;
esac
[ -n "${file:-}" ] && [ -f "$file" ] || { echo "ERROR transcript not found: $arg"; exit 2; }

sub_dir="${file%.jsonl}/subagents"
subs=()
[ -d "$sub_dir" ] && for s in "$sub_dir"/*.jsonl; do [ -f "$s" ] && subs+=("$s"); done

# Each file is read separately and in order: an API call is assigned to the last promptId
# seen in that file (only "user" lines have promptId). A subagent inherits the promptId
# of the prompt that launched it.
calls() {
  jq -c --arg src "$2" '
    def ptext: .message.content
      | if type == "string" then .
        else (map(select(.type == "text") | .text) | first // "") end;
    select(.type == "user" or .type == "assistant")
    | if .type == "user" then
        {k: "u", pid: .promptId, ts: .timestamp, meta: (.isMeta // false),
         txt: (if .message.content | type == "array" and any(.[]; .type == "tool_result")
               then null else (ptext | gsub("\\s+"; " ") | ltrimstr(" ")) end)}
      else
        {k: "a", id: .message.id, u: .message.usage}
      end' "$1" |
  jq -sc --arg src "$2" '
    reduce .[] as $r ({pid: null, out: []};
      if $r.k == "u" then
        .pid = ($r.pid // .pid)
        | if $r.txt != null and $src != "sub" then .out += [{k: "p", pid: .pid, ts: $r.ts, meta: $r.meta, txt: $r.txt}] else . end
      elif $r.u != null then
        .out += [{k: "c", pid: .pid, id: $r.id, src: $src, u: $r.u}]
      else . end)
    | .out[]'
}

{
  calls "$file" main
  for s in ${subs[@]+"${subs[@]}"}; do calls "$s" sub; done
} | jq -rs '
  def k: if . >= 1000000 then "\(. / 100000 | floor / 10)M"
         elif . >= 1000 then "\(. / 1000 | round)k" else "\(.)" end;
  def calls_word: if . == 1 then "call" else "calls" end;
  def pad($n): tostring | (" " * ([$n - length, 0] | max)) + .;

  # prompts in order of appearance: the user text of the promptId, or when missing —
  # an automatic turn (isMeta: background subagent message, task-notification) as "[auto]"
  (map(select(.k == "p")) | group_by(.pid)
   | map((map(select(.meta | not)) | first) // (first | .txt = "[auto] " + .txt))
   | sort_by(.ts)) as $prompts
  | (map(select(.k == "c")) | unique_by(.src + .id)
     | map(. + {new: ((.u.input_tokens // 0) + (.u.cache_creation_input_tokens // 0)),
                cache: (.u.cache_read_input_tokens // 0),
                out: (.u.output_tokens // 0)})) as $calls
  | ($prompts | map(.pid)) as $known
  | [ $prompts[] as $p
      | ($calls | map(select(.pid == $p.pid))) as $c
      | ($c | map(select(.src == "main")) | last) as $lm
      | {txt: $p.txt, ts: $p.ts, n: ($c | length), subs: ($c | map(select(.src == "sub")) | length),
         new: ($c | map(.new) | add // 0), cache: ($c | map(.cache) | add // 0),
         out: ($c | map(.out) | add // 0),
         ctx: (if $lm then $lm.new + $lm.cache else null end)} ]
    + ( ($calls | map(select(.pid as $x | $known | index($x) | not))) as $o
        | if ($o | length) > 0 then
            [{txt: "(no assigned prompt)", ts: "", n: ($o | length), subs: 0,
              new: ($o | map(.new) | add), cache: ($o | map(.cache) | add),
              out: ($o | map(.out) | add), ctx: null}]
          else [] end )
  | map(. + {tot: (.new + .cache + .out)})
  | . as $rows
  | ("  #   time  calls     new   cache     out   total   cumul.    ctx  prompt",
     ( reduce range(0; $rows | length) as $i ({acc: 0, lines: []};
         ($rows[$i]) as $r | .acc += $r.tot
         | .lines += [
             "\($i + 1 | pad(3))  \(($r.ts | .[11:16]) | pad(5))  \((if $r.subs > 0 then "\($r.n)*" else "\($r.n)" end) | pad(5))  \($r.new | k | pad(6))  \($r.cache | k | pad(6))  \($r.out | k | pad(6))  \($r.tot | k | pad(6))  \(.acc | k | pad(7))  \((if $r.ctx then ($r.ctx | k) else "-" end) | pad(5))  \($r.txt | .[0:50])"
           ])
       | .lines[] ),
     "",
     ( ($rows | map(.new) | add // 0) as $n | ($rows | map(.cache) | add // 0) as $c
       | ($rows | map(.out) | add // 0) as $o | ($rows | map(.n) | add // 0) as $calls
       | "TOTAL: \($calls) API \($calls | calls_word) | new \($n | k) | cache read \($c | k) | out \($o | k)",
         "       processed in total: \($n + $c + $o | k)  |  without cache read: \($n + $o | k)" ),
     ( if any($rows[]; .subs > 0) then "       * prompt with subagent calls (included)" else empty end ))
'

# Cost from the last cost-state entry (computed by Claude Code, if present in the transcript)
cost=$(jq -r 'select(.type == "cost-state") | .totalCostUSD' "$file" 2>/dev/null | tail -1)
[ -n "$cost" ] && printf '       cost per Claude Code: $%.2f\n' "$cost"
echo "SESSION: $(basename "$file" .jsonl)"
