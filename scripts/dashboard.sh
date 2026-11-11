#!/usr/bin/env bash
# dashboard.sh — HTML kanban board of the SDD cycle: every change in ai/changes/ by stage.
#
# Writes data.js (the files of active changes, task commit dates, drift since verification, the requirements
# index, Claude Code usage per run from scripts/usage.sh and a one-line summary per archived change, with its
# usage.md totals) next to a copy of templates/dashboard.html, plus
# archive/<dir>.js per archived change, which the page loads only when that change is opened. The page works
# from file:// with no server and re-reads data.js every 2 s, so with --watch it follows the work live.
# The archive part is rebuilt only when ai/changes/archive/ changed, so a long history does not slow
# down --watch. Read-only for the project: it writes only to the output directory.
#
# Usage (in the project root):  bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh [--out DIR] [--watch [SEC]] [--open]
#   --out DIR      output directory (default: ${REGENT_BOARDS:-~/.cache/regent/boards}/<project>-<checksum>,
#                  the same path for every session of the project, so a browser tab stays valid)
#   --watch [SEC]  rebuild data.js every SEC seconds (default 3) until Ctrl-C
#   --open         open the board in the default browser
#   --hook EVENT   quiet build for the plugin hooks (scripts/hooks/dashboard-refresh.sh): start | turn | tool;
#                  one build at a time per board (a request during a build makes it run once more),
#                  "tool" at most every 20 s, "start" also checks every archived file
# Output: "Board: <path to index.html>". Exit code: 0 = board written, 2 = wrong usage or no ai/.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
TEMPLATE="$HERE/../templates/dashboard.html"
CHECK="$HERE/sdd-check.sh"
ARCH=ai/changes/archive
TOOL_INTERVAL=20

usage() { sed -n '2,20p' "$0" | sed -E 's/^# ?//'; exit 2; }

out=""
watch=0
open=0
hook=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) [ $# -ge 2 ] || usage; out=$2; shift 2 ;;
    --watch)
      watch=3; shift
      case "${1:-}" in
        ''|--*) ;;
        *[!0-9]*|0) usage ;;
        *) watch=$1; shift ;;
      esac ;;
    --open) open=1; shift ;;
    --hook)
      [ $# -ge 2 ] || usage
      case "$2" in start|turn|tool) hook=$2 ;; *) usage ;; esac
      shift 2 ;;
    *) usage ;;
  esac
done

if [ ! -d ai ]; then
  [ -n "$hook" ] && exit 0
  echo "ERROR no ai/ directory — run in the SDD project root (/regent:init first)"; exit 2
fi
[ -f "$TEMPLATE" ] || { echo "ERROR missing $TEMPLATE"; exit 2; }

project=$(basename "$(pwd)")
if [ -z "$out" ]; then
  sum=$(pwd | cksum | cut -d' ' -f1)
  out="${REGENT_BOARDS:-${HOME:-/tmp}/.cache/regent/boards}/$project-$sum"
fi
mkdir -p "$out" 2>/dev/null || { echo "ERROR cannot create $out"; exit 2; }

git=0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git=1

# Records for the awk writers, one per line, tab-separated (few processes: Git Bash on Windows pays per fork):
#   P project branch | I index-file | U dir last-commit-date | K sha date subject
#   C name dir drift (active change) | A name dir archived-date (archived change) | F relative-path path
# An F record belongs to the C or A before it.

# K records for the "commit: <hash>" traces in the given tasks.md files.
commits() {
  [ $git -eq 1 ] || return 0
  shas=$(cat "$@" 2>/dev/null | grep -oE 'commit: [0-9a-f]{7,40}' | sed 's/commit: //' | sort -u \
    | git cat-file --batch-check='%(objectname) %(objecttype)' 2>/dev/null | awk '$2 == "commit" { print $1 }')
  # shellcheck disable=SC2086
  [ -n "$shas" ] && git log --no-walk=unsorted --format='K%x09%H%x09%cs%x09%s' $shas 2>/dev/null
  return 0
}

files() {
  for f in "$1"/*.md "$1"/*/*.md; do
    [ -f "$f" ] && printf 'F\t%s\t%s\n' "${f#"$1"/}" "$f"
  done
}

manifest_active() {
  branch=""
  [ $git -eq 1 ] && branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  printf 'P\t%s\t%s\n' "$project" "$branch"
  "$BASH" "$CHECK" index > "$out/.index" 2>/dev/null
  printf 'I\t%s\n' "$out/.index"
  "$BASH" "$HERE/usage.sh" --tsv --cache "$out/usage-cache" > "$out/.usage" 2>/dev/null
  printf 'X\t%s\n' "$out/.usage"
  if [ $git -eq 1 ]; then
    # newest first, so the first date seen per change directory is its last commit
    git -c core.quotePath=false log --format='>%cs' --name-only --relative -- ai/changes 2>/dev/null | awk '
      /^>/ { d = substr($0, 2); next }
      /^ai\/changes\/[^\/]+\// {
        split($0, p, "/")
        if (p[3] != "archive" && !(p[3] in seen)) { seen[p[3]] = 1; printf "U\t%s\t%s\n", p[3], d }
      }'
  fi
  commits ai/changes/*/tasks.md
  for d in ai/changes/*/; do
    d=${d%/}
    [ -d "$d" ] && [ "$d" != "$ARCH" ] || continue
    dir=${d##*/}
    drift=0
    if [ -f "$d/verification.md" ] && grep -qE '^Verdict:[[:space:]]*\**PASS' "$d/verification.md"; then
      drift=$("$BASH" "$CHECK" drift "$dir" 2>/dev/null | grep -c '^WARN .* changed since verification')
    fi
    printf 'C\t%s\t%s\t%s\n' "$dir" "$dir" "${drift:-0}"
    files "$d"
  done
}

manifest_archive() {
  commits "$ARCH"/*/tasks.md
  for d in "$ARCH"/*/; do
    d=${d%/}
    [ -d "$d" ] || continue
    dir=${d##*/}
    name=$dir
    archived=""
    case "$dir" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-?*) archived=${dir:0:10}; name=${dir:11} ;; esac
    printf 'A\t%s\t%s\t%s\n' "$name" "$dir" "$archived"
    files "$d"
  done
}

# Escaping by concatenation, not gsub: backslashes in a gsub replacement differ between awks (macOS awk, mawk, gawk).
AWK_LIB='
function esc(s,   o) {
  gsub(/\r/, "", s); o = ""
  while (match(s, /[\\"]/)) { o = o substr(s, 1, RSTART - 1) "\\" substr(s, RSTART, 1); s = substr(s, RSTART + 1) }
  return o s
}
function q(s) { return "\"" esc(s) "\"" }
function file(p,   l, o, n) {
  o = ""; n = 0
  while ((getline l < p) > 0) o = o (n++ ? "\\n" : "") esc(l)
  close(p)
  return "\"" o "\""
}
'

ACTIVE_AWK='
function head() {
  if (started++) return
  printf "\"project\":%s,\"branch\":%s,\"index\":%s,\"usage\":%s,\"commits\":\"%s\",\"changes\":[", \
    q(proj), q(br), (idx == "" ? "\"\"" : idx), (usg == "" ? "\"\"" : usg), com
}
$1 == "P" { proj = $2; br = $3; next }
$1 == "I" { idx = file($2); next }
$1 == "X" { usg = file($2); next }
$1 == "U" { upd[$2] = $3; next }
$1 == "K" { com = com (com == "" ? "" : "\\n") esc($2) "\t" esc($3) "\t" esc($4); next }
$1 == "C" {
  head()
  printf "%s{\"name\":%s,\"dir\":%s,\"place\":\"active\",\"archived\":\"\",\"updated\":\"%s\",\"drift\":%d,\"files\":[", \
    (nc++ ? "]}," : ""), q($2), q($3), upd[$3], $4 + 0
  nf = 0; next
}
$1 == "F" { printf "%s[%s,%s]", (nf++ ? "," : ""), q($2), file($3); next }
END { head(); printf "%s]", (nc ? "]}" : "") }
'

# Archived change → a summary record on stdout (the fields the archive table shows, read like
# sdd-check.sh meta_field and its tasks parser) and archive/<dir>.js with its files and commits.
ARCHIVE_AWK='
function meta(l, k,   v, a) {
  gsub(/[*`]/, "", l)
  if (l ~ ("^\\|[ \t]*" k "[ \t]*\\|")) { v = l; sub("^\\|[ \t]*" k "[ \t]*\\|", "", v); sub(/\|.*$/, "", v) }
  else if (l ~ ("^" k ":[ \t]")) { v = l; sub("^" k ":", "", v) }
  else return ""
  sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
  if (v !~ /\//) { split(v, a, /[ \t]+/); v = a[1] }
  return v
}
function scan(p, rel,   l, o, n, fence, insum, s, h) {
  o = ""; n = 0; fence = 0; insum = 0
  while ((getline l < p) > 0) {
    o = o (n++ ? "\\n" : "") esc(l)
    sub(/\r$/, "", l)
    if (rel == "proposal.md") {
      if (st == "") st = meta(l, "Status")
      if (ty == "") ty = meta(l, "Type")
      if (ty == "") ty = meta(l, "Typ")
      if (tk == "") tk = meta(l, "Ticket")
      if (cr == "") cr = meta(l, "Created")
      if (l ~ /^### Summary/) { insum = 1; continue }
      if (insum && l ~ /^#/) insum = 0
      else if (insum && sm == "" && l ~ /[^ \t]/ && l !~ /^[ \t]*(\[|\||<!--)/) { sm = l; insum = 0 }
    } else if (rel == "tasks.md") {
      if (l ~ /^[ \t]*(```|~~~)/) { fence = !fence; continue }
      if (fence) continue
      if (l ~ /^[ \t]*- \[.?\]/) { tot++; if (l ~ /^[ \t]*- \[[xX]\]/) dn++ }
      if (size == "" && match(l, /Size:[ \t]*[SML]/)) size = substr(l, RSTART + RLENGTH - 1, 1)
      s = l
      while (match(s, /commit: [0-9a-f]+/)) {
        h = substr(s, RSTART + 8, 7); s = substr(s, RSTART + RLENGTH)
        if ((h in kc) && !(h in seenc)) { seenc[h] = 1; cm = cm (cm == "" ? "" : "\\n") kc[h] }
      }
    } else if (rel == "verification.md") {
      if (vd == "") vd = meta(l, "Verdict")
      if (vdt == "") vdt = meta(l, "Date")
    } else if (rel == "usage.md") {
      if (ucost == "") ucost = meta(l, "Cost USD")
      if (uact == "") uact = meta(l, "Active seconds")
      if (ureg == "") ureg = meta(l, "Regent")
    }
  }
  close(p)
  return "\"" o "\""
}
function flush(   p) {
  if (dir == "") return
  printf "%s{\"name\":%s,\"dir\":%s,\"archived\":\"%s\",\"type\":%s,\"status\":%s,\"ticket\":%s,\"created\":%s,\"size\":\"%s\",\"done\":%d,\"total\":%d,\"verdict\":%s,\"vdate\":%s,\"summary\":%s,\"cost\":%s,\"active\":%s,\"regent\":%s}", \
    (na++ ? "," : ""), q(name), q(dir), arch, q(ty), q(st), q(tk), q(cr), size, dn, tot, q(vd), q(vdt), q(sm), q(ucost), q(uact), q(ureg)
  p = ENVIRON["OUT"] "/archive/" dir ".js"
  printf "window.regentArchive(%s,{\"commits\":\"%s\",\"files\":[%s]});\n", q(dir), cm, fl > p
  close(p)
  dir = ""
}
$1 == "K" { kc[substr($2, 1, 7)] = esc($2) "\t" esc($3) "\t" esc($4); next }
$1 == "A" {
  flush()
  name = $2; dir = $3; arch = $4
  ty = st = tk = cr = size = vd = vdt = sm = cm = fl = ucost = uact = ureg = ""; dn = tot = nf = 0; split("", seenc)
  next
}
$1 == "F" { fl = fl (nf++ ? "," : "") "[" q($2) "," scan($3, $2) "]"; next }
END { flush() }
'

# Whether the archive changed since the last build. The first build of a run checks every file (`find`);
# a --watch tick checks only the mtime of the archive directory, which changes when /regent:archive moves
# a change in (a stat per file costs seconds on Windows with a long history). An edit inside an already
# archived change shows on the next run.
archive_fresh() {
  [ -d "$ARCH" ] && [ -f "$out/.archive" ] && [ -f "$out/.astamp" ] && [ ! "$0" -nt "$out/.astamp" ] || return 1
  if [ "$1" = full ]; then
    [ -z "$(find "$ARCH" -newer "$out/.astamp" 2>/dev/null | head -n 1)" ]
    return
  fi
  [ ! "$ARCH" -nt "$out/.astamp" ]
}

archive_part() {
  archive_fresh "$1" && return 0
  touch "$out/.astamp.new"
  rm -rf "$out/archive"
  mkdir -p "$out/archive"
  manifest_archive | OUT="$out" awk -F'\t' "$AWK_LIB$ARCHIVE_AWK" > "$out/.archive.new"
  mv -f "$out/.archive.new" "$out/.archive"
  mv -f "$out/.astamp.new" "$out/.astamp"
}

# data.js is rewritten only when the data changed — the page re-renders only then.
build() {
  cmp -s "$TEMPLATE" "$out/index.html" || cp "$TEMPLATE" "$out/index.html"
  archive_part "$1"
  {
    manifest_active | awk -F'\t' "$AWK_LIB$ACTIVE_AWK"
    printf ',"archive":['
    cat "$out/.archive"
    printf ']'
  } > "$out/.body.new"
  if [ -f "$out/data.js" ] && cmp -s "$out/.body.new" "$out/.body"; then
    rm -f "$out/.body.new"
    return 0
  fi
  sig=$(cksum < "$out/.body.new" | cut -d' ' -f1)
  {
    printf 'window.regentBoard({"generated":"%s","sig":"%s",' "$(date '+%Y-%m-%d %H:%M:%S')" "$sig"
    cat "$out/.body.new"
    printf '});\n'
  } > "$out/data.js.tmp" && mv -f "$out/data.js.tmp" "$out/data.js"
  mv -f "$out/.body.new" "$out/.body"
}

open_board() {
  f="$out/index.html"
  case "$(uname -s)" in
    Darwin) open "$f" ;;
    MINGW*|MSYS*|CYGWIN*) explorer.exe "$(cygpath -w "$f")" ;;
    *) if command -v wslview >/dev/null 2>&1; then wslview "$f"
       elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$f" >/dev/null 2>&1 &
       else echo "INFO  no browser opener found — open the file by hand"; fi ;;
  esac
  return 0
}

# Hook builds: several sessions of one project share the board, so one builds at a time; a request that
# arrives during a build leaves .pending and the running build goes once more. A killed build's lock
# expires after 5 minutes.
if [ -n "$hook" ]; then
  if [ "$hook" = tool ] && [ -f "$out/.hook-at" ]; then
    last=$(cat "$out/.hook-at" 2>/dev/null)
    [ $(( $(date +%s) - ${last:-0} )) -lt $TOOL_INTERVAL ] && exit 0
  fi
  date +%s > "$out/.hook-at"
  lock="$out/.lock"
  [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ] && rmdir "$lock" 2>/dev/null
  if ! mkdir "$lock" 2>/dev/null; then
    touch "$out/.pending"
    exit 0
  fi
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  mode=quick
  [ "$hook" = start ] && mode=full
  while :; do
    rm -f "$out/.pending"
    build "$mode" >/dev/null 2>&1
    [ -f "$out/.pending" ] || break
    mode=quick
  done
  exit 0
fi

build full
board="$out/index.html"
command -v cygpath >/dev/null 2>&1 && board=$(cygpath -w "$board")
echo "Board: $board"
[ $open -eq 1 ] && open_board
if [ "$watch" -gt 0 ]; then
  echo "Watching ai/ every ${watch}s — Ctrl-C to stop"
  trap 'exit 0' INT TERM
  while :; do
    sleep "$watch"
    build quick
  done
fi
exit 0
