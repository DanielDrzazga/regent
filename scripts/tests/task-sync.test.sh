#!/usr/bin/env bash
# Testy scripts/hooks/task-sync.sh — zakres ai/docs/, korzeń gita z cwd, pola JSON-a bez jq,
# cisza na stdout, zawsze kod 0, brak CLI → cisza, błąd CLI → hook.log obok bazy;
# na koniec prawdziwy sync przez zbudowane CLI (gdy jest tools/regent/dist i node).
# Użycie: bash scripts/tests/task-sync.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO/scripts/hooks/task-sync.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/task-sync.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugin/scripts" "$T/bin" "$T/sdd/.git" "$T/sdd/ai/docs" "$T/sdd/src/deep" "$T/plain/.git" "$T/state"
cp "$REPO/scripts/regent.sh" "$T/plugin/scripts/regent.sh"
SDD=$(cd "$T/sdd" && pwd -P)
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; }

# Udawany regent w PATH: zapisuje argumenty (po jednym w linii) i katalog, szumi na stdout i stderr.
cat > "$T/bin/regent" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CALLS"
pwd -P > "$CALLS.pwd"
echo "Sync: szum na stdout"
[ "${REGENT_FAKE_CODE:-0}" -eq 0 ] || printf 'regent: błąd: baza zablokowana\ndruga linia\n' >&2
exit ${REGENT_FAKE_CODE:-0}
EOF
chmod +x "$T/bin/regent"
CALLS="$T/calls"
SYSPATH=/usr/bin:/bin

# run <stdin> [PATH] — hook z udawanym pluginem; stdout do $out, kod do $code
run() {
  rm -f "$CALLS" "$CALLS.pwd"
  out=$(printf '%s' "$1" | CALLS="$CALLS" CLAUDE_PLUGIN_ROOT="$T/plugin" CLAUDE_PROJECT_DIR="${PROJECT_DIR:-}" \
    REGENT_DB="$T/state/regent.db" PATH="${2:-$T/bin:$SYSPATH}" "$BASH" "$HOOK" 2>/dev/null)
  code=$?
}
json() { printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"%s"}' "$1" "$2" "$3" "${4:-Stop}"; }
expect_quiet() {
  if [ "$code" -eq 0 ]; then ok; else ko "kod $code"; fi
  if [ -z "$out" ]; then ok; else ko "stdout niepusty: $out"; fi
}
expect_args() {
  want=$(printf '%s\n' "$@")
  if [ -f "$CALLS" ] && [ "$(cat "$CALLS")" = "$want" ]; then ok; else ko "argumenty: $(tr '\n' ' ' < "$CALLS" 2>/dev/null)"; fi
}
expect_not_called() { if [ -f "$CALLS" ]; then ko "CLI wywołane: $(tr '\n' ' ' < "$CALLS")"; else ok; fi; }

name="projekt SDD: sync z sesją i transkryptem, w korzeniu projektu, cisza na stdout"
run "$(json s-1 "/t/sesja 1.jsonl" "$SDD")"
expect_quiet
expect_args task sync --source hook --session-id s-1 --transcript-path "/t/sesja 1.jsonl"
if [ "$(cat "$CALLS.pwd" 2>/dev/null)" = "$SDD" ]; then ok; else ko "katalog: $(cat "$CALLS.pwd" 2>/dev/null)"; fi

name="cwd w podkatalogu: korzeń gita z ai/docs"
run "$(json s-1 /t/x.jsonl "$SDD/src/deep" SessionStart)"
expect_quiet
if [ "$(cat "$CALLS.pwd" 2>/dev/null)" = "$SDD" ]; then ok; else ko "katalog: $(cat "$CALLS.pwd" 2>/dev/null)"; fi

name="projekt bez ai/docs: CLI nie startuje"
run "$(json s-1 /t/x.jsonl "$T/plain")"
expect_quiet; expect_not_called

name="brak cwd w JSON-ie: CLAUDE_PROJECT_DIR"
PROJECT_DIR="$SDD" run '{"session_id":"s-2","hook_event_name":"Stop"}'
expect_quiet; expect_args task sync --source hook --session-id s-2

name="JSON wielolinijkowy ze spacjami i escapingiem w ścieżce"
run "$(printf '{\n  "hook_event_name" : "Stop",\n  "session_id" : "s-3",\n  "transcript_path" : "C:\\\\t\\\\a \\"b\\".jsonl",\n  "cwd" : "%s"\n}' "$SDD")"
expect_quiet; expect_args task sync --source hook --session-id s-3 --transcript-path 'C:\t\a "b".jsonl'

name="bez session_id: sync bez sesji"
run "$(printf '{"cwd":"%s"}' "$SDD")"
expect_quiet; expect_args task sync --source hook

name="pusty stdin i katalog, którego nie ma: kod 0, nic"
PROJECT_DIR="$T/nie-ma" run ''
expect_quiet; expect_not_called

name="brak CLI: cisza i bez logu"
rm -f "$T/state/hook.log"
run "$(json s-1 /t/x.jsonl "$SDD")" "$SYSPATH"
expect_quiet
if [ -f "$T/state/hook.log" ]; then ko "log przy braku CLI"; else ok; fi

name="błąd CLI: kod 0, cisza na stdout, jedna linia w hook.log obok bazy"
REGENT_FAKE_CODE=4 run "$(json s-1 /t/x.jsonl "$SDD")"
expect_quiet
if [ "$(wc -l < "$T/state/hook.log" | tr -d ' ')" -eq 1 ] \
  && grep -q "Stop $SDD: kod 4 — regent: błąd: baza zablokowana druga linia" "$T/state/hook.log"; then ok; else ko "log: $(cat "$T/state/hook.log" 2>/dev/null)"; fi

name="log powyżej 256 KB przechodzi do hook.log.1"
awk 'BEGIN { for (i = 0; i < 4000; i++) print "stara linia logu stara linia logu stara linia logu stara linia logu stara" }' > "$T/state/hook.log"
REGENT_FAKE_CODE=4 run "$(json s-1 /t/x.jsonl "$SDD")"
if [ -f "$T/state/hook.log.1" ] && [ "$(wc -l < "$T/state/hook.log" | tr -d ' ')" -eq 1 ]; then ok; else ko "rotacja"; fi

# --- prawdziwe CLI ------------------------------------------------------------------------------
CLI="$REPO/tools/regent/dist/cli.js"
NODE=$(command -v node 2>/dev/null)
if [ -z "$NODE" ] || [ ! -f "$CLI" ]; then
  echo "SKIP [prawdziwe CLI] brak node albo tools/regent/dist — npm install w tools/regent"
else
  P="$T/real"
  mkdir -p "$P/.git" "$P/ai/docs"
  cp -R "$REPO/tools/regent/test/fixtures/ai/changes" "$P/ai/"
  P=$(cd "$P" && pwd -P)
  DB="$T/real.db"
  regent() { (cd "$P" && REGENT_DB="$DB" "$NODE" "$CLI" "$@"); }

  hook() { out=$(printf '%s' "$1" | CLAUDE_PLUGIN_ROOT="$REPO" REGENT_DB="$DB" "$BASH" "$HOOK" 2>&1); code=$?; }

  name="prawdziwe CLI: pierwszy hook zakłada zmiany z ai/changes/ i zapisuje czas sync"
  hook "$(json s-9 "$T/s-9.jsonl" "$P" SessionStart)"
  expect_quiet
  if regent task list --json | grep -q '"key": "sdd:note-tags"'; then ok; else ko "brak sdd:note-tags w bazie"; fi
  if regent task list | grep -q '^Ostatni sync: .* (hook)$'; then ok; else ko "list bez „Ostatni sync … (hook)”"; fi

  name="prawdziwe CLI: hook Stop dopina transkrypt do zadania wziętego w tej sesji"
  id=$(regent task list --json | "$NODE" -e '
    let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () =>
      process.stdout.write(String(JSON.parse(s).tasks.find((t) => t.key === "T-02").id)));')
  (cd "$P" && CLAUDECODE=1 CLAUDE_CODE_SESSION_ID=s-9 REGENT_DB="$DB" "$NODE" "$CLI" task take "$id" >/dev/null)
  hook "$(json s-9 "$T/s-9.jsonl" "$P")"
  expect_quiet
  if regent task show "$id" --json | grep -q "\"transcriptPath\": \"$T/s-9.jsonl\""; then ok; else ko "transkrypt nie dopięty do #$id"; fi
fi

echo "task-sync tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
