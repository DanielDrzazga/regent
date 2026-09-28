#!/usr/bin/env bash
# session-tokens.sh — zużycie tokenów w sesji Claude Code, rozbite na prompty (tylko odczyt).
#
# Czyta transkrypt ~/.claude/projects/<projekt>/<sesja>.jsonl (+ subagenci z <sesja>/subagents/)
# i sumuje message.usage z każdego wywołania API. Wywołania są deduplikowane po message.id
# (jedna odpowiedź modelu bywa zapisana w kilku liniach z tym samym usage).
#
# Użycie:  bash ${CLAUDE_PLUGIN_ROOT}/scripts/session-tokens.sh [sesja]
#   (bez argumentu)     najnowsza sesja projektu z bieżącego katalogu
#   <session-id>        sesja o tym ID (szukana we wszystkich projektach)
#   <plik.jsonl>        wskazany transkrypt
#
# Kolumny (per prompt użytkownika, z subagentami uruchomionymi w tym prompcie):
#   calls   liczba wywołań API (główna sesja + subagenci)
#   nowe    input + cache write — tokeny wejścia, których model wcześniej nie widział
#   cache   cache read — kontekst wysyłany ponownie przy każdym wywołaniu (tani, ale liczony)
#   out     output (z thinking)
#   razem   nowe + cache + out  — to, co faktycznie przetworzono
#   narast. suma „razem" od początku sesji
#   ctx     rozmiar kontekstu głównej sesji po ostatnim wywołaniu promptu
#
# Kod wyjścia: 0 = OK, 2 = błędne użycie / brak transkryptu.

set -u

usage() { sed -n '2,21p' "$0" | sed -E 's/^# ?//'; exit 2; }
command -v jq >/dev/null || { echo "ERROR brak jq (brew install jq)"; exit 2; }

PROJECTS="$HOME/.claude/projects"
arg="${1:-}"
case "$arg" in
  -h|--help) usage ;;
  "")
    dir="$PROJECTS/$(pwd | sed 's/[^A-Za-z0-9]/-/g')"
    file=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
    [ -n "$file" ] || { echo "ERROR brak transkryptów w $dir"; exit 2; } ;;
  *.jsonl) file="$arg" ;;
  *) file=$(ls "$PROJECTS"/*/"$arg".jsonl 2>/dev/null | head -1) ;;
esac
[ -n "${file:-}" ] && [ -f "$file" ] || { echo "ERROR nie znaleziono transkryptu: $arg"; exit 2; }

sub_dir="${file%.jsonl}/subagents"
subs=()
[ -d "$sub_dir" ] && for s in "$sub_dir"/*.jsonl; do [ -f "$s" ] && subs+=("$s"); done

# Każdy plik czytany osobno i po kolei: wywołanie API przypisujemy do ostatniego promptId
# widzianego w tym pliku (promptId mają tylko linie „user"). Subagent dziedziczy promptId
# promptu, który go uruchomił.
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
  def calls_pl: if . == 1 then "wywołanie"
                elif (. % 10 >= 2 and . % 10 <= 4 and (. % 100 < 12 or . % 100 > 14)) then "wywołania"
                else "wywołań" end;
  def pad($n): tostring | (" " * ([$n - length, 0] | max)) + .;

  # prompty w kolejności pojawienia się: tekst użytkownika danego promptId, a gdy go brak —
  # tura automatyczna (isMeta: wiadomość od subagenta w tle, task-notification) jako „[auto]"
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
            [{txt: "(bez przypisanego promptu)", ts: "", n: ($o | length), subs: 0,
              new: ($o | map(.new) | add), cache: ($o | map(.cache) | add),
              out: ($o | map(.out) | add), ctx: null}]
          else [] end )
  | map(. + {tot: (.new + .cache + .out)})
  | . as $rows
  | ("  #  czas   calls    nowe   cache     out   razem  narast.    ctx  prompt",
     ( reduce range(0; $rows | length) as $i ({acc: 0, lines: []};
         ($rows[$i]) as $r | .acc += $r.tot
         | .lines += [
             "\($i + 1 | pad(3))  \(($r.ts | .[11:16]) | pad(5))  \((if $r.subs > 0 then "\($r.n)*" else "\($r.n)" end) | pad(5))  \($r.new | k | pad(6))  \($r.cache | k | pad(6))  \($r.out | k | pad(6))  \($r.tot | k | pad(6))  \(.acc | k | pad(7))  \((if $r.ctx then ($r.ctx | k) else "-" end) | pad(5))  \($r.txt | .[0:50])"
           ])
       | .lines[] ),
     "",
     ( ($rows | map(.new) | add // 0) as $n | ($rows | map(.cache) | add // 0) as $c
       | ($rows | map(.out) | add // 0) as $o | ($rows | map(.n) | add // 0) as $calls
       | "RAZEM: \($calls) \($calls | calls_pl) API | nowe \($n | k) | cache read \($c | k) | out \($o | k)",
         "       przetworzone łącznie: \($n + $c + $o | k)  |  bez cache read: \($n + $o | k)" ),
     ( if any($rows[]; .subs > 0) then "       * prompt z wywołaniami subagentów (wliczone)" else empty end ))
'

# Koszt z ostatniego zapisu cost-state (liczony przez Claude Code, jeśli jest w transkrypcie)
cost=$(jq -r 'select(.type == "cost-state") | .totalCostUSD' "$file" 2>/dev/null | tail -1)
[ -n "$cost" ] && printf '       koszt wg Claude Code: $%.2f\n' "$cost"
echo "SESJA: $(basename "$file" .jsonl)"
