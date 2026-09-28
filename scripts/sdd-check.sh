#!/usr/bin/env bash
# sdd-check.sh — deterministyczna walidacja artefaktów SDD w projekcie (tylko odczyt).
#
# To, co da się policzyć, liczy skrypt, nie model: format delty, checkboxy tasków, pokrycie
# AC przez taski, kolizje numerów REQ, utrata AC przy merge do main spec, dryf kodu od weryfikacji.
#
# Użycie (w katalogu głównym projektu):  bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh <tryb> [argumenty]
#   change <nazwa>        struktura zmiany: Status, delta, tasks, pokrycie AC przez taski
#   preflight <nazwa>     delta vs ai/specs/: kolizje numerów REQ, MODIFIED/REMOVED bez REQ, utrata AC
#   postmerge <nazwa>     po merge: main specs bez formatu delty, AC zgodne z deltą
#   drift <nazwa>         czy pliki zmiany zmieniły się od weryfikacji (Commit HEAD z verification.md)
#   diff <nazwa> [baza]   fakty dla review: wyłączone/usunięte testy, mniej asercji, pliki spoza Affected Files
#   next-req              następny wolny numer REQ (ai/specs/, aktywne zmiany i archiwum)
#   status                jedna linia na aktywną zmianę: Status, taski, weryfikacja
#   index                 spis wymagań: „domena: REQ-NNN tytuł (AC: n)" — mapa ai/specs/
#   stale                 pliki zarchiwizowanych zmian ruszone później poza cyklem SDD
#
# Wyjście: linie „ERROR|WARN|INFO <plik>[:<linia>] <opis>" + „RESULT: OK|WARN|ERROR (...)".
# Kod wyjścia: 0 = brak ERROR, 1 = są ERROR, 2 = błędne użycie.

set -u
LC_ALL=C
export LC_ALL

errors=0
warnings=0
err()  { echo "ERROR $*"; errors=$((errors + 1)); }
warn() { echo "WARN  $*"; warnings=$((warnings + 1)); }
info() { echo "INFO  $*"; }

# Wypisuje wynik reguł awk i dolicza ERROR/WARN do liczników.
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

usage() { sed -n '2,19p' "$0" | sed -E 's/^# ?//'; exit 2; }

# --- Parser specyfikacji --------------------------------------------------------------------
# Emituje rekordy TSV: rola, plik, linia, rodzaj, sekcja, REQ, wartość.
# Rodzaje: SEC, REQ, AC, SAME (AC oznaczone „(bez zmian)"), DROP (Usunięte AC), POWOD, BYLO, INV, PLACEHOLDER.
# Pomija bloki kodu i komentarze HTML — instrukcje z szablonów nie są treścią.
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
  if (line ~ /REQ-(XXX|YYY|ZZZ|NNN)|\{\{[A-Z_]+\}\}|\[kryterium|\[Nazwa|\[warunek|\[akcja|\[oczekiwany/)
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
    if (line ~ /\(bez zmian\)/) rec("SAME", a)
    next
  }
  if (req != "" && line ~ /^\*\*Usunięte AC:?\*\*/) {
    rest = line; sub(/^\*\*Usunięte AC:?\*\*/, "", rest)
    while (match(rest, /AC-[0-9]+/)) { rec("DROP", substr(rest, RSTART, RLENGTH)); rest = substr(rest, RSTART + RLENGTH) }
    indrop = 1   # kolejne punkty listy („- AC-3 — powód") też są usuwanymi AC
    next
  }
  if (req != "" && line ~ /^\*\*Powód:?\*\*/) { rec("POWOD", ""); next }
  if (line ~ /^\*\*Było:?\*\*/) { rec("BYLO", ""); next }
  if (line ~ /INV-[0-9]+/ && toupper(sec) ~ /^INVARIANTS/) { match(line, /INV-[0-9]+/); rec("INV", substr(line, RSTART, RLENGTH)) }
}
'

# Wspólne funkcje reguł (klucz sekcji, domena z nazwy pliku).
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

# Parser tasks.md — rekordy: T, plik, linia, stan (TODO/DONE/BADBOX/NOBOX), grupa, ID, treść.
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

# Wartość pola z tabeli metadanych („| Pole | wartość |") albo linii „Pole: wartość".
meta_field() {
  [ -f "$1" ] || return 0
  awk -v k="$2" '
    function out(v,   a) { sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); if (v ~ /\//) print v; else { split(v, a, /[ \t]+/); print a[1] } }
    # pogrubienie i backticki (| **Status** | `Approved` |) to formatowanie, nie wartość
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

# Ścieżki z sekcji „Affected Files" w design.md. Token w backtickach: ścieżka albo nazwa pliku;
# słowo bez backticków: tylko gdy wygląda na ścieżkę (ma „/" oraz rozszerzenie albo kończy się „/").
# Pomija komentarze HTML i bloki kodu; odrzuca endpointy („/api/..."), URL-e i „..".
# Sama nazwa pliku daje dwa wzorce: plik w korzeniu i „*/nazwa" (pathspec git dopasowuje od korzenia).
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

# Najstarszy (wg daty) commit zapisany w tasks.md jako „commit: <hash>".
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

need_change() {
  case "$1" in */*|*..*|"") echo "ERROR niepoprawna nazwa zmiany: '$1'"; exit 2 ;; esac
  [ -d "ai/changes/$1" ] || { err "ai/changes/$1: brak katalogu zmiany"; finish; }
}

# --- change ---------------------------------------------------------------------------------
cmd_change() {
  name=$1
  dir="ai/changes/$name"
  need_change "$name"
  for f in proposal.md design.md tasks.md; do
    [ -f "$dir/$f" ] || err "$dir/$f: brak pliku"
  done
  specs=$(change_specs "$name")
  [ -n "$specs" ] || err "$dir/specs/: brak delta spec"

  status=$(meta_field "$dir/proposal.md" Status)
  typ=$(meta_field "$dir/proposal.md" Typ)
  case "$status" in
    Draft|Approved|Rejected) info "$dir/proposal.md Status: $status" ;;
    "") [ -f "$dir/proposal.md" ] && err "$dir/proposal.md: brak pola Status" ;;
    *) err "$dir/proposal.md: Status '$status' — dozwolone: Draft / Approved / Rejected" ;;
  esac

  # shellcheck disable=SC2086
  delta=$(parse D $specs)
  emit "$(printf '%s\n' "$delta" | awk -v typ="$typ" "$RULES_LIB"'
    $1 == "D" {
      loc = $2 ":" $3; kind = $4; sk = key($5); r = $6; v = $7
      if (kind == "PLACEHOLDER") { printf "ERROR %s placeholder z szablonu: %s\n", loc, v; next }
      if (kind == "SEC") {
        if (sk == "") printf "WARN  %s nieznana sekcja delty %s (dozwolone: ADDED, MODIFIED, REMOVED, INVARIANTS, Notes)\n", loc, v
        next
      }
      if (kind == "REQ") {
        nreq++
        if (sk != "ADDED" && sk != "MODIFIED" && sk != "REMOVED") printf "ERROR %s %s poza sekcją ADDED/MODIFIED/REMOVED\n", loc, r
        if (r in rsec) { printf "ERROR %s %s występuje w delcie więcej niż raz (także %s)\n", loc, r, rloc[r]; next }
        rsec[r] = sk; rloc[r] = loc; ord[++n] = r; next
      }
      if (kind == "AC") {
        if ((r, v) in seen) printf "ERROR %s %s/%s zduplikowane\n", loc, r, v
        seen[r, v] = 1; nac[r]++; next
      }
      if (kind == "POWOD") { powod[r] = 1; next }
      if (kind == "INV") { ninv++; next }
    }
    END {
      for (i = 1; i <= n; i++) {
        r = ord[i]; s = rsec[r]
        if ((s == "ADDED" || s == "MODIFIED") && nac[r] == 0) printf "ERROR %s %s bez AC\n", rloc[r], r
        if (s == "REMOVED" && !(r in powod)) printf "ERROR %s %s w REMOVED bez **Powód:**\n", rloc[r], r
      }
      if (typ == "refactor" && ninv == 0) printf "ERROR delta: refactor bez INVARIANTS (INV-n)\n"
      if (nreq == 0 && ninv == 0) printf "WARN  delta: brak REQ i INV — delta jest pusta\n"
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
      if (st == "NOBOX") { printf "WARN  %s task bez checkboxa: %s\n", loc, txt; next }
      if (st == "BADBOX") printf "WARN  %s nietypowy checkbox (dozwolone [ ] i [x]): %s\n", loc, txt
      total++
      if (st == "DONE") done++
      if (id == "") printf "WARN  %s task bez ID T-NN: %s\n", loc, txt
      refs = 0; rest = txt
      while (match(rest, /REQ-[0-9]+(\/AC-[0-9]+(([ \t]*,[ \t]*(AC-)?[0-9]+)|(\.\.(AC-)?[0-9]+))*)?/)) {
        m = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); refs++
        split(m, part, "/"); r = part[1]
        if (!(r in known)) printf "WARN  %s %s odwołuje się do nieistniejącego %s\n", loc, id, r
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
        if (!(m in inv)) printf "WARN  %s %s odwołuje się do nieistniejącego %s\n", loc, id, m
      }
      if (refs == 0 && grp !~ /^SETUP/ && txt !~ /bez REQ/) printf "WARN  %s %s bez odwołania do REQ/AC, INV (albo jawnie: bez REQ: powód)\n", loc, id
      if (tolower(txt) !~ /weryfikacja:/) printf "WARN  %s %s bez weryfikacja:\n", loc, id
      if (st == "DONE" && txt !~ /commit: [0-9a-f]/) printf "WARN  %s %s odhaczony bez śladu (commit: <hash>) — /regent:apply 4c\n", loc, id
      if (st == "DONE" && txt ~ /(REQ|INV)-[0-9]+/ && txt !~ /testy:/) printf "WARN  %s %s odhaczony bez mapowania testy: — reviewer nie znajdzie testu AC\n", loc, id
    }
    END {
      for (i = 1; i <= na; i++) {
        split(acs[i], p, "/")
        if (!(acs[i] in cov) && !(p[1] in whole) && !(acs[i] in same)) printf "WARN  tasks.md: %s nie ma taska\n", acs[i]
      }
      printf "INFO  tasks.md: %d/%d zrobione\n", done, total
    }')"
  finish
}

# --- preflight --------------------------------------------------------------------------------
cmd_preflight() {
  name=$1
  need_change "$name"
  specs=$(change_specs "$name")
  [ -n "$specs" ] || { err "ai/changes/$name/specs/: brak delta spec"; finish; }
  for f in $specs; do
    if ! grep -qE '^### REQ-[0-9]+' "$f"; then
      info "$f: delta bez REQ (tylko INVARIANTS) — merge nie zmienia ai/specs/"
    elif [ ! -f "ai/specs/$(basename "$f")" ]; then
      info "$f: nowy main spec ai/specs/$(basename "$f")"
    fi
  done
  # shellcheck disable=SC2046,SC2086
  recs=$(parse D $specs; parse M $(main_specs); parse O $(other_deltas "$name"))
  emit "$(printf '%s\n' "$recs" | awk "$RULES_LIB"'
    $1 == "M" && $4 == "REQ" { d = dom($2); mreq[d, $6] = 1; mdom[$6] = d; mtitle[d, $6] = $7; next }
    $1 == "M" && $4 == "AC"  { d = dom($2); macl[d, $6] = macl[d, $6] " " $7; next }
    $1 == "O" && $4 == "REQ" { osec[$6] = key($5); ofile[$6] = $2; next }
    $1 == "D" && $4 == "REQ" { r = $6; dsec[r] = key($5); ddom[r] = dom($2); dloc[r] = $2 ":" $3; dtitle[r] = $7; ord[++n] = r; next }
    $1 == "D" && $4 == "AC"   { dac[$6, $7] = 1; next }
    $1 == "D" && $4 == "DROP" { ddrop[$6, $7] = 1; next }
    END {
      for (i = 1; i <= n; i++) {
        r = ord[i]; s = dsec[r]; d = ddom[r]; loc = dloc[r]
        if (s == "ADDED") {
          if (r in mdom) printf "ERROR %s %s (ADDED) już istnieje w ai/specs/%s.md — kolizja numeru, weź next-req\n", loc, r, mdom[r]
          else if ((r in osec) && osec[r] == "ADDED") printf "ERROR %s %s (ADDED) dodaje też aktywna zmiana %s — kolizja numeru\n", loc, r, ofile[r]
          continue
        }
        if (s != "MODIFIED" && s != "REMOVED") continue
        if (!((d, r) in mreq)) {
          if (r in mdom) printf "ERROR %s %s jest w ai/specs/%s.md, a delta dotyczy domeny %s\n", loc, r, mdom[r], d
          else printf "ERROR %s %s (%s) nie istnieje w ai/specs/%s.md — zachowanie bez specyfikacji opisz jako ADDED\n", loc, r, s, d
          continue
        }
        if (s == "MODIFIED") {
          c = split(macl[d, r], al, " ")
          for (j = 1; j <= c; j++) {
            a = al[j]
            if (a != "" && !((r, a) in dac) && !((r, a) in ddrop))
              printf "ERROR %s %s/%s jest w main spec, a nie ma go w bloku MODIFIED ani w Usunięte AC — zniknąłby przy merge\n", loc, r, a
          }
          if (dtitle[r] != mtitle[d, r]) printf "INFO  %s %s zmienia nazwę: %s -> %s\n", loc, r, mtitle[d, r], dtitle[r]
        }
        if ((r in osec) && (osec[r] == "MODIFIED" || osec[r] == "REMOVED"))
          printf "WARN  %s %s zmienia też aktywna zmiana %s — druga archiwizacja wymaga odświeżenia bloku\n", loc, r, ofile[r]
      }
    }')"
  finish
}

# --- postmerge --------------------------------------------------------------------------------
cmd_postmerge() {
  name=$1
  need_change "$name"
  specs=$(change_specs "$name")
  [ -n "$specs" ] || { err "ai/changes/$name/specs/: brak delta spec"; finish; }
  # shellcheck disable=SC2046,SC2086
  recs=$(parse D $specs; parse M $(main_specs))
  emit "$(printf '%s\n' "$recs" | awk "$RULES_LIB"'
    $1 == "M" {
      loc = $2 ":" $3; d = dom($2)
      if ($4 == "SEC" && key($5) ~ /^(ADDED|MODIFIED|REMOVED|INVARIANTS)$/) printf "ERROR %s nagłówek delty ## %s w main spec\n", loc, $7
      else if ($4 == "BYLO") printf "ERROR %s linia Było: w main spec — to format delty\n", loc
      else if ($4 == "DROP") printf "ERROR %s linia Usunięte AC w main spec — to format delty\n", loc
      else if ($4 == "SAME") printf "ERROR %s znacznik (bez zmian) w main spec — to format delty\n", loc
      else if ($4 == "PLACEHOLDER") printf "ERROR %s placeholder z szablonu: %s\n", loc, $7
      else if ($4 == "REQ") {
        if ($6 in gdom) printf "ERROR %s %s występuje też w ai/specs/%s.md\n", loc, $6, gdom[$6]
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
        if (s == "REMOVED") { if ((d, r) in mreq) printf "ERROR %s %s (REMOVED) nadal jest w main spec\n", f, r; continue }
        if (s != "ADDED" && s != "MODIFIED") continue
        if (!((d, r) in mreq)) { printf "ERROR %s %s (%s) nie trafił do main spec\n", f, r, s; continue }
        c = split(dacl[r], al, " ")
        for (j = 1; j <= c; j++) if (al[j] != "" && !((d, r, al[j]) in mac)) printf "ERROR %s %s/%s z delty brak w main spec\n", f, r, al[j]
        c = split(macl[d, r], al, " ")
        for (j = 1; j <= c; j++) if (al[j] != "" && !((r, al[j]) in dac)) printf "ERROR %s %s/%s w main spec, a nie ma go w bloku z delty\n", f, r, al[j]
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
  [ -f "$vf" ] || { err "$vf: brak pliku"; finish; }
  h=$(meta_field "$vf" "Commit HEAD")
  [ -n "$h" ] || { err "$vf: brak pola Commit HEAD"; finish; }
  git rev-parse -q --verify "$h^{commit}" >/dev/null 2>&1 \
    || { warn "$vf: commit $h niedostępny lokalnie — nie da się porównać"; finish; }
  paths=$(affected_paths "$dir/design.md")
  set -f
  if [ -n "$paths" ]; then
    # shellcheck disable=SC2086
    changed=$(git diff --name-only "$h" -- $paths 2>/dev/null)
    rc=$?
  else
    info "$dir/design.md: brak ścieżek w Affected Files — porównuję całe repo poza ai/"
    changed=$(git diff --name-only "$h" -- . ':(exclude)ai' 2>/dev/null)
    rc=$?
  fi
  set +f
  [ $rc -eq 0 ] || { warn "git diff od $h nie powiódł się — nie da się porównać"; finish; }
  if [ -n "$changed" ]; then
    for f in $changed; do warn "$f zmieniony od weryfikacji ($h)"; done
  else
    info "pliki zmiany bez zmian od weryfikacji ($h)"
  fi
  finish
}

# --- diff -------------------------------------------------------------------------------------
TEST_RE='(^|/)(tests?|__tests__|e2e|specs?)/|\.(test|spec)\.[A-Za-z0-9]+$|_test\.[A-Za-z0-9]+$|(^|/)test_[^/]+$'
ASSERT_RE='expect\(|assert|should[.(]|verify\('   # punkty wejścia asercji — matcher (.toBe) to ta sama asercja
SKIP_RE='(^|[^A-Za-z0-9_])(it|describe|test|context)\.(skip|only|todo)\(|(^|[^A-Za-z0-9_])[xf](it|describe|test)\(|@Disabled|@Ignore|pytest\.mark\.(skip|xfail)|t\.Skip\(|\.skip\('

# Czyta linie `git diff --name-status` ze stdin; wypisuje WARN dla usuniętych testów i testów
# z mniejszą liczbą asercji. Osobna funkcja: bash 3.2 nie parsuje `case` wewnątrz $( … ).
test_integrity() {
  base=$1
  while IFS="$(printf '\t')" read -r st p1 p2; do
    [ -n "$st" ] || continue
    p=$p1
    case "$st" in (R*|C*) p=$p2 ;; esac
    printf '%s\n' "$p" | grep -qE "$TEST_RE" || continue
    case "$st" in
      (D) echo "WARN  $p usunięty plik testu" ;;
      (M)
        # liczymy wystąpienia, nie linie — kilka asercji w jednej linii to kilka asercji
        old=$(git show "$base:$p" 2>/dev/null | grep -oE "$ASSERT_RE" | wc -l | tr -d ' ')
        new=$(grep -oE "$ASSERT_RE" "$p" 2>/dev/null | wc -l | tr -d ' ')
        [ "${new:-0}" -lt "${old:-0}" ] && echo "WARN  $p mniej asercji niż w bazie ($old -> $new)"
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
  # Baza: rodzic najstarszego commitu cyklu — dotykającego katalogu zmiany (ai/changes/ w repo)
  # albo zapisanego w tasks.md jako „commit: <hash>" (ai/changes/ lokalny); inaczej merge-base.
  if [ -z "$base" ]; then
    oldest=$(git log --format=%H -- "$dir" 2>/dev/null | tail -1)
    src="rodzic pierwszego commitu dotykającego $dir"
    if [ -z "$oldest" ]; then
      oldest=$(oldest_recorded "$dir/tasks.md")
      src="rodzic najstarszego commitu z tasks.md"
    fi
    if [ -n "$oldest" ] && git rev-parse -q --verify "$oldest^" >/dev/null 2>&1; then
      base="$oldest^"
      info "baza: $src"
    else
      db=$(default_branch)
      if [ -n "$db" ]; then
        base=$(git merge-base HEAD "$db" 2>/dev/null)
        [ -n "$base" ] && info "baza: merge-base HEAD z $db"
      fi
    fi
  fi
  [ -n "$base" ] || { err "brak bazy porównania — podaj ją jawnie: diff $name <commit>"; finish; }
  git rev-parse -q --verify "$base^{commit}" >/dev/null 2>&1 || { err "baza $base nie istnieje w repo"; finish; }
  info "baza porównania: $base"

  ns=$(git diff --name-status -M "$base" -- . ':(exclude)ai' 2>/dev/null)
  res=$(printf '%s\n' "$ns" | test_integrity "$base")
  emit "$res"

  # Wyrażenia regularne przekazujemy przez ENVIRON — awk -v interpretuje sekwencje ucieczki (\( \.).
  tests=$(printf '%s\n' "$ns" | RE="$TEST_RE" awk -F'\t' '$1 != "D" { p = ($1 ~ /^[RC]/) ? $3 : $2; if (p ~ ENVIRON["RE"]) print p }')
  nontest=$(printf '%s\n' "$ns" | RE="$TEST_RE" awk -F'\t' '$1 != "D" && $1 != "" { p = ($1 ~ /^[RC]/) ? $3 : $2; if (p !~ ENVIRON["RE"]) print p }')

  if [ -n "$tests" ]; then
    set -f
    # shellcheck disable=SC2086
    emit "$(git diff -U0 "$base" -- $tests 2>/dev/null | RE="$SKIP_RE" awk '
      /^\+\+\+ / { f = substr($0, 7); next }
      /^\+/ { l = substr($0, 2); if (l ~ ENVIRON["RE"]) { sub(/^[ \t]+/, "", l); printf "WARN  %s dodany marker pominięcia testu: %s\n", f, l } }')"
    set +f
  fi

  paths=$(affected_paths "$dir/design.md")
  if [ -z "$paths" ]; then
    info "$dir/design.md: brak ścieżek w Affected Files — pomijam porównanie zakresu"
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
        if (!ok) printf "INFO  %s poza Affected Files (możliwe unrequested)\n", $0
      }'
    set -f
    for tk in $paths; do
      case "$tk" in *'*'*) continue ;; esac
      [ -e "$tk" ] || info "$tk z Affected Files nie istnieje"
    done
    set +f
  fi
  finish
}

# --- next-req ---------------------------------------------------------------------------------
cmd_next_req() {
  # shellcheck disable=SC2046
  # archiwum też: numer usuniętego REQ nie wraca do obiegu
  files=$(ls ai/specs/*.md ai/changes/*/specs/*.md ai/changes/archive/*/specs/*.md 2>/dev/null)
  max=0
  if [ -n "$files" ]; then
    # shellcheck disable=SC2086
    for n in $(grep -hoE '^### REQ-[0-9]+' $files | sed 's/^### REQ-//'); do
      n=$((10#$n))
      [ "$n" -gt "$max" ] && max=$n
    done
  fi
  printf 'REQ-%03d\n' $((max + 1))
  exit 0
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
    ver="brak"
    if [ -f "${d}verification.md" ]; then
      ver="$(meta_field "${d}verification.md" Verdict)@$(meta_field "${d}verification.md" "Commit HEAD")"
    fi
    info "$n: Status=${st:-brak} tasks=$counts verification=$ver"
  done
  [ $found -eq 1 ] || info "brak aktywnych zmian"
  finish
}

# --- index ----------------------------------------------------------------------------------
cmd_index() {
  specs=$(main_specs)
  [ -n "$specs" ] || { info "brak plików w ai/specs/"; exit 0; }
  # shellcheck disable=SC2086
  parse M $specs | awk "$RULES_LIB"'
    $4 == "REQ" { k = dom($2) SUBSEP $6; if (!(k in title)) { ord[++n] = k; title[k] = $7; d[k] = dom($2); id[k] = $6 }; next }
    $4 == "AC"  { nac[dom($2) SUBSEP $6]++ }
    END { for (i = 1; i <= n; i++) { k = ord[i]; printf "%s: %s %s (AC: %d)\n", d[k], id[k], title[k], nac[k] } }'
  exit 0
}

# --- stale ----------------------------------------------------------------------------------
# Czyta kandydatów (hash, data, temat) ze stdin. Commit, którego pliki mają dokładnie stan
# któregoś zapisanego commitu cyklu, to squash/rebase tej pracy (nie zmiana spoza cyklu).
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
    [ $c -le 5 ] && echo "WARN  $ch: $(printf '%s' "$h" | cut -c1-8) $d $subj — pliki zmiany ruszone poza cyklem SDD"
  done
  [ $c -gt 5 ] && echo "WARN  $ch: … i $((c - 5)) kolejnych commitów poza cyklem"
  return 0
}

# Commit, który rusza pliki zarchiwizowanej zmiany i nie należy do cyklu SDD, zmienił kod poza
# cyklem — main spec mógł przestać opisywać prawdę (hotfix bez follow-upu, ręczna poprawka).
# Commit należy do cyklu, gdy: jest zapisany w którymś tasks.md jako „commit: <hash>"
# (/regent:apply 4c), jego temat zawiera klucz ticketu którejś zmiany (pole Ticket — przeżywa
# squash i rebase), dotyka ai/changes/ (projekt, który jednak wersjonuje ai/), albo jego pliki
# mają stan zapisanego commitu cyklu (squash bez klucza w temacie).
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
    [ $rc -eq 0 ] || { warn "$n: git log nie powiódł się — pominięto"; continue; }
    cands=$(printf '%s\n' "$log" | INREPO="$in_repo" RECORDED="$recorded" KEYS="$keys" awk -F'\t' '
      BEGIN {
        m = split(ENVIRON["INREPO"], r, "\n");   for (i = 1; i <= m; i++) full[r[i]] = 1
        m = split(ENVIRON["RECORDED"], r, "\n"); for (i = 1; i <= m; i++) short[r[i]] = 1
        nk = split(ENVIRON["KEYS"], key, "\n")
      }
      # klucz ticketu jako całe słowo: CAP-7 nie pasuje do CAP-70 ani XCAP-7
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
  [ $found -eq 1 ] || info "brak zarchiwizowanych zmian z Affected Files"
  finish
}

# --- dispatch ---------------------------------------------------------------------------------
[ $# -ge 1 ] || usage
mode=$1
shift
case "$mode" in
  -h|--help|help) usage ;;
  change|preflight|postmerge|drift|diff) [ $# -ge 1 ] || usage ;;
  next-req|status|index|stale) ;;
  *) usage ;;
esac
[ -d ai ] || { echo "ERROR brak katalogu ai/ — uruchom w katalogu głównym projektu SDD"; exit 2; }

case "$mode" in
  change)    cmd_change "$1" ;;
  preflight) cmd_preflight "$1" ;;
  postmerge) cmd_postmerge "$1" ;;
  drift)     cmd_drift "$1" ;;
  diff)      cmd_diff "$1" "${2:-}" ;;
  next-req)  cmd_next_req ;;
  status)    cmd_status ;;
  index)     cmd_index ;;
  stale)     cmd_stale ;;
esac
