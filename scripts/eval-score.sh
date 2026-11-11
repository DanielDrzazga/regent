#!/usr/bin/env bash
# eval-score.sh — the eval oracle: runs a skill's eval set, computes one result line and decides
# keep/discard between a baseline and a candidate. The script counts, not the model (docs/evals.md).
#
# Usage:
#   eval-score.sh run <plugin-dir> <tag> <result.json> [options]       eval + result line
#       --runs N            runs per case (default: from case.yaml)
#       --budget USD        hard cost limit of the eval run (--max-cost-usd)
#       -j N                cases in parallel (default 2)
#       --files a,b         candidate files (paths relative to the plugin) — for the prompt= field
#       --no-bash           without Bash (--disallow-tools Bash): a machine without a sandbox (bwrap)
#   eval-score.sh score <result.json> [--plugin <dir>] [--files a,b] [--keep-traces]
#                                                                  result line from an existing JSON
#   eval-score.sh decide <best-line> <candidate-line> [--noise 0.05] [--tnoise <time threshold>]
#                                                  keep|discard: reason (exit 0 = keep, 1 = discard)
#
# Result line (key=value fields, one line):
#   quality  mean case score (eval run score 0..1, averaged over runs)
#   cost     sum of per-case median cost in USD (tokens weighted by pricing, subagents included)
#   tokens   sum of per-case median tokens (input + cache write and read + output, every model in
#            the trace's result.modelUsage); 0 when the trace is missing
#   models   the same per model family: opus:<tokens>,sonnet:<tokens>,… ("-" without traces)
#   seconds  sum of per-case median time
#   prompt   bytes of the candidate files (--files); 0 without --files
#   spread   relative cost spread of the set: Σ(max − min) / Σ case medians (≈ 2σ of the difference
#            of two measurements — a baseline run ×3 gives the noise threshold)
#   tspread  the same for time — time varies more than cost, so it has its own threshold (--tnoise)
#   cases    <case>:<score>,… (name without the prefix up to the first "-")
#   failed   <grader>:<failed>/<runs>,… or "-"
#   errors   runs that errored (timeout, crash) — 0 for a healthy eval
#
# The decide rule: quality gate — the candidate's quality ≥ the best one's, and every case at 1.00
# stays at 1.00. Then keep when: cost drops by more than --noise; or time drops by more than
# --tnoise while cost does not rise beyond --noise; or cost and time stay within their thresholds and
# the prompt is shorter. A candidate with errors > 0 → discard. --tnoise defaults to --noise.
#
# run calls the eval with --keep-temp (traces for tokens=) and removes the sandbox dirs after scoring.
# Exit codes: 0 — ok (decide: keep), 1 — decide: discard, 2 — wrong usage, 3 — the eval failed.

set -u

usage() { sed -n '2,38p' "$0" | sed -E 's/^# ?//'; exit 2; }
die() { echo "eval-score.sh: $*" >&2; exit 2; }
command -v jq >/dev/null || die "jq not found (brew install jq / apt install jq)"

# Bytes of the candidate files, paths relative to the plugin, comma-separated.
prompt_bytes() {
  plugin=$1; files=$2; total=0
  [ -n "$files" ] || { echo 0; return; }
  old_ifs=$IFS; IFS=,
  for f in $files; do
    [ -f "$plugin/$f" ] || die "candidate file not found: $plugin/$f"
    n=$(wc -c < "$plugin/$f" | tr -d ' ')
    total=$((total + n))
  done
  IFS=$old_ifs
  echo "$total"
}

# Tokens of one run per model family from its trace (result.modelUsage includes subagents):
# a JSON object {"opus": n, "sonnet": n}; no trace → {}.
trace_tokens() {
  [ -f "$1" ] || { echo '{}'; return; }
  jq -sc '[.[] | select(.type == "result") | .modelUsage // {} | to_entries[]
          | {model: (.key | if test("opus") then "opus" elif test("sonnet") then "sonnet"
                            elif test("haiku") then "haiku" else . end),
             n: ((.value.inputTokens // 0) + (.value.outputTokens // 0)
                 + (.value.cacheReadInputTokens // 0) + (.value.cacheCreationInputTokens // 0))}]
          | group_by(.model) | map({key: .[0].model, value: (map(.n) | add)}) | from_entries' "$1"
}

score() {
  json=$1; plugin=$2; files=$3; keep_traces=$4
  [ -f "$json" ] || die "eval result not found: $json"
  # Per-run tokens are added before the medians are computed (jq does not read files).
  toks=$(jq -r '.cases[] | .arms.with[]? | .tracePath // ""' "$json" | while IFS= read -r t; do
    trace_tokens "$t"
  done | jq -sc '.')
  prompt=$(prompt_bytes "$plugin" "$files")
  jq -r --argjson toks "$toks" --arg prompt "$prompt" '
    def median: sort | if length == 0 then 0
      elif length % 2 == 1 then .[length / 2 | floor]
      else (.[length / 2 - 1] + .[length / 2]) / 2 end;
    def r2: . * 100 | round / 100;
    def r3: . * 1000 | round / 1000;
    def short: sub("^[^-]*-"; "");
    # Assign tokens to every run in file order.
    [.cases[] | {name, runs: [.arms.with[]?]}] as $cs
    | ([$cs[] | .runs | length] | add // 0) as $nruns
    | (reduce range(0; $cs | length) as $i ({off: 0, out: []};
        ($cs[$i].runs | length) as $n
        | .out += [$cs[$i] + {toks: $toks[.off:(.off + $n)]}] | .off += $n)).out as $cases
    | [$cases[] | (.toks | map(keys[]) | unique) as $models | {
        name: (.name | short),
        score: ([.runs[].score // 0] | if length == 0 then 0 else add / length end),
        cost: ([.runs[].costUsd // 0] | median),
        secs: ([.runs[].durationSeconds // 0] | median),
        toks: ([.toks[] | [.[]] | add // 0] | median),
        models: (. as $c | [$models[] as $m | {key: $m, value: ([$c.toks[] | .[$m] // 0] | median)}] | from_entries),
        range: ([.runs[].costUsd // 0] | if length < 2 then 0 else max - min end),
        trange: ([.runs[].durationSeconds // 0] | if length < 2 then 0 else max - min end),
        errors: ([.runs[] | select((.error // "") != "")] | length),
        failed: [.runs[].graders[]? | select(.passed == false and .scored != false) | .name]
      }] as $rows
    | ($rows | length) as $n
    | [$rows[].failed[]] as $f
    | ([$f | group_by(.)[] | "\(.[0]):\(length)/\($nruns)"] | join(",")) as $failed
    | ([$rows[].models | to_entries[]] | group_by(.key)
        | map("\(.[0].key):\(map(.value) | add | floor)") | join(",")) as $models
    | "quality=\(if $n == 0 then 0 else ([$rows[].score] | add / $n | r3) end)"
      + " cost=\([$rows[].cost] | add // 0 | r3)"
      + " tokens=\([$rows[].toks] | add // 0 | floor)"
      + " models=\(if $models == "" then "-" else $models end)"
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

# A field's value from a result line.
field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1; }

decide() {
  best=$1; cand=$2; noise=$3; tnoise=$4
  [ "$(field "$cand" errors)" = 0 ] || { echo "discard: runs with errors (errors=$(field "$cand" errors))"; return 1; }
  BQ=$(field "$best" quality) CQ=$(field "$cand" quality) \
  BK=$(field "$best" cost) CK=$(field "$cand" cost) \
  BT=$(field "$best" seconds) CT=$(field "$cand" seconds) \
  BP=$(field "$best" prompt) CP=$(field "$cand" prompt) \
  BC=$(field "$best" cases) CC=$(field "$cand" cases) NOISE=$noise TNOISE=$tnoise \
  awk 'BEGIN {
    if (ENVIRON["CQ"] + 0 < ENVIRON["BQ"] - 0.0005) { printf "discard: quality %s < %s\n", ENVIRON["CQ"], ENVIRON["BQ"]; exit 1 }
    nb = split(ENVIRON["BC"], b, ","); nc = split(ENVIRON["CC"], c, ",")
    for (i = 1; i <= nc; i++) { split(c[i], kv, ":"); cs[kv[1]] = kv[2] }
    for (i = 1; i <= nb; i++) {
      split(b[i], kv, ":")
      if (kv[2] + 0 >= 1 && (!(kv[1] in cs) || cs[kv[1]] + 0 < 1)) {
        printf "discard: case %s dropped from 1.00 to %s\n", kv[1], (kv[1] in cs ? cs[kv[1]] : "missing"); exit 1
      }
    }
    n = ENVIRON["NOISE"] + 0; tn = ENVIRON["TNOISE"] + 0; bk = ENVIRON["BK"] + 0; ck = ENVIRON["CK"] + 0; bt = ENVIRON["BT"] + 0; ct = ENVIRON["CT"] + 0
    dk = (bk > 0) ? (ck - bk) / bk : 0
    dt = (bt > 0) ? (ct - bt) / bt : 0
    if (dk < -n) { printf "keep: cost %+.0f%% (%.3f → %.3f USD)\n", dk * 100, bk, ck; exit 0 }
    if (dt < -tn && dk <= n) { printf "keep: time %+.0f%% (%d → %d s), cost %+.0f%%\n", dt * 100, bt, ct, dk * 100; exit 0 }
    if (dk <= n && dk >= -n && dt <= tn && dt >= -tn && ENVIRON["CP"] + 0 < ENVIRON["BP"] + 0) {
      printf "keep: simpler prompt (%d → %d B), cost %+.0f%%, time %+.0f%%\n", ENVIRON["BP"], ENVIRON["CP"], dk * 100, dt * 100; exit 0
    }
    printf "discard: cost %+.0f%% (threshold %.0f%%), time %+.0f%% (threshold %.0f%%), prompt %d → %d B\n", dk * 100, n * 100, dt * 100, tn * 100, ENVIRON["BP"], ENVIRON["CP"]
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
    runs=""; budget=""; jobs=2; files=""; tools="Bash Write Edit"; nobash=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --runs) runs=$2; shift 2 ;;
        --budget) budget=$2; shift 2 ;;
        -j) jobs=$2; shift 2 ;;
        --files) files=$2; shift 2 ;;
        --no-bash) tools="Write Edit"; nobash=1; shift ;;
        *) die "unknown option: $1" ;;
      esac
    done
    [ -d "$plugin/evals" ] || die "$plugin/evals not found"
    set -- plugin eval "$plugin" --eval-dir evals --tag "$tag" --ablation none --scaffold \
      --trust-plugin --allow-tools $tools --no-publish --keep-temp --json "$out" -j "$jobs" \
      --threshold 0
    [ "$nobash" = 1 ] && set -- "$@" --disallow-tools Bash
    [ -n "$runs" ] && set -- "$@" --runs "$runs"
    [ -n "$budget" ] && set -- "$@" --max-cost-usd "$budget"
    # EVAL_CLEAN_HOME=1 — the eval runs with an empty HOME, so its Bash sandbox does not see a ~/.docker
    # that Docker Desktop keeps filling with symlinks (the sandbox refuses those). A clean HOME has no
    # login: pass a token from `claude setup-token` in CLAUDE_CODE_OAUTH_TOKEN (it uses your plan).
    if [ "${EVAL_CLEAN_HOME:-}" = 1 ]; then
      [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || die "EVAL_CLEAN_HOME=1 needs CLAUDE_CODE_OAUTH_TOKEN (claude setup-token) — docs/evals.md"
      ehome=$(mktemp -d "${TMPDIR:-/tmp}/eval-home.XXXXXX")
      # Skills commit during the eval (apply, bugfix): an identity, as the test project's own commits have.
      printf '[user]\n\tname = Regent Eval\n\temail = eval@example.invalid\n' > "$ehome/.gitconfig"
      HOME=$ehome claude "$@" > "$out.log" 2>&1
      rc=$?
      chmod -R u+rwX "$ehome" 2>/dev/null; rm -rf "$ehome"
    else
      claude "$@" > "$out.log" 2>&1
      rc=$?
    fi
    # 0 — ok, 1 — threshold (disabled by --threshold 0), 2 — cost limit (partial result).
    if [ ! -f "$out" ]; then echo "eval-score.sh: the eval failed (exit $rc), log: $out.log" >&2; exit 3; fi
    # EVAL_KEEP_TRACES=1 keeps the run sandboxes (traces, the test project as the skill left it).
    keep_runs=0; [ "${EVAL_KEEP_TRACES:-}" = 1 ] && keep_runs=1
    score "$out" "$plugin" "$files" "$keep_runs"
    # After scoring: the eval also keeps sealed sandboxes of runs without a trace — remove those too.
    [ "$keep_runs" = 1 ] || sed -n 's/^.*kept \(\/[^:]*\/e-[A-Za-z0-9]*\):.*$/\1/p' "$out.log" | while IFS= read -r d; do
      chmod -R u+rwX "$d" 2>/dev/null; rm -rf "$d"
    done
    first=$(jq -r '[.cases[] | .arms.with[]? | .error // empty] | first // empty' "$out")
    [ -z "$first" ] || echo "eval-score.sh: a run errored — $first" >&2
    ;;
  score)
    [ $# -ge 1 ] || usage
    json=$1; shift; plugin=.; files=""; keep=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --plugin) plugin=$2; shift 2 ;;
        --files) files=$2; shift 2 ;;
        --keep-traces) keep=1; shift ;;
        *) die "unknown option: $1" ;;
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
        *) die "unknown option: $1" ;;
      esac
    done
    decide "$best" "$cand" "$noise" "${tnoise:-$noise}"
    ;;
  *) usage ;;
esac
