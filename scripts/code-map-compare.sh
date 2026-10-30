#!/usr/bin/env bash
# code-map-compare.sh — porównanie kosztu/jakości z grafem kodu (Graphify) i bez, na wariantach
# scaffoldu evala (tag bez grafu / tag z grafem). Dwa przebiegi optimize-score.sh run, ten sam
# --runs/--budget, werdykt optimize-score.sh decide (bez grafu = baseline, z grafem = kandydat).
# docs/plans/code-map-graphify.md.
#
# Użycie:
#   code-map-compare.sh <katalog-pluginu> <tag-bez-grafu> <tag-z-grafem> <out-prefix>
#       [--runs N] [--budget USD] [-j N] [--no-bash] [--noise 0.05] [--tnoise próg]
#
#   --runs/--budget/-j/--no-bash — identyczne dla obu przebiegów, przechodzą do
#     `optimize-score.sh run`. --no-bash: zapytania Graphify idą przez Bash, więc graf nie
#     zadziała — ostrzeżenie na stderr, porównanie i tak liczy obie strony.
#   --noise/--tnoise — przechodzą do `optimize-score.sh decide`.
#
# Wynik: dwie linie wyniku (bez grafu, z grafem), różnice quality/cost/tokens/seconds i jedna
# linia werdyktu `optimize-score.sh decide` (bez grafu = best/baseline, z grafem = kandydat).
# Kody wyjścia: 0 — keep, 1 — discard, 2 — błędne użycie, 3 — eval padł.
#
# Para przypadków (wariant bez grafu / z grafem) ma mieć TĘ SAMĄ nazwę w `case.yaml` (`name:`) —
# `decide` dopasowuje przypadki best↔kandydat po nazwie (po prefiksie skilla); różne nazwy
# wyglądają jak zniknięcie przypadku ze score 1.00 i zawsze kończą się `discard`.

set -u
here="$(cd "$(dirname "$0")" && pwd)"
SCORE="$here/optimize-score.sh"

usage() { sed -n '2,19p' "$0" | sed -E 's/^# ?//'; exit 2; }
die() { echo "code-map-compare.sh: $*" >&2; exit 2; }

[ $# -ge 4 ] || usage
plugin=$1; tag_without=$2; tag_with=$3; out=$4; shift 4

runs=""; budget=""; jobs=""; nobash=0; noise=""; tnoise=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2; shift 2 ;;
    --budget) budget=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --no-bash) nobash=1; shift ;;
    --noise) noise=$2; shift 2 ;;
    --tnoise) tnoise=$2; shift 2 ;;
    *) die "nieznana opcja: $1" ;;
  esac
done
[ "$nobash" = 1 ] && echo "code-map-compare.sh: --no-bash — zapytania Graphify idą przez Bash, graf nie zadziała; porównanie i tak liczy obie strony" >&2

run_variant() { # $1 tag, $2 plik wyniku
  set -- run "$plugin" "$1" "$2"
  [ -n "$runs" ] && set -- "$@" --runs "$runs"
  [ -n "$budget" ] && set -- "$@" --budget "$budget"
  [ -n "$jobs" ] && set -- "$@" -j "$jobs"
  [ "$nobash" = 1 ] && set -- "$@" --no-bash
  bash "$SCORE" "$@"
}

without=$(run_variant "$tag_without" "$out-bez-grafu.json") || exit $?
with=$(run_variant "$tag_with" "$out-z-grafem.json") || exit $?

echo "bez grafu:  $without"
echo "z grafem:   $with"

field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1; }
for f in quality cost tokens seconds; do
  b=$(field "$without" "$f"); c=$(field "$with" "$f")
  d=$(awk -v b="$b" -v c="$c" 'BEGIN { if (b + 0 == 0) print "n/a"; else printf "%+.1f%%", (c - b) / b * 100 }')
  echo "różnica $f: $b → $c ($d)"
done

decide() {
  set -- decide "$without" "$with"
  [ -n "$noise" ] && set -- "$@" --noise "$noise"
  [ -n "$tnoise" ] && set -- "$@" --tnoise "$tnoise"
  bash "$SCORE" "$@"
}
decide
