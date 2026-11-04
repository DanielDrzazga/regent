#!/usr/bin/env bash
# sdd-check.sh — deterministic validation of SDD artifacts in a project (read-only, except renumber).
#
# What can be counted is counted by the script, not the model: delta format, task checkboxes, AC
# coverage by tasks, REQ number collisions, AC loss on merge into the main spec, code drift since verification.
#
# Usage (in the project root):  bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh <mode> [arguments]
#   change <name>         change structure: Status, delta, tasks, AC coverage by tasks
#   preflight <name>      delta vs ai/specs/ (also of the default branch): REQ number collisions, MODIFIED/REMOVED of a missing REQ, AC loss
#   postmerge <name>      after merge: main specs without delta format, AC consistent with the delta
#   drift <name>          whether the change's files changed since verification (Commit HEAD from verification.md)
#   diff <name> [base]    facts for review: disabled/removed tests, fewer assertions, files outside Affected Files
#   next-req              next free REQ number (ai/specs/, active changes, archive, other branches)
#   renumber <name> <REQ> [new-REQ]  renumber an ADDED REQ in the change's files (default: to next-req)
#   status                one line per active change: Status, tasks, verification
#   index                 requirements index: "domain: REQ-NNN title (AC: n)" — map of ai/specs/
#   stale                 files of archived changes touched later outside the SDD cycle
#
# Output: lines "ERROR|WARN|INFO <file>[:<line>] <text>" + "RESULT: OK|WARN|ERROR (...)".
# Exit code: 0 = no ERROR, 1 = ERROR present, 2 = wrong usage.

set -u
LC_ALL=C
export LC_ALL

errors=0
warnings=0
err()  { echo "ERROR $*"; errors=$((errors + 1)); }
warn() { echo "WARN  $*"; warnings=$((warnings + 1)); }
info() { echo "INFO  $*"; }

# Prints the awk rules' output and adds ERROR/WARN to the counters.
emit() {
  [ -n "$1" ] || return 0
  printf '%s\n' "$1"
  e=$(printf '%s\n' "$1" | grep -c '^ERROR')
  w=$(printf '%s\n' "$1" | grep -c '^WARN')
  errors=$((errors + e))
  warnings=$((warnings + w))
}

finish() {
  r=OK
  [ $warnings -gt 0 ] && r=WARN
  [ $errors -gt 0 ] && r=ERROR
  echo "RESULT: $r (errors=$errors warnings=$warnings)"
  [ $errors -eq 0 ] && exit 0
  exit 1
}

usage() { sed -n '2,20p' "$0" | sed -E 's/^# ?//'; exit 2; }

# --- Spec parser -----------------------------------------------------------------------------
# Emits TSV records: role, file, line, kind, section, REQ, value.
# Kinds: SEC, REQ, AC, SAME (AC marked "(unchanged)"), DROP (Removed AC), REASON, WAS, INV, PLACEHOLDER.
# Skips code blocks and HTML comments — template instructions are not content.
# Markers: English (**Removed AC:**, **Was:**, **Reason:**, "(unchanged)") and, for artifacts written
# before the translation, the legacy Polish ones (the second alternative in each regex below).
PARSE_AWK='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function rec(kind, val) { gsub(/\t/, " ", val); printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", role, FILENAME, FNR, kind, sec, req, val }
FNR == 1 { fence = 0; incom = 0; sec = ""; req = ""; indrop = 0 }
{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
  if (fence) next
  if (incom) {
    e = index(line, "-->")
    if (!e) next
    line = substr(line, e + 3); incom = 0
  }
  while ((s = index(line, "<!--")) > 0) {
    rest = substr(line, s + 4); e = index(rest, "-->")
    if (e) line = substr(line, 1, s - 1) substr(rest, e + 3)
    else { line = substr(line, 1, s - 1); incom = 1; break }
  }
  if (line ~ /REQ-(XXX|YYY|ZZZ|NNN)|\{\{[A-Z_]+\}\}|\[(Name|Requirement name|precondition|user or system action|expected result|testable criterion|criterion|changed criterion|new criterion)[] ]|\[kryterium|\[Nazwa|\[warunek|\[akcja|\[oczekiwany/)
    rec("PLACEHOLDER", trim(line))
  if (line ~ /^## /) { sec = trim(substr(line, 4)); req = ""; rec("SEC", sec); next }
  if (line ~ /^### REQ-[0-9]+/) {
    match(line, /REQ-[0-9]+/); req = substr(line, RSTART, RLENGTH)
    t = substr(line, RSTART + RLENGTH); sub(/^:?[ \t]*/, "", t)
    rec("REQ", trim(t)); next
  }
  if (line ~ /^(#|##|###) /) { req = ""; indrop = 0; next }
  if (line ~ /^#+ /) next
  if (indrop && line ~ /^[ \t]*[-*] .*AC-[0-9]+/ && line !~ /^[ \t]*[-*] \[[ xX]\]/) {
    rest = line
    while (match(rest, /AC-[0-9]+/)) { rec("DROP", substr(rest, RSTART, RLENGTH)); rest = substr(rest, RSTART + RLENGTH) }
    next
  }
  if (line !~ /^[ \t]*[-*] / && line !~ /^[ \t]*$/) indrop = 0
  if (line ~ /^[ \t]*[-*] \[[ xX]\]/) indrop = 0
  if (req != "" && line ~ /^[ \t]*[-*] (\[[ xX]\] )?(\*\*)?AC-[0-9]+/) {
    match(line, /AC-[0-9]+/); a = substr(line, RSTART, RLENGTH); rec("AC", a)
    if (line ~ /\((unchanged|bez zmian)\)/) rec("SAME", a)
    next
  }
  if (req != "" && line ~ /^\*\*(Removed AC|Usunięte AC):?\*\*/) {
    rest = line; sub(/^\*\*(Removed AC|Usunięte AC):?\*\*/, "", rest)
    while (match(rest, /AC-[0-9]+/)) { rec("DROP", substr(rest, RSTART, RLENGTH)); rest = substr(rest, RSTART + RLENGTH) }
    indrop = 1   # following list items ("- AC-3 — reason") are removed AC too
    next
  }
  if (req != "" && line ~ /^\*\*(Reason|Powód):?\*\*/) { rec("REASON", ""); next }
  if (line ~ /^\*\*(Was|Było):?\*\*/) { rec("WAS", ""); next }
  if (line ~ /INV-[0-9]+/ && toupper(sec) ~ /^INVARIANTS/) { match(line, /INV-[0-9]+/); rec("INV", substr(line, RSTART, RLENGTH)) }
}
'

# Shared rule functions (section key, domain from the file name).
RULES_LIB='
BEGIN { FS = "\t" }
function key(s) {
  s = toupper(s)
  if (s ~ /^ADDED/) return "ADDED"
  if (s ~ /^MODIFIED/) return "MODIFIED"
  if (s ~ /^REMOVED/) return "REMOVED"
  if (s ~ /^INVARIANTS/) return "INVARIANTS"
  if (s ~ /^NOTES/) return "NOTES"
  return ""
}
function dom(f,   n, p, d) { n = split(f, p, "/"); d = p[n]; sub(/\.md$/, "", d); return d }
'

# tasks.md parser — records: T, file, line, state (TODO/DONE/BADBOX/NOBOX), group, ID, text.
TASK_AWK='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function rec(st, id, txt) { gsub(/\t/, " ", txt); printf "T\t%s\t%s\t%s\t%s\t%s\t%s\n", FILENAME, FNR, st, grp, id, txt }
FNR == 1 { fence = 0; grp = "" }
{
  line = $0
  sub(/\r$/, "", line)
  if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
  if (fence) next
  if (line ~ /^## /) { grp = trim(substr(line, 4)); next }
  id = ""
  if (match(line, /T-[0-9]+/)) id = substr(line, RSTART, RLENGTH)
  if (line ~ /^[ \t]*- \[\]/) { rec("BADBOX", id, trim(line)); next }
  if (line ~ /^[ \t]*- \[.\]/) {
    box = substr(line, index(line, "[") + 1, 1)
    st = (box == " ") ? "TODO" : ((box == "x" || box == "X") ? "DONE" : "BADBOX")
    rec(st, id, trim(line)); next
  }
  if (line ~ /^[ \t]*[-*] T-[0-9]+/) rec("NOBOX", id, trim(line))
}
'

parse() { role=$1; shift; [ $# -gt 0 ] || return 0; awk -v role="$role" "$PARSE_AWK" "$@"; }

# Field value from the metadata table ("| Field | value |") or a "Field: value" line.
meta_field() {
  [ -f "$1" ] || return 0
  awk -v k="$2" '
    function out(v,   a) { sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); if (v ~ /\//) print v; else { split(v, a, /[ \t]+/); print a[1] } }
    # bold and backticks (| **Status** | `Approved` |) are formatting, not the value
    { line = $0; sub(/\r$/, "", line); gsub(/[*`]/, "", line) }
    line ~ ("^\\|[ \t]*" k "[ \t]*\\|") { v = line; sub("^\\|[ \t]*" k "[ \t]*\\|", "", v); sub(/\|.*$/, "", v); out(v); exit }
    line ~ ("^" k ":[ \t]") { v = line; sub("^" k ":", "", v); out(v); exit }
  ' "$1"
}

main_specs()   { ls ai/specs/*.md 2>/dev/null; }
change_specs() { ls ai/changes/"$1"/specs/*.md 2>/dev/null; }
other_deltas() {
  for d in ai/changes/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    [ "$n" = archive ] || [ "$n" = "$1" ] || ls ${d}specs/*.md 2>/dev/null
  done
}

# Paths from the "Affected Files" section of design.md. A backticked token: a path or a file name;
# a word without backticks: only when it looks like a path (has "/" and an extension, or ends with "/").
# Skips HTML comments and code blocks; rejects endpoints ("/api/..."), URLs and "..".
# A bare file name gives two patterns: the file in the root and "*/name" (git pathspec matches from the root).
affected_paths() {
  [ -f "$1" ] || return 0
  awk '
    function add(t) { if (!(t in seen)) { seen[t] = 1; print t } }
    function emit(t, quoted) {
      sub(/[.:,;]+$/, "", t)
      if (t == "" || t ~ /^\[/ || t ~ /[ <>{}"]/ || t ~ /^\// || t ~ /:\/\// || t ~ /\.\./) return
      if (!quoted && !(t ~ /\// && (t ~ /\.[A-Za-z0-9]+$/ || t ~ /\/$/))) return
      if (t !~ /\// && t !~ /\.[A-Za-z0-9]+$/) return
      if (t !~ /\//) { add(t); add("*/" t); return }
      add(t)
    }
    FNR == 1 { fence = 0; incom = 0; ins = 0 }
    {
      line = $0; sub(/\r$/, "", line)
      if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; next }
      if (fence) next
      if (incom) { e = index(line, "-->"); if (!e) next; line = substr(line, e + 3); incom = 0 }
      while ((s = index(line, "<!--")) > 0) {
        rest = substr(line, s + 4); e = index(rest, "-->")
        if (e) line = substr(line, 1, s - 1) substr(rest, e + 3)
        else { line = substr(line, 1, s - 1); incom = 1; break }
      }
      if (line ~ /^#+ /) { ins = (line ~ /Affected Files/); next }
      if (!ins) next
      scan = line
      while (match(scan, /`[^`]+`/)) { emit(substr(scan, RSTART + 1, RLENGTH - 2), 1); scan = substr(scan, RSTART + RLENGTH) }
      gsub(/`[^`]*`/, " ", line)
      n = split(line, w, /[ \t|,;()]+/)
      for (i = 1; i <= n; i++) emit(w[i], 0)
    }
  ' "$1"
}

# The oldest (by date) commit recorded in tasks.md as "commit: <hash>".
oldest_recorded() {
  [ -f "$1" ] || return 0
  best=""
  bt=""
  for h in $(grep -oE 'commit: [0-9a-f]{7,40}' "$1" | sed 's/commit: //'); do
    t=$(git log -1 --format=%ct "$h" 2>/dev/null) || continue
    [ -n "$t" ] || continue
    if [ -z "$bt" ] || [ "$t" -lt "$bt" ]; then bt=$t; best=$(git rev-parse "$h" 2>/dev/null); fi
  done
  echo "$best"
}

default_branch() {
  b=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  [ -n "$b" ] && { echo "$b"; return 0; }
  for c in main master; do
    git rev-parse -q --verify "$c^{commit}" >/dev/null 2>&1 && { echo "$c"; return 0; }
  done
  return 0
}

# Local and remote branches (without symbolic */HEAD). `ai/` is tracked, so deltas and main specs
# of other branches are visible without a checkout (empty when `ai/` is not in git).
branch_refs() { git for-each-ref --format='%(refname)' refs/heads refs/remotes 2>/dev/null | grep -v '/HEAD$'; }

# REQ numbers from all branches: "ref:path:line" with section and REQ headings, in file order.
ref_req_lines() {
  refs=$(branch_refs)
  [ -n "$refs" ] || return 0
  # shellcheck disable=SC2086
  git grep -E '^(## |### REQ-[0-9]+)' $refs -- 'ai/specs/*.md' 'ai/changes/*/specs/*.md' 2>/dev/null
  return 0
}

# All taken numbers (without leading zeros): working tree + branches.
# The archive too: a removed REQ's number does not come back into use.
used_req_numbers() {
  files=$(ls ai/specs/*.md ai/changes/*/specs/*.md ai/changes/archive/*/specs/*.md 2>/dev/null)
  {
    # shellcheck disable=SC2086
    [ -n "$files" ] && grep -hoE '^### REQ-[0-9]+' $files
    ref_req_lines | grep -oE ':### REQ-[0-9]+'
  } | sed 's/.*REQ-//; s/^0*//; s/^$/0/' | sort -nu
}

next_req_value() {
  max=$(used_req_numbers | tail -n 1)
  printf 'REQ-%03d\n' $((${max:-0} + 1))
}

# Records "R ref change REQ": ADDED in deltas of active changes on other branches (excluding change $1).
ref_added() {
  ref_req_lines | awk -v me="$1" '
    {
      i = index($0, ":"); ref = substr($0, 1, i - 1); rest = substr($0, i + 1)
      j = index(rest, ":"); path = substr(rest, 1, j - 1); txt = substr(rest, j + 1)
      sub(/\r$/, "", txt)
      if (ref ":" path != last) { last = ref ":" path; sec = "" }
    }
    txt ~ /^## / { sec = toupper(substr(txt, 4)); next }
    path ~ /^ai\/changes\// && path !~ /^ai\/changes\/archive\// && sec ~ /^ADDED/ && txt ~ /^### REQ-[0-9]+/ {
      split(path, p, "/"); if (p[3] == me) next
      sub(/^refs\/(heads|remotes)\//, "", ref)
      match(txt, /REQ-[0-9]+/); printf "R\t%s\t%s\t%s\n", ref, p[3], substr(txt, RSTART, RLENGTH)
    }'
}

# Records "A change": changes already archived (locally or on the default branch $1) — their
# deltas on old branches are not a collision.
archived_changes() {
  {
    ls -d ai/changes/archive/*/ 2>/dev/null
    [ -n "$1" ] && git ls-tree --name-only "$1" -- ai/changes/archive/ 2>/dev/null
  } | awk '{ n = $0; sub(/\/$/, "", n); sub(/.*\//, "", n); sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-/, "", n); printf "A\t%s\n", n }'
}

need_change() {
  case "$1" in */*|*..*|"") echo "ERROR invalid change name: '$1'"; exit 2 ;; esac
  [ -d "ai/changes/$1" ] || { err "ai/changes/$1: no change directory"; finish; }
}

# --- change ---------------------------------------------------------------------------------
cmd_change() {
  name=$1
  dir="ai/changes/$name"
  need_change "$name"
  for f in proposal.md design.md tasks.md; do
    [ -f "$dir/$f" ] || err "$dir/$f: missing file"
  done
  specs=$(change_specs "$name")
  [ -n "$specs" ] || err "$dir/specs/: no delta spec"

  status=$(meta_field "$dir/proposal.md" Status)
  typ=$(meta_field "$dir/proposal.md" Type)
  [ -n "$typ" ] || typ=$(meta_field "$dir/proposal.md" Typ)   # legacy Polish field name
  case "$status" in
    Draft|Approved|Rejected) info "$dir/proposal.md Status: $status" ;;
    "") [ -f "$dir/proposal.md" ] && err "$dir/proposal.md: no Status field" ;;
    *) err "$dir/proposal.md: Status '$status' — allowed: Draft / Approved / Rejected" ;;
  esac

  # shellcheck disable=SC2086
  delta=$(parse D $specs)
  emit "$(printf '%s\n' "$delta" | awk -v typ="$typ" "$RULES_LIB"'
    $1 == "D" {
      loc = $2 ":" $3; kind = $4; sk = key($5); r = $6; v = $7
      if (kind == "PLACEHOLDER") { printf "ERROR %s template placeholder: %s\n", loc, v; next }
      if (kind == "SEC") {
        if (sk == "") printf "WARN  %s unknown delta section %s (allowed: ADDED, MODIFIED, REMOVED, INVARIANTS, Notes)\n", loc, v
        next
      }
      if (kind == "REQ") {
        nreq++
        if (sk != "ADDED" && sk != "MODIFIED" && sk != "REMOVED") printf "ERROR %s %s outside an ADDED/MODIFIED/REMOVED section\n", loc, r
        if (r in rsec) { printf "ERROR %s %s appears in the delta more than once (also %s)\n", loc, r, rloc[r]; next }
        rsec[r] = sk; rloc[r] = loc; ord[++n] = r; next
      }
      if (kind == "AC") {
        if ((r, v) in seen) printf "ERROR %s %s/%s duplicated\n", loc, r, v
        seen[r, v] = 1; nac[r]++; next
      }
      if (kind == "REASON") { reason[r] = 1; next }
      if (kind == "INV") { ninv++; next }
    }
    END {
      for (i = 1; i <= n; i++) {
        r = ord[i]; s = rsec[r]
        if ((s == "ADDED" || s == "MODIFIED") && nac[r] == 0) printf "ERROR %s %s without AC\n", rloc[r], r
        if (s == "REMOVED" && !(r in reason)) printf "ERROR %s %s in REMOVED without **Reason:**\n", rloc[r], r
      }
      if (typ == "refactor" && ninv == 0) printf "ERROR delta: refactor without INVARIANTS (INV-n)\n"
      if (nreq == 0 && ninv == 0) printf "WARN  delta: no REQ and no INV — the delta is empty\n"
    }')"

  [ -f "$dir/tasks.md" ] || finish
  # shellcheck disable=SC2046
  known=$(parse G $(main_specs))
  tasks=$(awk "$TASK_AWK" "$dir/tasks.md")
  emit "$(printf '%s\n%s\n%s\n' "$delta" "$known" "$tasks" | awk "$RULES_LIB"'
    $1 == "D" && $4 == "REQ" { k = key($5); known[$6] = 1; if (k == "ADDED" || k == "MODIFIED") live[$6] = 1; next }
    $1 == "D" && $4 == "AC"  { if ($6 in live) acs[++na] = $6 "/" $7; next }
    $1 == "D" && $4 == "SAME" { same[$6 "/" $7] = 1; next }
    $1 == "D" && $4 == "INV" { inv[$7] = 1; next }
    $1 == "G" && $4 == "REQ" { known[$6] = 1; next }
    $1 == "T" {
      loc = $2 ":" $3; st = $4; grp = toupper($5); id = $6; txt = $7
      if (st == "NOBOX") { printf "WARN  %s task without a checkbox: %s\n", loc, txt; next }
      if (st == "BADBOX") printf "WARN  %s unusual checkbox (allowed [ ] and [x]): %s\n", loc, txt
      total++
      if (st == "DONE") done++
      if (id == "") printf "WARN  %s task without a T-NN ID: %s\n", loc, txt
      refs = 0; rest = txt
      while (match(rest, /REQ-[0-9]+(\/AC-[0-9]+(([ \t]*,[ \t]*(AC-)?[0-9]+)|(\.\.(AC-)?[0-9]+))*)?/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); refs++
        split(m, part, "/"); r = part[1]
        if (!(r in known)) printf "WARN  %s %s refers to a nonexistent %s\n", loc, id, r
        if (index(m, "/") == 0) whole[r] = 1
        else {
          list = part[2]; gsub(/AC-/, "", list); gsub(/[ \t]/, "", list)
          c = split(list, num, ",")
          for (j = 1; j <= c; j++) {
            if (index(num[j], "..")) { split(num[j], rg, /\.\./); for (q = rg[1] + 0; q <= rg[2] + 0; q++) cov[r "/AC-" q] = 1 }
            else cov[r "/AC-" (num[j] + 0)] = 1
          }
        }
      }
      rest = txt
      while (match(rest, /INV-[0-9]+/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); refs++
        if (!(m in inv)) printf "WARN  %s %s refers to a nonexistent %s\n", loc, id, m
      }
      # legacy Polish markers accepted too: "bez REQ", "weryfikacja:", "testy:"
      if (refs == 0 && grp !~ /^SETUP/ && txt !~ /no REQ|bez REQ/) printf "WARN  %s %s without a REQ/AC, INV reference (or explicitly: no REQ: reason)\n", loc, id
      if (tolower(txt) !~ /(verification|weryfikacja):/) printf "WARN  %s %s without verification:\n", loc, id
      if (st == "DONE" && txt !~ /commit: [0-9a-f]/) printf "WARN  %s %s checked off without a trace (commit: <hash>) — /regent:apply 4c\n", loc, id
      if (st == "DONE" && txt ~ /(REQ|INV)-[0-9]+/ && txt !~ /(tests|testy):/) printf "WARN  %s %s checked off without a tests: mapping — the reviewer will not find the AC test\n", loc, id
    }
    END {
      for (i = 1; i <= na; i++) {
        split(acs[i], p, "/")
        if (!(acs[i] in cov) && !(p[1] in whole) && !(acs[i] in same)) printf "WARN  tasks.md: %s has no task\n", acs[i]
      }
      printf "INFO  tasks.md: %d/%d done\n", done, total
    }')"
  finish
}

# --- preflight --------------------------------------------------------------------------------
cmd_preflight() {
  name=$1
  need_change "$name"
  specs=$(change_specs "$name")
  [ -n "$specs" ] || { err "ai/changes/$name/specs/: no delta spec"; finish; }
  for f in $specs; do
    if ! grep -qE '^### REQ-[0-9]+' "$f"; then
      info "$f: delta without REQ (INVARIANTS only) — the merge does not change ai/specs/"
    elif [ ! -f "ai/specs/$(basename "$f")" ]; then
      info "$f: new main spec ai/specs/$(basename "$f")"
    fi
  done
  # Main specs of the default branch and deltas of other branches (without a checkout).
  base=$(default_branch)
  btmp=$(mktemp -d "${TMPDIR:-/tmp}/sdd-base.XXXXXX")
  if [ -n "$base" ]; then
    for f in $(git ls-tree --name-only "$base" -- ai/specs/ 2>/dev/null | grep '\.md$'); do
      git show "$base:$f" > "$btmp/$(basename "$f")" 2>/dev/null
    done
  fi
  # shellcheck disable=SC2046,SC2086
  recs=$(parse D $specs; parse M $(main_specs); parse O $(other_deltas "$name")
    parse B $(ls "$btmp"/*.md 2>/dev/null); ref_added "$name"; archived_changes "$base")
  rm -rf "$btmp"
  emit "$(printf '%s\n' "$recs" | awk -v base="$base" "$RULES_LIB"'
    $1 == "M" && $4 == "REQ" {
      d = dom($2)
      if ($6 in mdom) printf "ERROR %s:%s %s also appears in ai/specs/%s.md — duplicate number\n", $2, $3, $6, mdom[$6]
      mreq[d, $6] = 1; mdom[$6] = d; mtitle[d, $6] = $7; next
    }
    $1 == "B" && $4 == "REQ" { bdom[$6] = dom($2); next }
    $1 == "R" { if (!($4 in rchg)) { rchg[$4] = $3; rref[$4] = $2 }; next }
    $1 == "A" { arch[$2] = 1; next }
    $1 == "M" && $4 == "AC"  { d = dom($2); macl[d, $6] = macl[d, $6] " " $7; next }
    $1 == "O" && $4 == "REQ" { osec[$6] = key($5); ofile[$6] = $2; next }
    $1 == "D" && $4 == "REQ" { r = $6; dsec[r] = key($5); ddom[r] = dom($2); dloc[r] = $2 ":" $3; dtitle[r] = $7; ord[++n] = r; next }
    $1 == "D" && $4 == "AC"   { dac[$6, $7] = 1; next }
    $1 == "D" && $4 == "DROP" { ddrop[$6, $7] = 1; next }
    END {
      for (i = 1; i <= n; i++) {
        r = ord[i]; s = dsec[r]; d = ddom[r]; loc = dloc[r]
        if (s == "ADDED") {
          if (r in mdom) printf "ERROR %s %s (ADDED) already exists in ai/specs/%s.md — number collision, take next-req\n", loc, r, mdom[r]
          else if ((r in osec) && osec[r] == "ADDED") printf "ERROR %s %s (ADDED) is also added by active change %s — number collision\n", loc, r, ofile[r]
          else if (r in bdom) printf "ERROR %s %s (ADDED) is already in %s:ai/specs/%s.md — collision with the default branch, sdd-check renumber\n", loc, r, base, bdom[r]
          else if ((r in rchg) && !(rchg[r] in arch)) printf "WARN  %s %s (ADDED) is also added by change %s on branch %s — whoever archives second runs sdd-check renumber\n", loc, r, rchg[r], rref[r]
          continue
        }
        if (s != "MODIFIED" && s != "REMOVED") continue
        if (!((d, r) in mreq)) {
          if (r in mdom) printf "ERROR %s %s is in ai/specs/%s.md, but the delta is for domain %s\n", loc, r, mdom[r], d
          else printf "ERROR %s %s (%s) does not exist in ai/specs/%s.md — describe unspecified behavior as ADDED\n", loc, r, s, d
          continue
        }
        if (s == "MODIFIED") {
          c = split(macl[d, r], al, " ")
          for (j = 1; j <= c; j++) {
            a = al[j]
            if (a != "" && !((r, a) in dac) && !((r, a) in ddrop))
              printf "ERROR %s %s/%s is in the main spec but neither in the MODIFIED block nor in Removed AC — it would vanish on merge\n", loc, r, a
          }
          if (dtitle[r] != mtitle[d, r]) printf "INFO  %s %s is renamed: %s -> %s\n", loc, r, mtitle[d, r], dtitle[r]
        }
        if ((r in osec) && (osec[r] == "MODIFIED" || osec[r] == "REMOVED"))
          printf "WARN  %s %s is also changed by active change %s — the second archive needs a refreshed block\n", loc, r, ofile[r]
      }
    }')"
  finish
}

# --- postmerge --------------------------------------------------------------------------------
cmd_postmerge() {
  name=$1
  need_change "$name"
  specs=$(change_specs "$name")
  [ -n "$specs" ] || { err "ai/changes/$name/specs/: no delta spec"; finish; }
  # shellcheck disable=SC2046,SC2086
  recs=$(parse D $specs; parse M $(main_specs))
  emit "$(printf '%s\n' "$recs" | awk "$RULES_LIB"'
    $1 == "M" {
      loc = $2 ":" $3; d = dom($2)
      if ($4 == "SEC" && key($5) ~ /^(ADDED|MODIFIED|REMOVED|INVARIANTS)$/) printf "ERROR %s delta heading ## %s in the main spec\n", loc, $7
      else if ($4 == "WAS") printf "ERROR %s Was: line in the main spec — that is delta format\n", loc
      else if ($4 == "DROP") printf "ERROR %s Removed AC line in the main spec — that is delta format\n", loc
      else if ($4 == "SAME") printf "ERROR %s (unchanged) marker in the main spec — that is delta format\n", loc
      else if ($4 == "PLACEHOLDER") printf "ERROR %s template placeholder: %s\n", loc, $7
      else if ($4 == "REQ") {
        if ($6 in gdom) printf "ERROR %s %s also appears in ai/specs/%s.md\n", loc, $6, gdom[$6]
        gdom[$6] = d; mreq[d, $6] = 1
      }
      else if ($4 == "AC") { mac[d, $6, $7] = 1; macl[d, $6] = macl[d, $6] " " $7 }
      next
    }
    $1 == "D" && $4 == "REQ" { r = $6; dsec[r] = key($5); ddom[r] = dom($2); ord[++n] = r; next }
    $1 == "D" && $4 == "AC"  { dac[$6, $7] = 1; dacl[$6] = dacl[$6] " " $7; next }
    END {
      for (i = 1; i <= n; i++) {
        r = ord[i]; s = dsec[r]; d = ddom[r]; f = "ai/specs/" d ".md"
        if (s == "REMOVED") { if ((d, r) in mreq) printf "ERROR %s %s (REMOVED) is still in the main spec\n", f, r; continue }
        if (s != "ADDED" && s != "MODIFIED") continue
        if (!((d, r) in mreq)) { printf "ERROR %s %s (%s) did not reach the main spec\n", f, r, s; continue }
        c = split(dacl[r], al, " ")
        for (j = 1; j <= c; j++) if (al[j] != "" && !((d, r, al[j]) in mac)) printf "ERROR %s %s/%s from the delta missing in the main spec\n", f, r, al[j]
        c = split(macl[d, r], al, " ")
        for (j = 1; j <= c; j++) if (al[j] != "" && !((r, al[j]) in dac)) printf "ERROR %s %s/%s in the main spec but not in the delta block\n", f, r, al[j]
      }
    }')"
  finish
}

# --- drift ------------------------------------------------------------------------------------
cmd_drift() {
  name=$1
  need_change "$name"
  dir="ai/changes/$name"
  vf="$dir/verification.md"
  [ -f "$vf" ] || { err "$vf: missing file"; finish; }
  h=$(meta_field "$vf" "Commit HEAD")
  [ -n "$h" ] || { err "$vf: no Commit HEAD field"; finish; }
  git rev-parse -q --verify "$h^{commit}" >/dev/null 2>&1 \
    || { warn "$vf: commit $h not available locally — cannot compare"; finish; }
  paths=$(affected_paths "$dir/design.md")
  set -f
  if [ -n "$paths" ]; then
    # shellcheck disable=SC2086
    changed=$(git diff --name-only "$h" -- $paths 2>/dev/null)
    rc=$?
  else
    info "$dir/design.md: no paths in Affected Files — comparing the whole repo except ai/"
    changed=$(git diff --name-only "$h" -- . ':(exclude)ai' 2>/dev/null)
    rc=$?
  fi
  set +f
  [ $rc -eq 0 ] || { warn "git diff from $h failed — cannot compare"; finish; }
  if [ -n "$changed" ]; then
    for f in $changed; do warn "$f changed since verification ($h)"; done
  else
    info "change files unchanged since verification ($h)"
  fi
  finish
}

# --- diff -------------------------------------------------------------------------------------
TEST_RE='(^|/)(tests?|__tests__|e2e|specs?)/|\.(test|spec)\.[A-Za-z0-9]+$|_test\.[A-Za-z0-9]+$|(^|/)test_[^/]+$'
ASSERT_RE='expect\(|assert|should[.(]|verify\('   # assertion entry points — a matcher (.toBe) is the same assertion
SKIP_RE='(^|[^A-Za-z0-9_])(it|describe|test|context)\.(skip|only|todo)\(|(^|[^A-Za-z0-9_])[xf](it|describe|test)\(|@Disabled|@Ignore|pytest\.mark\.(skip|xfail)|t\.Skip\(|\.skip\('

# Reads `git diff --name-status` lines from stdin; prints WARN for removed tests and tests
# with fewer assertions. A separate function: bash 3.2 does not parse `case` inside $( … ).
test_integrity() {
  base=$1
  while IFS="$(printf '\t')" read -r st p1 p2; do
    [ -n "$st" ] || continue
    p=$p1
    case "$st" in (R*|C*) p=$p2 ;; esac
    printf '%s\n' "$p" | grep -qE "$TEST_RE" || continue
    case "$st" in
      (D) echo "WARN  $p test file removed" ;;
      (M)
        # count occurrences, not lines — several assertions in one line are several assertions
        old=$(git show "$base:$p" 2>/dev/null | grep -oE "$ASSERT_RE" | wc -l | tr -d ' ')
        new=$(grep -oE "$ASSERT_RE" "$p" 2>/dev/null | wc -l | tr -d ' ')
        [ "${new:-0}" -lt "${old:-0}" ] && echo "WARN  $p fewer assertions than in the base ($old -> $new)"
        ;;
    esac
  done
  return 0
}

cmd_diff() {
  name=$1
  base=${2:-}
  need_change "$name"
  dir="ai/changes/$name"
  # Base: the parent of the cycle's oldest commit — one touching the change directory (ai/changes/ in
  # the repo) or recorded in tasks.md as "commit: <hash>" (local ai/changes/); otherwise merge-base.
  if [ -z "$base" ]; then
    oldest=$(git log --format=%H -- "$dir" 2>/dev/null | tail -1)
    src="parent of the first commit touching $dir"
    if [ -z "$oldest" ]; then
      oldest=$(oldest_recorded "$dir/tasks.md")
      src="parent of the oldest commit from tasks.md"
    fi
    if [ -n "$oldest" ] && git rev-parse -q --verify "$oldest^" >/dev/null 2>&1; then
      base="$oldest^"
      info "base: $src"
    else
      db=$(default_branch)
      if [ -n "$db" ]; then
        base=$(git merge-base HEAD "$db" 2>/dev/null)
        [ -n "$base" ] && info "base: merge-base of HEAD with $db"
      fi
    fi
  fi
  [ -n "$base" ] || { err "no comparison base — pass it explicitly: diff $name <commit>"; finish; }
  git rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1 || { err "base $base does not exist in the repo"; finish; }
  info "comparison base: $base"

  ns=$(git diff --name-status -M "$base" -- . ':(exclude)ai' 2>/dev/null)
  res=$(printf '%s\n' "$ns" | test_integrity "$base")
  emit "$res"

  # Regexes are passed via ENVIRON — awk -v interprets escape sequences (\( \.).
  tests=$(printf '%s\n' "$ns" | RE="$TEST_RE" awk -F'\t' '$1 != "D" { p = ($1 ~ /^[RC]/) ? $3 : $2; if (p ~ ENVIRON["RE"]) print p }')
  nontest=$(printf '%s\n' "$ns" | RE="$TEST_RE" awk -F'\t' '$1 != "D" && $1 != "" { p = ($1 ~ /^[RC]/) ? $3 : $2; if (p !~ ENVIRON["RE"]) print p }')

  if [ -n "$tests" ]; then
    set -f
    # shellcheck disable=SC2086
    emit "$(git diff -U0 "$base" -- $tests 2>/dev/null | RE="$SKIP_RE" awk '
      /^\+\+\+ / { f = substr($0, 7); next }
      /^\+/ { l = substr($0, 2); if (l ~ ENVIRON["RE"]) { sub(/^[ \t]+/, "", l); printf "WARN  %s test skip marker added: %s\n", f, l } }')"
    set +f
  fi

  paths=$(affected_paths "$dir/design.md")
  if [ -z "$paths" ]; then
    info "$dir/design.md: no paths in Affected Files — skipping the scope comparison"
  elif [ -n "$nontest" ]; then
    printf '%s\n' "$nontest" | TOKS="$paths" awk '
      BEGIN { n = split(ENVIRON["TOKS"], t, "\n") }
      {
        ok = 0
        for (i = 1; i <= n && !ok; i++) {
          tk = t[i]
          if (tk == "") continue
          if (tk ~ /\*/) { re = tk; gsub(/\./, "\\.", re); gsub(/\*/, ".*", re); if ($0 ~ ("^" re "$")) ok = 1; continue }
          if ($0 == tk) ok = 1
          else if (index($0, tk) == 1 && (substr(tk, length(tk)) == "/" || substr($0, length(tk) + 1, 1) == "/")) ok = 1
        }
        if (!ok) printf "INFO  %s outside Affected Files (possibly unrequested)\n", $0
      }'
    set -f
    for tk in $paths; do
      case "$tk" in *'*'*) continue ;; esac
      [ -e "$tk" ] || info "$tk from Affected Files does not exist"
    done
    set +f
  fi
  finish
}

# --- next-req ---------------------------------------------------------------------------------
cmd_next_req() {
  next_req_value
  exit 0
}

# --- renumber ---------------------------------------------------------------------------------
# The only mode that writes: the number from /regent:propose is provisional — on a collision (another
# branch took it first) the change gets a new one. Numbers do not reach the code, so the change's files suffice.
cmd_renumber() {
  name=$1
  old=$2
  new=${3:-}
  need_change "$name"
  printf '%s' "$old" | grep -qE '^REQ-[0-9]+$' || { echo "ERROR invalid number: '$old' (expected REQ-NNN)"; exit 2; }
  if [ -n "$new" ]; then
    printf '%s' "$new" | grep -qE '^REQ-[0-9]+$' || { echo "ERROR invalid number: '$new'"; exit 2; }
  fi
  specs=$(change_specs "$name")
  # shellcheck disable=SC2086
  sec=$(parse D $specs | awk -F'\t' -v r="$old" "$RULES_LIB"'$4 == "REQ" && $6 == r { print key($5); exit }')
  [ "$sec" = ADDED ] || { err "ai/changes/$name/specs/: $old is not in ADDED — only a new requirement can be renumbered"; finish; }
  if [ -z "$new" ]; then
    new=$(next_req_value)
  elif used_req_numbers | grep -qx "$(printf '%s' "$new" | sed 's/^REQ-0*//; s/^$/0/')"; then
    err "$new is taken — omit the argument and the script takes next-req"; finish
  fi
  find "ai/changes/$name" -type f -name '*.md' | sort | while IFS= read -r f; do
    n=$(grep -oE "$old([^0-9]|\$)" "$f" | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] || continue
    sed -E "s/$old([^0-9]|\$)/$new\\1/g" "$f" > "$f.renumber" && mv "$f.renumber" "$f"
    echo "INFO  $f: $old -> $new ($n)"
  done
  finish
}

# --- status -----------------------------------------------------------------------------------
cmd_status() {
  found=0
  for d in ai/changes/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    [ "$n" = archive ] && continue
    found=1
    st=$(meta_field "${d}proposal.md" Status)
    counts="-"
    if [ -f "${d}tasks.md" ]; then
      counts=$(awk "$TASK_AWK" "${d}tasks.md" | awk -F'\t' '$4 == "DONE" { d++ } $4 == "TODO" || $4 == "BADBOX" { t++ } END { printf "%d/%d", d, d + t }')
    fi
    ver="none"
    if [ -f "${d}verification.md" ]; then
      ver="$(meta_field "${d}verification.md" Verdict)@$(meta_field "${d}verification.md" "Commit HEAD")"
    fi
    info "$n: Status=${st:-none} tasks=$counts verification=$ver"
  done
  [ $found -eq 1 ] || info "no active changes"
  finish
}

# --- index ----------------------------------------------------------------------------------
cmd_index() {
  specs=$(main_specs)
  [ -n "$specs" ] || { info "no files in ai/specs/"; exit 0; }
  # shellcheck disable=SC2086
  parse M $specs | awk "$RULES_LIB"'
    $4 == "REQ" { k = dom($2) SUBSEP $6; if (!(k in title)) { ord[++n] = k; title[k] = $7; d[k] = dom($2); id[k] = $6 }; next }
    $4 == "AC"  { nac[dom($2) SUBSEP $6]++ }
    END { for (i = 1; i <= n; i++) { k = ord[i]; printf "%s: %s %s (AC: %d)\n", d[k], id[k], title[k], nac[k] } }'
  exit 0
}

# --- stale ----------------------------------------------------------------------------------
# Reads candidates (hash, date, subject) from stdin. A commit whose files have exactly the state of
# some recorded cycle commit is a squash/rebase of that work (not a change outside the cycle).
stale_report() {
  ch=$1
  rec=$2
  c=0
  while IFS="$(printf '\t')" read -r h d subj; do
    [ -n "$h" ] || continue
    files=$(git diff-tree --no-commit-id --name-only -r "$h" 2>/dev/null)
    same=0
    set -f
    for r in $rec; do
      # shellcheck disable=SC2086
      if [ -n "$files" ] && git diff --quiet "$r" "$h" -- $files 2>/dev/null; then same=1; break; fi
    done
    set +f
    [ $same -eq 1 ] && continue
    c=$((c + 1))
    [ $c -le 5 ] && echo "WARN  $ch: $(printf '%s' "$h" | cut -c1-8) $d $subj — change files touched outside the SDD cycle"
  done
  [ $c -gt 5 ] && echo "WARN  $ch: … and $((c - 5)) more commits outside the cycle"
  return 0
}

# A commit that touches an archived change's files and is not part of the SDD cycle changed code
# outside the cycle — the main spec may no longer describe the truth (hotfix without a follow-up, manual fix).
# A commit belongs to the cycle when: it is recorded in some tasks.md as "commit: <hash>"
# (/regent:apply 4c), its subject contains a change's ticket key (Ticket field — survives
# squash and rebase), it touches ai/changes/ (a project that does version ai/), or its files
# have the state of a recorded cycle commit (squash without the key in the subject).
cmd_stale() {
  keys=$(for f in ai/changes/*/proposal.md ai/changes/archive/*/proposal.md; do
    [ -f "$f" ] && meta_field "$f" Ticket
  done | grep -vE '^(NONE|none|-)?$|[][/ ]' | sort -u)
  in_repo=$(git log --no-merges --format=%H -- ai/changes 2>/dev/null)
  recorded=$(grep -rhoE 'commit: [0-9a-f]{7,40}' ai/changes 2>/dev/null | sed 's/commit: //' | cut -c1-7 | sort -u)
  rec_full=$(for h in $recorded; do git rev-parse -q --verify "$h^{commit}" 2>/dev/null; done)
  found=0
  for d in ai/changes/archive/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    day=$(printf '%s' "$n" | cut -c1-10)
    case "$day" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) continue ;; esac
    paths=$(affected_paths "${d}design.md")
    [ -n "$paths" ] || continue
    found=1
    set -f
    # shellcheck disable=SC2086
    log=$(git log --no-merges --since="$day 23:59:59" --format='%H%x09%ad%x09%s' --date=short -- $paths 2>/dev/null)
    rc=$?
    set +f
    [ $rc -eq 0 ] || { warn "$n: git log failed — skipped"; continue; }
    cands=$(printf '%s\n' "$log" | INREPO="$in_repo" RECORDED="$recorded" KEYS="$keys" awk -F'\t' '
      BEGIN {
        m = split(ENVIRON["INREPO"], r, "\n");   for (i = 1; i <= m; i++) full[r[i]] = 1
        m = split(ENVIRON["RECORDED"], r, "\n"); for (i = 1; i <= m; i++) short[r[i]] = 1
        nk = split(ENVIRON["KEYS"], key, "\n")
      }
      # ticket key as a whole word: CAP-7 does not match CAP-70 or XCAP-7
      function ticketed(subj,   i, k, s, p, abs, base, a, b) {
        for (i = 1; i <= nk; i++) {
          k = key[i]; if (k == "") continue
          s = subj; base = 0
          while ((p = index(s, k)) > 0) {
            abs = base + p
            a = (abs == 1) ? "" : substr(subj, abs - 1, 1); b = substr(subj, abs + length(k), 1)
            if (a !~ /[A-Za-z0-9]/ && b !~ /[A-Za-z0-9]/) return 1
            s = substr(s, p + 1); base = abs
          }
        }
        return 0
      }
      $1 != "" && !($1 in full) && !(substr($1, 1, 7) in short) && !ticketed($3) { print }')
    emit "$(printf '%s\n' "$cands" | stale_report "$(printf '%s' "$n" | cut -c12-)" "$rec_full")"
  done
  [ $found -eq 1 ] || info "no archived changes with Affected Files"
  finish
}

# --- dispatch ---------------------------------------------------------------------------------
[ $# -ge 1 ] || usage
mode=$1
shift
case "$mode" in
  -h|--help|help) usage ;;
  change|preflight|postmerge|drift|diff) [ $# -ge 1 ] || usage ;;
  renumber) [ $# -ge 2 ] || usage ;;
  next-req|status|index|stale) ;;
  *) usage ;;
esac
[ -d ai ] || { echo "ERROR no ai/ directory — run in the SDD project root"; exit 2; }

case "$mode" in
  change)    cmd_change "$1" ;;
  preflight) cmd_preflight "$1" ;;
  postmerge) cmd_postmerge "$1" ;;
  drift)     cmd_drift "$1" ;;
  diff)      cmd_diff "$1" "${2:-}" ;;
  next-req)  cmd_next_req ;;
  renumber)  cmd_renumber "$1" "$2" "${3:-}" ;;
  status)    cmd_status ;;
  index)     cmd_index ;;
  stale)     cmd_stale ;;
esac
