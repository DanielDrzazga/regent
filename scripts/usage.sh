#!/usr/bin/env bash
# usage.sh — Claude Code usage of SDD changes, measured from the session transcripts (read-only for the project).
#
# Reads <transcripts>/<session>.jsonl and <session>/subagents/*.jsonl (+ *.meta.json for the agent type).
# A /regent:<command> starts a run; the run belongs to the change its arguments name — or, when they name
# none (/regent:bugfix <description>), to the change directory its Write/Edit/Bash calls touched most — and
# the session's prompts after it belong to the same run until the next /regent: command. Calls are deduplicated by
# message.id; a subagent counts towards the prompt that launched it. Per run: Regent version (from the
# skill's plugin path), active time (prompt → its last call), prompts, and per model × effort × agent the
# calls and tokens (input, cache write 5m/1h, cache read, output). Cost = tokens × scripts/pricing.tsv —
# an API-equivalent estimate; Claude Code does not record the billed amount.
#
# Usage (in the project root):
#   usage.sh <change>         markdown for ai/changes/<change>/usage.md
#   usage.sh --tsv            records for scripts/dashboard.sh:
#                             R run change command regent session start end active prompts   (epoch seconds)
#                             M run model effort agent calls input cw5m cw1h cache_read output cost_usd
# Options: --cache DIR (parsed sessions; default: the board's usage-cache, ~/.cache/regent/boards/<project>-<sum>/)
# — a session is parsed again only when its transcript changed; a parsed session stays after Claude Code deletes it.
# Environment: REGENT_TRANSCRIPTS — the transcript directory (default: Claude Code's directory of this project).
# Exit code: 0 = OK, 2 = wrong usage, 3 = no run of <change> in the transcripts.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
PRICES="$HERE/pricing.tsv"

usage() { sed -n '2,22p' "$0" | sed -E 's/^# ?//'; exit 2; }

change=""
mode=md
cache=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tsv) mode=tsv; shift ;;
    --cache) [ $# -ge 2 ] || usage; cache=$2; shift 2 ;;
    -*) usage ;;
    *) [ -z "$change" ] || usage; change=$1; shift ;;
  esac
done
[ "$mode" = tsv ] || [ -n "$change" ] || usage
[ -d ai ] || { echo "ERROR no ai/ directory — run in the SDD project root"; exit 2; }

project=$(basename "$(pwd)")
if [ -z "$cache" ]; then
  # the board's cache (scripts/dashboard.sh): the hooks keep it current, and it outlives deleted transcripts
  sum=$(pwd | cksum | cut -d' ' -f1)
  cache="${REGENT_BOARDS:-${HOME:-/tmp}/.cache/regent/boards}/$project-$sum/usage-cache"
fi
mkdir -p "$cache" 2>/dev/null || { echo "ERROR cannot create $cache"; exit 2; }

# Claude Code names a project's transcript directory after its path, every non-alphanumeric character a "-"
# (on Windows the path is C:\... — `pwd -W` in Git Bash).
TRX=${REGENT_TRANSCRIPTS:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$( (pwd -W 2>/dev/null || pwd) | sed 's/[^A-Za-z0-9]/-/g')}

# --- parse: sessions changed since the last run → $cache/<session>.tsv ----------------------------------
# S run command args regent session start end active prompts | M run model effort agent calls in cw5m cw1h cr out
PARSE_AWK='
function val(l, k,   n) {
  if (!match(l, "\"" k "\":\"[^\"]*\"")) return ""
  n = length(k) + 4
  return substr(l, RSTART + n, RLENGTH - n - 1)
}
function num(l, k,   n) {
  if (!match(l, "\"" k "\":[0-9]+")) return 0
  n = length(k) + 3
  return substr(l, RSTART + n, RLENGTH - n) + 0
}
function epoch(t,   y, m, d, a, yy, mm) {
  y = substr(t, 1, 4) + 0; m = substr(t, 6, 2) + 0; d = substr(t, 9, 2) + 0
  a = (m <= 2); yy = y - a; mm = m + 12 * a - 3
  return (d + int((153 * mm + 2) / 5) + 365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) - 719469) * 86400 \
    + substr(t, 12, 2) * 3600 + substr(t, 15, 2) * 60 + substr(t, 18, 2)
}
FNR == 1 {
  f = FILENAME; gsub(/\\/, "/", f)
  sub_ = (f ~ /\/subagents\//)
  n = split(f, p, "/")
  if (sub_) {
    sess = p[n - 2]; agent = "subagent"
    mf = FILENAME; sub(/\.jsonl$/, ".meta.json", mf)
    if ((getline ml < mf) > 0) { a = val(ml, "agentType"); if (a != "") agent = a }
    close(mf)
  } else {
    sess = p[n]; sub(/\.jsonl$/, "", sess); cur = ""; sessions[sess] = 1
  }
  pid = ""
}
{
  l = $0
  if (index(l, "\"promptId\":\"")) pid = val(l, "promptId")
  user = index(l, "\"role\":\"user\"") && !index(l, "\"tool_use_id\"")
  if (!sub_ && user) {
    meta = index(l, "\"isMeta\":true")
    if (match(l, /<command-name>\/regent:[a-z-]+<\/command-name>/)) {
      cmd = substr(l, RSTART + 14, RLENGTH - 29)
      args = ""
      if (match(l, /<command-args>[^<]*<\/command-args>/)) args = substr(l, RSTART + 14, RLENGTH - 29)
      gsub(/\\[nt]/, " ", args); gsub(/[\t"]/, " ", args)
      cur = sess ":" pid; rcmd[cur] = cmd; rargs[cur] = args; rsess[cur] = sess; nrun[++nr] = cur
      t = val(l, "timestamp"); if (t != "") rstart[cur] = rend[cur] = epoch(t)
    }
    if (cur != "" && meta && rver[cur] == "" && match(l, /[\\\/]regent[\\\/]+[0-9]+\.[0-9]+\.[0-9]+[\\\/]+skills[\\\/]/)) {
      v = substr(l, RSTART, RLENGTH); gsub(/[^0-9.]/, "", v); rver[cur] = v
    }
    if (cur != "" && !meta && pid != "" && !(pid in prun)) {
      prun[pid] = cur; rprompts[cur]++
      t = val(l, "timestamp"); if (t != "") pstart[pid] = epoch(t)
    }
    next
  }
  if (!index(l, "\"role\":\"assistant\"") || !(u = index(l, "\"usage\":{"))) next
  run = prun[pid]
  # change directories the run writes to (one line per content block, so before the message.id dedup)
  if (run != "" && index(l, "\"type\":\"tool_use\"") && l ~ /"name":"(Write|Edit|MultiEdit|NotebookEdit|Bash)"/) {
    s = l
    while (match(s, /ai[\\\/]+changes[\\\/]+[A-Za-z0-9._-]+([\\\/]+[A-Za-z0-9._-]+)?/)) {
      w = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      gsub(/[\\\/]+/, "/", w); n = split(w, seg, "/"); c = seg[3]
      if (c == "archive") { if (n < 4) continue; c = seg[4]; sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-/, "", c) }
      if (!((run, c) in touch)) tkeys[++nt] = run SUBSEP c
      touch[run, c]++
    }
  }
  if (!match(l, /"id":"msg_[^"]*"/)) next
  id = substr(l, RSTART + 6, RLENGTH - 7)
  if (id in seen) next
  seen[id] = 1
  model = val(l, "model")
  if (run == "" || model == "" || model ~ /^</) next
  e = val(l, "perTurnEffort"); if (e == "") e = val(l, "effort"); if (e == "") e = "-"
  us = substr(l, u)
  cc = num(us, "cache_creation_input_tokens"); h1 = num(us, "ephemeral_1h_input_tokens")
  k = run SUBSEP model SUBSEP e SUBSEP (sub_ ? agent : "main")
  if (!(k in calls)) keys[++nk] = k
  calls[k]++; tin[k] += num(us, "input_tokens"); tc5[k] += cc - h1; tc1[k] += h1
  tcr[k] += num(us, "cache_read_input_tokens"); tout[k] += num(us, "output_tokens")
  t = val(l, "timestamp")
  if (t != "") {
    t = epoch(t)
    if (!(run in rstart) || t < rstart[run]) rstart[run] = t
    if (t > rend[run]) rend[run] = t
    if (t > pend[pid]) pend[pid] = t
  }
}
END {
  for (q in prun) if ((q in pstart) && (q in pend) && pend[q] > pstart[q]) ract[prun[q]] += pend[q] - pstart[q]
  for (i = 1; i <= nt; i++) {
    split(tkeys[i], kk, SUBSEP); s = rsess[kk[1]]
    out[s] = out[s] sprintf("T\t%s\t%s\t%d\n", kk[1], kk[2], touch[tkeys[i]])
  }
  for (i = 1; i <= nr; i++) {
    r = nrun[i]
    out[rsess[r]] = out[rsess[r]] sprintf("S\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\n", r, rcmd[r], rargs[r], rver[r], rsess[r], rstart[r], rend[r], ract[r], rprompts[r])
  }
  for (i = 1; i <= nk; i++) {
    split(keys[i], kk, SUBSEP); s = rsess[kk[1]]
    out[s] = out[s] sprintf("M\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n", kk[1], kk[2], kk[3], kk[4], calls[keys[i]], tin[keys[i]], tc5[keys[i]], tc1[keys[i]], tcr[keys[i]], tout[keys[i]])
  }
  for (s in sessions) { f = ENVIRON["CACHE"] "/" s ".tsv"; printf "%s", out[s] > f; close(f) }
}
'

parse() {
  [ -d "$TRX" ] || return 0
  stamp="$cache/.stamp"
  touch "$cache/.stamp.new"
  # newest first: stop at the first session older than the last parse (one ls instead of a stat per file)
  changed=""
  for n in $(ls -t "$TRX" 2>/dev/null | grep '\.jsonl$'); do
    [ -f "$stamp" ] && [ ! "$TRX/$n" -nt "$stamp" ] && break
    changed="$changed $TRX/$n"
  done
  # a running subagent writes only its own file — check the newest one of the latest sessions
  if [ -f "$stamp" ]; then
    for n in $(ls -t "$TRX" 2>/dev/null | grep '\.jsonl$' | head -n 5); do
      d="$TRX/${n%.jsonl}/subagents"
      [ -d "$d" ] || continue
      s=$(ls -t "$d" | grep '\.jsonl$' | head -n 1)
      [ -n "$s" ] && [ "$d/$s" -nt "$stamp" ] && changed="$changed $TRX/$n"
    done
  fi
  if [ -n "$changed" ]; then
    # shellcheck disable=SC2086
    mains=$(grep -l '<command-name>/regent:' $changed 2>/dev/null | sort -u)
    files=""
    for m in $mains; do
      files="$files $m"
      for s in "${m%.jsonl}"/subagents/*.jsonl; do [ -f "$s" ] && files="$files $s"; done
    done
    # shellcheck disable=SC2086
    [ -n "$files" ] && CACHE="$cache" awk "$PARSE_AWK" $files
  fi
  mv -f "$cache/.stamp.new" "$stamp"
}

# --- resolve: runs → changes, cost from the price list ---------------------------------------------------
names() {
  for d in ai/changes/*/ ai/changes/archive/*/; do
    [ -d "$d" ] || continue
    d=${d%/}; n=${d##*/}
    [ "$d" = ai/changes/archive ] && continue
    case "$d" in ai/changes/archive/*) case "$n" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-?*) n=${n:11} ;; esac ;; esac
    printf 'N\t%s\n' "$n"
  done
}

RESOLVE_AWK='
BEGIN { FS = "\t" }
FILENAME == ENVIRON["PRICES"] {
  if ($1 == "# as-of") asof = $2
  if ($1 !~ /^#/ && NF >= 6) { pin[$1] = $2; pout[$1] = $3; pc5[$1] = $4; pc1[$1] = $5; pcr[$1] = $6 }
  next
}
$1 == "N" { known[$2] = 1; next }
$1 == "T" { if ($3 in known) { tc[$2, $3] = $4; tl[$2] = tl[$2] " " $3 }; next }
$1 == "S" {
  ch = ""; n = split($4, w, " ")
  for (i = 1; i <= n && ch == ""; i++) if (w[i] in known) ch = w[i]
  # arguments without a change name (/regent:bugfix <description>): the change directory the run wrote to most
  if (ch == "") { best = 0; n = split(tl[$2], w, " "); for (i = 1; i <= n; i++) if (tc[$2, w[i]] > best) { best = tc[$2, w[i]]; ch = w[i] } }
  if (ch == "" || (ENVIRON["ONLY"] != "" && ch != ENVIRON["ONLY"])) next
  keep[$2] = 1
  printf "R\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $2, ch, $3, $5, $6, $7, $8, $9, $10
  next
}
$1 == "M" && ($2 in keep) {
  m = $3; sub(/\[.*\]$/, "", m); sub(/-20[0-9][0-9][0-9][0-9][0-9][0-9]$/, "", m)
  cost = (m in pin) ? ($7 * pin[m] + $8 * pc5[m] + $9 * pc1[m] + $10 * pcr[m] + $11 * pout[m]) / 1000000 : -1
  printf "M\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.4f\n", $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, cost
}
END { if (asof != "") printf "P\t%s\n", asof }
'

resolve() {
  { names; cat "$cache"/*.tsv 2>/dev/null; } | PRICES="$PRICES" ONLY="$1" awk "$RESOLVE_AWK" "$PRICES" -
}

# --- markdown for usage.md -------------------------------------------------------------------------------
MD_AWK='
BEGIN { FS = "\t" }
function k(n) { return n >= 1000000 ? sprintf("%.1fM", n / 1000000) : n >= 1000 ? sprintf("%.0fk", n / 1000) : n "" }
function dur(s) { s = int(s + 0.5); return s >= 3600 ? int(s / 3600) "h " int((s % 3600) / 60) "m" : s >= 60 ? int(s / 60) "m" : s "s" }
function usd(c) { return c < 0 ? "?" : sprintf("$%.2f", c) }
function date(t,   z, era, doe, yoe, y, doy, mp, d, m) {
  z = int(t / 86400) + 719468; era = int(z / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100)); mp = int((5 * doy + 2) / 153)
  d = doy - int((153 * mp + 2) / 5) + 1; m = mp < 10 ? mp + 3 : mp - 9; y += (m <= 2)
  return sprintf("%04d-%02d-%02d %02d:%02d", y, m, d, int((t % 86400) / 3600), int((t % 3600) / 60))
}
$1 == "P" { asof = $2; next }
$1 == "R" {
  nr++; rid[nr] = $2; rcmd[$2] = $4; rver[$2] = ($5 == "" ? "?" : $5); rstart[$2] = $7; ract[$2] = $9; rpr[$2] = $10
  if ($5 != "" && !($5 in vs)) { vs[$5] = 1; vers = vers (vers == "" ? "" : "/") $5 }
  tact += $9; tpr += $10; next
}
$1 == "M" {
  nm++; ml[nm] = $0; r = $2
  rc[r] += $6; ri[r] += $7; rw[r] += $8 + $9; rr[r] += $10; ro[r] += $11
  if ($12 < 0) unk[r] = 1; else rcost[r] += $12
  tc += $6; ti += $7; tw += $8 + $9; tr += $10; to += $11; if ($12 >= 0) tcost += $12
}
END {
  printf "# Usage: %s\n\n", ENVIRON["ONLY"]
  printf "Claude Code usage of this change, measured by `scripts/usage.sh` from the session transcripts on this machine.\n"
  printf "A run starts at a `/regent:` command naming the change (or writing to its directory) and takes the session'"'"'s prompts until the next `/regent:` command.\n"
  printf "Cost is an API-equivalent estimate (tokens × the price list of %s, `scripts/pricing.tsv`), not a bill. Times in UTC.\n\n", asof
  printf "| Field | Value |\n|-------|-------|\n"
  printf "| Cost USD | %.2f |\n| Active seconds | %d |\n| Runs | %d |\n| Prompts | %d |\n| Calls | %d |\n", tcost, tact, nr, tpr, tc
  printf "| Input tokens | %d |\n| Cache write tokens | %d |\n| Cache read tokens | %d |\n| Output tokens | %d |\n", ti, tw, tr, to
  printf "| Regent | %s |\n| Prices | %s |\n\n", (vers == "" ? "?" : vers), asof
  printf "## Runs\n\n| Started | Command | Regent | Active | Prompts | Calls | Input | Cache write | Cache read | Output | Cost |\n"
  printf "|---------|---------|--------|--------|---------|-------|-------|-------------|------------|--------|------|\n"
  for (i = 1; i <= nr; i++) {
    r = rid[i]
    printf "| %s | `%s` | %s | %s | %d | %d | %s | %s | %s | %s | %s%s |\n", date(rstart[r]), rcmd[r], rver[r], dur(ract[r]), rpr[r], rc[r], k(ri[r]), k(rw[r]), k(rr[r]), k(ro[r]), usd(rcost[r]), (r in unk ? " + ?" : "")
  }
  printf "\n## By model, effort and agent\n\n| Command | Model | Effort | Agent | Calls | Input | Cache write | Cache read | Output | Cost |\n"
  printf "|---------|-------|--------|-------|-------|-------|-------------|------------|--------|------|\n"
  for (i = 1; i <= nm; i++) {
    split(ml[i], f, "\t")
    printf "| `%s` | %s | %s | %s | %d | %s | %s | %s | %s | %s |\n", rcmd[f[2]], f[3], f[4], f[5], f[6], k(f[7]), k(f[8] + f[9]), k(f[10]), k(f[11]), usd(f[12])
  }
}
'

parse
if [ "$mode" = tsv ]; then
  resolve ""
  exit 0
fi
recs=$(resolve "$change")
printf '%s\n' "$recs" | grep -q '^R' || { echo "INFO  no run of $change in the transcripts ($TRX)" >&2; exit 3; }
# runs in start order
{ printf '%s\n' "$recs" | grep -v '^R'; printf '%s\n' "$recs" | grep '^R' | sort -t "$(printf '\t')" -k7,7n; } \
  | ONLY="$change" awk "$MD_AWK"
