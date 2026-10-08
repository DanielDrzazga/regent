#!/usr/bin/env bash
# optimize-score.sh — wyrocznia pętli /regent:optimize: uruchamia zestaw evali skilla, liczy jedną
# linię wyniku i rozstrzyga keep/discard. Liczy skrypt, nie model (docs/plans/optimize.md).
#
# Użycie:
#   optimize-score.sh run <katalog-pluginu> <tag> <wynik.json> [opcje]   eval + linia wyniku
#       --runs N            przebiegi na przypadek (domyślnie z case.yaml)
#       --budget USD        twardy limit kosztu przebiegu evala (--max-cost-usd)
#       -j N                przypadki równolegle (domyślnie 2)
#       --files a,b         pliki kandydata (ścieżki względem pluginu) — do pola prompt=
#   optimize-score.sh score <wynik.json> [--plugin <katalog>] [--files a,b] [--keep-traces]
#                                                                          linia z gotowego JSON-a
#   optimize-score.sh decide <linia-najlepsza> <linia-kandydat> [--noise 0.05] [--tnoise <próg czasu>]
#                                                     keep|discard: powód (kod 0 = keep, 1 = discard)
#
# Linia wyniku (pola key=value, jedna linia):
#   quality  średni wynik przypadków (wynik przebiegu evala 0..1, średnia po przebiegach)
#   cost     suma median kosztu przypadków w USD (tokeny ważone cennikiem, z subagentami)
#   tokens   suma median tokenów przypadków (wejście + zapis i odczyt cache + wyjście, wszystkie
#            modele z result.modelUsage śladu); 0, gdy ślad niedostępny
#   seconds  suma median czasu przypadków
#   prompt   bajty plików kandydata (--files); 0 bez --files
#   spread   względny rozrzut kosztu zestawu: Σ(max − min) / Σ median przypadków (≈ 2σ różnicy
#            dwóch pomiarów — z baseline ×3 liczy się z niego próg szumu)
#   tspread  to samo dla czasu — czas waha się mocniej niż koszt, więc ma własny próg (--tnoise)
#   cases    <przypadek>:<wynik>,… (nazwa bez prefiksu do pierwszego „-”)
#   failed   <oceniacz>:<oblane>/<przebiegi>,… albo „-”
#   errors   przebiegi z błędem (timeout, crash) — 0 przy zdrowym evalu
#
# Reguła decide: bramka jakości — quality kandydata ≥ najlepszej i każdy przypadek z wynikiem 1.00
# zostaje na 1.00. Potem keep, gdy: koszt spada o więcej niż --noise; albo czas spada o więcej niż
# --tnoise, a koszt nie rośnie ponad --noise; albo koszt i czas w swoich progach, a prompt jest
# krótszy. Kandydat z errors > 0 → discard. --tnoise domyślnie równa się --noise.
#
# run uruchamia eval z --keep-temp (ślady dla tokens=) i po policzeniu usuwa katalogi sandboksów.
# Kody wyjścia: 0 — ok (decide: keep), 1 — decide: discard, 2 — błędne użycie, 3 — eval padł.

set -u

usage() { sed -n '2,32p' "$0" | sed -E 's/^# ?//'; exit 2; }
die() { echo "optimize-score.sh: $*" >&2; exit 2; }
command -v jq >/dev/null || die "brak jq (brew install jq / apt install jq)"

# Bajty plików kandydata, ścieżki względem pluginu, rozdzielone przecinkami.
prompt_bytes() {
  plugin=$1; files=$2; total=0
  [ -n "$files" ] || { echo 0; return; }
  old_ifs=$IFS; IFS=,
  for f in $files; do
    [ -f "$plugin/$f" ] || die "brak pliku kandydata: $plugin/$f"
    n=$(wc -c < "$plugin/$f" | tr -d ' ')
    total=$((total + n))
  done
  IFS=$old_ifs
  echo "$total"
}

# Tokeny przebiegu ze śladu (result.modelUsage obejmuje subagentów); brak śladu → 0.
trace_tokens() {
  [ -f "$1" ] || { echo 0; return; }
  jq -s '[.[] | select(.type == "result") | .modelUsage // {} | to_entries[]
          | .value | (.inputTokens // 0) + (.outputTokens // 0)
            + (.cacheReadInputTokens // 0) + (.cacheCreationInputTokens // 0)] | add // 0' "$1"
}

score() {
  json=$1; plugin=$2; files=$3; keep_traces=$4
  [ -f "$json" ] || die "brak wyniku evala: $json"
  # Tokeny per przebieg dopisujemy do JSON-a przed liczeniem median (jq nie czyta plików).
  toks=$(jq -r '.cases[] | .arms.with[]? | .tracePath // ""' "$json" | while IFS= read -r t; do
    trace_tokens "$t"
  done | jq -s '.')
  prompt=$(prompt_bytes "$plugin" "$files")
  jq -r --argjson toks "$toks" --arg prompt "$prompt" '
    def median: sort | if length == 0 then 0
      elif length % 2 == 1 then .[length / 2 | floor]
      else (.[length / 2 - 1] + .[length / 2]) / 2 end;
    def r2: . * 100 | round / 100;
    def r3: . * 1000 | round / 1000;
    def short: sub("^[^-]*-"; "");
    # Każdemu przebiegowi przypisz tokeny w kolejności z pliku.
    [.cases[] | {name, runs: [.arms.with[]?]}] as $cs
    | ([$cs[] | .runs | length] | add // 0) as $nruns
    | (reduce range(0; $cs | length) as $i ({off: 0, out: []};
        ($cs[$i].runs | length) as $n
        | .out += [$cs[$i] + {toks: $toks[.off:(.off + $n)]}] | .off += $n)).out as $cases
    | [$cases[] | {
        name: (.name | short),
        score: ([.runs[].score // 0] | if length == 0 then 0 else add / length end),
        cost: ([.runs[].costUsd // 0] | median),
        secs: ([.runs[].durationSeconds // 0] | median),
        toks: (.toks | median),
        range: ([.runs[].costUsd // 0] | if length < 2 then 0 else max - min end),
        trange: ([.runs[].durationSeconds // 0] | if length < 2 then 0 else max - min end),
        errors: ([.runs[] | select((.error // "") != "")] | length),
        failed: [.runs[].graders[]? | select(.passed == false and .scored != false) | .name]
      }] as $rows
    | ($rows | length) as $n
    | [$rows[].failed[]] as $f
    | ([$f | group_by(.)[] | "\(.[0]):\(length)/\($nruns)"] | join(",")) as $failed
    | "quality=\(if $n == 0 then 0 else ([$rows[].score] | add / $n | r3) end)"
      + " cost=\([$rows[].cost] | add // 0 | r3)"
      + " tokens=\([$rows[].toks] | add // 0 | floor)"
      + " seconds=\([$rows[].secs] | add // 0 | floor)"
      + " prompt=\($prompt)"
      + " spread=\(([$rows[].cost] | add // 0) as $c | if $c == 0 then 0 else ([$rows[].range] | add) / $c | r2 end)"
      + " tspread=\(([$rows[].secs] | add // 0) as $s | if $s == 0 then 0 else ([$rows[].trange] | add) / $s | r2 end)"
      + " cases=\([$rows[] | "\(.name):\(.score | r2)"] | join(","))"
      + " failed=\(if $failed == "" then "-" else $failed end)"
      + " errors=\([$rows[].errors] | add // 0)"
  ' "$json"
  if [ "$keep_traces" != 1 ]; then
    jq -r '.cases[] | .arms.with[]? | .tracePath // ""' "$json" | while IFS= read -r t; do
      case "$t" in */out/trace.jsonl) d=${t%/out/trace.jsonl} ;; *) continue ;; esac
      case "$d" in */claude-eval-*|*/e-*) chmod -R u+rwX "$d" 2>/dev/null; rm -rf "$d" ;; esac
    done
  fi
}

# Wartość pola z linii wyniku.
field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1; }

decide() {
  best=$1; cand=$2; noise=$3; tnoise=$4
  [ "$(field "$cand" errors)" = 0 ] || { echo "discard: przebiegi z błędem (errors=$(field "$cand" errors))"; return 1; }
  BQ=$(field "$best" quality) CQ=$(field "$cand" quality) \
  BK=$(field "$best" cost) CK=$(field "$cand" cost) \
  BT=$(field "$best" seconds) CT=$(field "$cand" seconds) \
  BP=$(field "$best" prompt) CP=$(field "$cand" prompt) \
  BC=$(field "$best" cases) CC=$(field "$cand" cases) NOISE=$noise TNOISE=$tnoise \
  awk 'BEGIN {
    if (ENVIRON["CQ"] + 0 < ENVIRON["BQ"] - 0.0005) { printf "discard: jakość %s < %s\n", ENVIRON["CQ"], ENVIRON["BQ"]; exit 1 }
    nb = split(ENVIRON["BC"], b, ","); nc = split(ENVIRON["CC"], c, ",")
    for (i = 1; i <= nc; i++) { split(c[i], kv, ":"); cs[kv[1]] = kv[2] }
    for (i = 1; i <= nb; i++) {
      split(b[i], kv, ":")
      if (kv[2] + 0 >= 1 && (!(kv[1] in cs) || cs[kv[1]] + 0 < 1)) {
        printf "discard: przypadek %s spadł z 1.00 do %s\n", kv[1], (kv[1] in cs ? cs[kv[1]] : "brak"); exit 1
      }
    }
    n = ENVIRON["NOISE"] + 0; tn = ENVIRON["TNOISE"] + 0; bk = ENVIRON["BK"] + 0; ck = ENVIRON["CK"] + 0; bt = ENVIRON["BT"] + 0; ct = ENVIRON["CT"] + 0
    dk = (bk > 0) ? (ck - bk) / bk : 0
    dt = (bt > 0) ? (ct - bt) / bt : 0
    if (dk < -n) { printf "keep: koszt %+.0f%% (%.3f → %.3f USD)\n", dk * 100, bk, ck; exit 0 }
    if (dt < -tn && dk <= n) { printf "keep: czas %+.0f%% (%d → %d s), koszt %+.0f%%\n", dt * 100, bt, ct, dk * 100; exit 0 }
    if (dk <= n && dk >= -n && dt <= tn && dt >= -tn && ENVIRON["CP"] + 0 < ENVIRON["BP"] + 0) {
      printf "keep: prostszy prompt (%d → %d B), koszt %+.0f%%, czas %+.0f%%\n", ENVIRON["BP"], ENVIRON["CP"], dk * 100, dt * 100; exit 0
    }
    printf "discard: koszt %+.0f%% (próg %.0f%%), czas %+.0f%% (próg %.0f%%), prompt %d → %d B\n", dk * 100, n * 100, dt * 100, tn * 100, ENVIRON["BP"], ENVIRON["CP"]
    exit 1
  }'
}

cmd=${1:-}
[ -n "$cmd" ] || usage
shift
case "$cmd" in
  -h|--help) usage ;;
  run)
    [ $# -ge 3 ] || usage
    plugin=$1; tag=$2; out=$3; shift 3
    runs=""; budget=""; jobs=2; files=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --runs) runs=$2; shift 2 ;;
        --budget) budget=$2; shift 2 ;;
        -j) jobs=$2; shift 2 ;;
        --files) files=$2; shift 2 ;;
        *) die "nieznana opcja: $1" ;;
      esac
    done
    [ -d "$plugin/evals" ] || die "brak $plugin/evals"
    set -- plugin eval "$plugin" --eval-dir evals --tag "$tag" --ablation none --scaffold \
      --trust-plugin --allow-tools Bash Write Edit --no-publish --keep-temp --json "$out" -j "$jobs" \
      --threshold 0
    [ -n "$runs" ] && set -- "$@" --runs "$runs"
    [ -n "$budget" ] && set -- "$@" --max-cost-usd "$budget"
    claude "$@" > "$out.log" 2>&1
    rc=$?
    # 0 — ok, 1 — próg (wyłączony przez --threshold 0), 2 — limit kosztu (wynik częściowy).
    if [ ! -f "$out" ]; then echo "optimize-score.sh: eval padł (kod $rc), log: $out.log" >&2; exit 3; fi
    score "$out" "$plugin" "$files" 0
    ;;
  score)
    [ $# -ge 1 ] || usage
    json=$1; shift; plugin=.; files=""; keep=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --plugin) plugin=$2; shift 2 ;;
        --files) files=$2; shift 2 ;;
        --keep-traces) keep=1; shift ;;
        *) die "nieznana opcja: $1" ;;
      esac
    done
    score "$json" "$plugin" "$files" "$keep"
    ;;
  decide)
    [ $# -ge 2 ] || usage
    best=$1; cand=$2; shift 2; noise=0.05; tnoise=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --noise) noise=$2; shift 2 ;;
        --tnoise) tnoise=$2; shift 2 ;;
        *) die "nieznana opcja: $1" ;;
      esac
    done
    decide "$best" "$cand" "$noise" "${tnoise:-$noise}"
    ;;
  *) usage ;;
esac
