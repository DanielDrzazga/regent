#!/usr/bin/env bash
# eval-ab.sh — A/B of two refs on one eval tag: a baseline and a candidate worktree, eval-score.sh run
# on each, the noise threshold from the baseline spread, and the keep/discard decision (docs/evals.md).
#
# Usage:
#   eval-ab.sh <base-ref> <candidate-ref> <tag> [options]
#       <tag>          an eval tag, e.g. propose-train, apply-train, wiki-holdout
#       --runs N       runs per case on both sides (default 3 — fewer gives no usable noise threshold)
#       --budget USD   hard cost cap per side (eval --max-cost-usd); a capped side counts as errored
#       --files a,b    candidate files for the prompt= field (paths relative to the plugin)
#       --no-bash      pass --no-bash to eval-score.sh (both sides)
#       --fresh-base   ignore a cached baseline and run it again
#       --private-evals DIR  add the eval sets in DIR (DIR/<set>/<case>/case.yaml) to both sides for this
#                      run only — for cases on private code that must never be committed to this repo
#       --keep         keep the worktrees (default: removed at the end)
#
# Usage limits: a run that reports a usage or rate limit stops the A/B at once (exit 4) — no further
# side is started, so the rest of your window is not spent on runs that would fail. A clean baseline
# (errors=0) is cached per base commit, tag, runs and eval version in evals/results/base-cache.tsv,
# so after a limit stop (or for another candidate) the baseline is not paid for again.
#
# A ref without evals/ (e.g. main before the evals were merged) gets evals/ and the eval scripts
# copied from this checkout, so both sides run the same cases. Output: both result lines, the decision,
# and a row in evals/results/ab.tsv (tab-separated).
# Exit codes: 0 keep, 1 discard, 2 usage, 3 eval failed or errored runs, 4 usage limit reached.

set -u

usage() { sed -n '2,25p' "$0" | sed -E 's/^# ?//'; exit 2; }
die() { echo "eval-ab.sh: $*" >&2; exit 2; }

[ $# -ge 3 ] || usage
base=$1; cand=$2; tag=$3; shift 3
runs=3; files=""; nobash=""; keep=0; budget=""; fresh=0; private=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2; shift 2 ;;
    --budget) budget=$2; shift 2 ;;
    --files) files=$2; shift 2 ;;
    --no-bash) nobash="--no-bash"; shift ;;
    --fresh-base) fresh=1; shift ;;
    --private-evals) private=$2; shift 2 ;;
    --keep) keep=1; shift ;;
    *) die "unknown option: $1" ;;
  esac
done

repo=$(git rev-parse --show-toplevel 2>/dev/null) || die "run inside the regent repo"
[ -d "$repo/evals" ] && [ -f "$repo/scripts/eval-score.sh" ] || die "this checkout has no evals/ — switch to a branch with them"
base_sha=$(git -C "$repo" rev-parse -q --verify "$base^{commit}") || die "unknown ref: $base"
git -C "$repo" rev-parse -q --verify "$cand^{commit}" >/dev/null || die "unknown ref: $cand"

results="$repo/evals/results"; mkdir -p "$results"
if [ -n "$private" ]; then
  [ -d "$private" ] || die "--private-evals: $private is not a directory"
  private=$(cd "$private" && pwd)
  case "$private/" in "$repo"/*) die "--private-evals must live outside this repo — private cases are never committed" ;; esac
fi
stamp=$(date +%Y%m%d-%H%M%S)
LIMIT_RE='usage limit|rate[ _-]?limit|limit reached|hit your [a-z ]*limit|limit will reset|resets at'

# The eval version: the cases, fixtures and the scoring script this checkout runs on both sides.
evals_ver=$( { find "$repo/evals" ${private:+"$private"} -type f -not -path "$results/*" -print0 | LC_ALL=C sort -z \
  | xargs -0 cat; cat "$repo/scripts/eval-score.sh"; } | shasum | cut -c1-12)
cache="$results/base-cache.tsv"
key="$base_sha:$tag:r$runs:$evals_ver:${nobash:-bash}:${files:--}"

work=""
cleanup() {
  [ -n "$work" ] || return
  [ "$keep" = 1 ] && { echo "worktrees kept in $work"; return; }
  git -C "$repo" worktree remove --force "$work/base" 2>/dev/null
  git -C "$repo" worktree remove --force "$work/cand" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

setup() { # $1 side, $2 ref
  [ -n "$work" ] || work=$(mktemp -d "${TMPDIR:-/tmp}/regent-ab.XXXXXX")
  git -C "$repo" worktree add -q --detach "$work/$1" "$2" || die "worktree for $2 failed"
  if [ ! -d "$work/$1/evals" ]; then
    cp -R "$repo/evals" "$work/$1/evals"
    rm -rf "$work/$1/evals/results"
  fi
  [ -f "$work/$1/scripts/eval-score.sh" ] || cp "$repo/scripts/eval-score.sh" "$work/$1/scripts/"
  # Private sets live only in the temporary worktree; it is removed at the end of the run.
  [ -z "$private" ] || cp -R "$private/." "$work/$1/evals/"
}

field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1; }

# A side's run reported a usage or rate limit (in the eval log or in a run's error).
limit_hit() { # $1 result json
  { cat "$1.log" 2>/dev/null; jq -r '.. | .error? // empty' "$1" 2>/dev/null; } | grep -qiE "$LIMIT_RE"
}

run() { # $1 side, $2 ref → result line on stdout; exit 4 on a usage limit
  out="$results/ab-$stamp-$tag-$1.json"
  echo "eval-ab.sh: $1 ($2) — $tag ×$runs …" >&2
  # shellcheck disable=SC2086
  line=$(bash "$work/$1/scripts/eval-score.sh" run "$work/$1" "$tag" "$out" --runs "$runs" \
    ${budget:+--budget "$budget"} ${files:+--files "$files"} $nobash)
  rc=$?
  if limit_hit "$out"; then
    echo "eval-ab.sh: usage limit reached during the $1 run — stopped, nothing else started." >&2
    [ "$1" = cand ] && echo "eval-ab.sh: the baseline is cached; rerun the same command after the reset." >&2
    exit 4
  fi
  [ "$rc" = 0 ] || { echo "eval-ab.sh: the $1 eval failed" >&2; exit 3; }
  printf '%s\n' "$line"
}

bline=""
if [ "$fresh" = 0 ] && [ -f "$cache" ]; then
  bline=$(awk -F '\t' -v k="$key" '$1 == k { l = $2 } END { print l }' "$cache")
  [ -z "$bline" ] || echo "eval-ab.sh: base ($base) — cached baseline for $tag ×$runs" >&2
fi
if [ -z "$bline" ]; then
  setup base "$base"
  bline=$(run base "$base") || exit $?
  # A baseline with errored runs is no reference: no cache, no candidate run.
  if [ "$(field "$bline" errors)" != 0 ]; then
    echo "base $base: $bline" >&2
    echo "eval-ab.sh: the baseline has errored runs — fix the cause above; no candidate run" >&2
    exit 3
  fi
  printf '%s\t%s\n' "$key" "$bline" >> "$cache"
fi

setup cand "$cand"
cline=$(run cand "$cand") || exit $?

noise=$(awk -v s="$(field "$bline" spread)" 'BEGIN { printf "%.2f", (s + 0 > 0.05) ? s : 0.05 }')
tnoise=$(awk -v s="$(field "$bline" tspread)" 'BEGIN { printf "%.2f", (s + 0 > 0.05) ? s : 0.05 }')
decision=$(bash "$repo/scripts/eval-score.sh" decide "$bline" "$cline" --noise "$noise" --tnoise "$tnoise")
code=$?

echo "base $base: $bline"
echo "cand $cand: $cline"
echo "$decision (noise $noise, tnoise $tnoise)"

tsv="$results/ab.tsv"
[ -f "$tsv" ] || printf 'date\ttag\tbase\tcandidate\tdecision\tbase_line\tcandidate_line\n' > "$tsv"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$stamp" "$tag" "$base" "$cand" "$decision" "$bline" "$cline" >> "$tsv"
exit "$code"
