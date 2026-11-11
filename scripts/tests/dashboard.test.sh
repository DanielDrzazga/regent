#!/usr/bin/env bash
# Tests for scripts/dashboard.sh — fixtures in a temp directory, no network, no browser.
# Usage: bash scripts/tests/dashboard.test.sh      (exit code 0 = all green)

set -u
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
HERE=$(cd "$(dirname "$0")" && pwd)
DASH="$HERE/../dashboard.sh"
TEMPLATE="$HERE/../../templates/dashboard.html"
T=$(mktemp -d "${TMPDIR:-/tmp}/dashboard-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
P="$T/p"
O="$T/out"
pass=0
fail=0
name=""
out=""
code=0

run() { out=$(cd "$P" && REGENT_TRANSCRIPTS="$T/no-transcripts" "$BASH" "$DASH" "$@" 2>&1); code=$?; }
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/      /'; }
expect_code() { [ "$code" -eq "$1" ] && ok || bad "exit code $code, expected $1"; }
expect_has()  { printf '%s\n' "$out" | grep -qE -- "$1" && ok || bad "missing from output: $1"; }
data_has()    { grep -qF -- "$1" "$O/data.js" && ok || bad "missing from data.js: $1"; }
data_not()    { if grep -qF -- "$1" "$O/data.js"; then bad "unexpected in data.js: $1"; else ok; fi; }
g() { git -C "$P" -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
sum() { cksum < "$O/data.js"; }

mkdir -p "$P"
name="no ai/ directory"
run --out "$O"; expect_code 2; expect_has '^ERROR no ai/ directory'

name="wrong usage"
mkdir -p "$P/ai/changes"
run --watch 0; expect_code 2
run --bogus; expect_code 2

# --- fixture: a change per stage + an archived one --------------------------------------------
C="$P/ai/changes"
mkdir -p "$P/ai/specs" "$C/draft-one" "$C/doing/specs" "$C/done-one" "$C/archive/2026-01-02-old-change" "$P/src"
cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

### REQ-001: Login

- AC-1: correct password logs in
EOF
printf '| Status | Draft |\n' > "$C/draft-one/proposal.md"
printf '| Status | Approved |\n| Type | feature |\n' > "$C/doing/proposal.md"
printf '# Design\n\n## Affected Files\n\n- `src/app.js`\n' > "$C/done-one/design.md"
printf '| Status | Approved |\n' > "$C/done-one/proposal.md"
A="$C/archive/2026-01-02-old-change"
printf '| **Status** | `Approved` |\n| Type | bugfix |\n| Ticket | KEY-7 |\n| Created | 2025-12-20 |\n\n### Summary\n\nFix the "login" loop\n' > "$A/proposal.md"
printf -- '- [x] T-01: fix\n- [ ] T-02: docs\n```\n- [x] T-99: inside a code block\n```\n---\nTotal: 2 tasks | Size: S\n' > "$A/tasks.md"
printf 'Verdict: PASS\nDate: 2026-01-01\n' > "$A/verification.md"
printf '# Usage: old-change\n\n| Field | Value |\n|-------|-------|\n| Cost USD | 1.50 |\n| Active seconds | 900 |\n| Regent | 1.4.0/1.5.0 |\n' > "$A/usage.md"
printf 'say "quoted" back\\slash </script>\r\nsecond line\r\n' > "$C/doing/specs/auth.md"
echo 'v1' > "$P/src/app.js"
g init -q; g add -A; g commit -q -m "feat: start"
h=$(git -C "$P" rev-parse --short HEAD)
full=$(git -C "$P" rev-parse HEAD)
printf -- '- [x] T-01: [BE] Login — REQ-001/AC-1 — verification: test ✅ (commit: %s · tests: t.js)\n- [ ] T-02: [FE] Form — no REQ: UI — verification: e2e\n' "$h" > "$C/doing/tasks.md"
printf -- '- [x] T-01: Login — REQ-001 — verification: test ✅ (commit: %s · tests: t.js)\n' "$h" > "$C/done-one/tasks.md"
printf 'Verdict: PASS\nDate: 2026-11-10\nCommit HEAD: %s\n' "$h" > "$C/done-one/verification.md"

name="board written"
run --out "$O"; expect_code 0; expect_has '^Board: .*index\.html$'
cmp -s "$TEMPLATE" "$O/index.html" && ok || bad "index.html differs from templates/dashboard.html"
head -c 40 "$O/data.js" | grep -q '^window.regentBoard({"generated":"' && ok || bad "data.js does not start with the regentBoard call"
tail -c 4 "$O/data.js" | grep -q '});' && ok || bad "data.js does not end with });"

name="active changes with their files"
data_has '"name":"draft-one","dir":"draft-one","place":"active"'
data_has '["specs/auth.md","say \"quoted\" back\\slash </script>\nsecond line"]'
data_not '"name":"old-change","dir":"2026-01-02-old-change","place"'

name="archived change: a summary in data.js, its files in archive/<dir>.js"
data_has '"archive":[{"name":"old-change","dir":"2026-01-02-old-change","archived":"2026-01-02","type":"bugfix","status":"Approved","ticket":"KEY-7","created":"2025-12-20","size":"S","done":1,"total":2,"verdict":"PASS","vdate":"2026-01-01","summary":"Fix the \"login\" loop","cost":"1.50","active":"900","regent":"1.4.0/1.5.0"}]'
data_has "$(printf '"usage":"P\t2026-11-03"')"
data_not 'inside a code block'
D="$O/archive/2026-01-02-old-change.js"
head -c 52 "$D" 2>/dev/null | grep -qF 'window.regentArchive("2026-01-02-old-change",{"commi' && ok || bad "missing or malformed $D"
grep -qF '["tasks.md","- [x] T-01: fix' "$D" && ok || bad "$D: no tasks.md"
data_has '"index":"auth: REQ-001 Login (AC: 1)"'
data_not "$(printf '\r')"

name="recorded commit resolved to sha, date and subject"
tab=$(printf '\t')
data_has "\"commits\":\"$full${tab}"
data_has "${tab}feat: start\""

name="no drift right after verification"
data_has '"dir":"done-one","place":"active","archived":"","updated":"'
grep -qE '"dir":"done-one"[^{]*"drift":0' "$O/data.js" && ok || bad "done-one drift should be 0"

name="unchanged data — data.js not rewritten"
before=$(sum)
run --out "$O"; expect_code 0
[ "$before" = "$(sum)" ] && ok || bad "data.js rewritten without a change"

name="unchanged archive — archive part not rebuilt"
echo '// cached' >> "$D"
run --out "$O"; expect_code 0
grep -q '^// cached' "$D" && ok || bad "archive rebuilt without a change"

name="a change moved into the archive — archive part rebuilt"
sleep 1
mkdir -p "$C/archive/2026-02-03-next"; printf '| Status | Abandoned |\n' > "$C/archive/2026-02-03-next/proposal.md"
run --out "$O"; expect_code 0
grep -q '^// cached' "$D" && bad "archive not rebuilt" || ok
data_has '{"name":"next","dir":"2026-02-03-next","archived":"2026-02-03","type":"","status":"Abandoned"'
data_has '"summary":"","cost":"","active":"","regent":""}'
[ -f "$O/archive/2026-02-03-next.js" ] && ok || bad "missing archive/2026-02-03-next.js"

name="code moved after verification — drift"
echo 'v2' > "$P/src/app.js"; g add -A; g commit -q -m "fix: outside the cycle"
run --out "$O"; expect_code 0
grep -qE '"dir":"done-one"[^{]*"drift":1' "$O/data.js" && ok || bad "done-one drift should be 1"

# --- hook builds -------------------------------------------------------------------------------
B="$T/boards"
hookrun() { out=$(cd "$1" && REGENT_BOARDS="$B" REGENT_TRANSCRIPTS="$T/no-transcripts" "$BASH" "$DASH" --hook "$2" 2>&1); code=$?; }
board() { ls -d "$B"/*/ 2>/dev/null | head -n 1; }

name="hook: no ai/ — nothing, no board"
mkdir -p "$T/plain"
hookrun "$T/plain" turn; expect_code 0
[ -z "$out" ] && ok || bad "hook printed output"
[ -z "$(board)" ] && ok || bad "board written for a project without ai/"

name="hook: quiet build at one path per project"
hookrun "$P" start; expect_code 0
[ -z "$out" ] && ok || bad "hook printed output"
D2=$(board)
[ -n "$D2" ] && [ -f "${D2}data.js" ] && [ -f "${D2}index.html" ] && ok || bad "no board under REGENT_BOARDS"
[ ! -d "${D2}.lock" ] && ok || bad "lock left after the build"

name="hook: a build in progress — request recorded, no second build"
mkdir "${D2}.lock"; s1=$(cksum < "${D2}data.js")
echo "- [ ] T-03: [BE] new — no REQ: x — verification: y" >> "$C/doing/tasks.md"
hookrun "$P" turn; expect_code 0
[ -f "${D2}.pending" ] && ok || bad "no .pending for the running build"
[ "$s1" = "$(cksum < "${D2}data.js")" ] && ok || bad "built despite the lock"
rmdir "${D2}.lock"

name="hook: tools throttled to one build per 20 s"
hookrun "$P" turn; expect_code 0
grep -qF 'T-03: [BE] new' "${D2}data.js" && ok || bad "turn build missed the change"
echo "- [ ] T-04: [BE] newer — no REQ: x — verification: y" >> "$C/doing/tasks.md"
hookrun "$P" tool; expect_code 0
grep -qF 'T-04' "${D2}data.js" && bad "tool build ran within 20 s" || ok
echo $(( $(date +%s) - 60 )) > "${D2}.hook-at"
hookrun "$P" tool; expect_code 0
grep -qF 'T-04' "${D2}data.js" && ok || bad "tool build skipped after 20 s"

name="hook script: returns at once, the build finishes in the background"
H="$HERE/../hooks/dashboard-refresh.sh"
rm -rf "$B"
out=$(cd "$T" && printf '{}' | CLAUDE_PROJECT_DIR="$P" REGENT_BOARDS="$B" REGENT_TRANSCRIPTS="$T/no-transcripts" "$BASH" "$H" start 2>&1); code=$?
expect_code 0
[ -z "$out" ] && ok || bad "hook script printed output"
i=0; while [ $i -lt 60 ] && ! ls "$B"/*/data.js >/dev/null 2>&1; do sleep 0.5; i=$((i + 1)); done
ls "$B"/*/data.js >/dev/null 2>&1 && ok || bad "no board 30 s after the hook"
out=$(CLAUDE_PROJECT_DIR="$T/plain" "$BASH" "$H" turn 2>&1); code=$?
expect_code 0
out=$("$BASH" "$H" 2>&1); code=$?
expect_code 0; expect_has 'usage: <start\|turn\|tool>'

name="data.js is valid JavaScript"
if command -v node >/dev/null 2>&1; then
  res=$(node -e 'let d; global.window = { regentBoard: (x) => { d = x } }; require(process.argv[1]);
    const n = d.changes.map(c => c.name).join(",") + "|" + d.archive.map(a => a.name).join(",");
    if (n !== "doing,done-one,draft-one|old-change,next") throw new Error(n); console.log("ok")' "$O/data.js" 2>&1)
  [ "$res" = ok ] && ok || bad "node: $res"
fi

echo "dashboard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
