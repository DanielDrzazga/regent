#!/usr/bin/env bash
# Tests for scripts/usage.sh — a fixture transcript in a temp directory, no network.
# Usage: bash scripts/tests/usage.test.sh      (exit code 0 = all green)

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
USAGE="$HERE/../usage.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/usage-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
P="$T/p"
X="$T/trx"
pass=0
fail=0
name=""
out=""
code=0

run() { out=$(cd "$P" && REGENT_TRANSCRIPTS="$X" "$BASH" "$USAGE" --cache "$T/cache" "$@" 2>&1); code=$?; }
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/      /'; }
expect_code() { [ "$code" -eq "$1" ] && ok || bad "exit code $code, expected $1"; }
expect_has()  { printf '%s\n' "$out" | grep -qF -- "$1" && ok || bad "missing from output: $1"; }
expect_not()  { if printf '%s\n' "$out" | grep -qF -- "$1"; then bad "unexpected in output: $1"; else ok; fi; }

mkdir -p "$P/ai/changes/add-login" "$X/s1/subagents"
asst() { # id model ts effort in cache_creation cache_1h cache_read out
  printf '{"parentUuid":"x","message":{"model":"%s","id":"%s","type":"message","role":"assistant","content":[{"type":"text","text":"note \\"model\\":\\"fake\\""}],"usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":%s}}},"type":"assistant","timestamp":"%s","effort":"%s","perTurnEffort":"%s"}\n' \
    "$2" "$1" "$5" "$6" "$8" "$9" "$7" "$3" "$4" "$4"
}
{
  printf '{"parentUuid":null,"promptId":"p1","type":"user","message":{"role":"user","content":"<command-message>apply</command-message>\\n<command-name>/regent:apply</command-name>\\n<command-args>add-login --tasks 2</command-args>"},"timestamp":"2026-11-10T10:00:00.000Z"}\n'
  printf '{"promptId":"p1","type":"user","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":"Base directory for this skill: C:\\\\Users\\\\x\\\\.claude\\\\plugins\\\\cache\\\\regent\\\\regent\\\\1.5.0\\\\skills\\\\apply"}]},"timestamp":"2026-11-10T10:00:00.100Z"}\n'
  asst msg_a1 claude-opus-5-5 2026-11-10T10:01:00.000Z high 1000 2000 2000 10000 500
  asst msg_a1 claude-opus-5-5 2026-11-10T10:01:00.000Z high 1000 2000 2000 10000 500
  printf '{"promptId":"p1","type":"user","message":{"role":"user","content":[{"tool_use_id":"t1","type":"tool_result","content":"<command-name>/regent:status</command-name>"}]},"timestamp":"2026-11-10T10:04:00.000Z"}\n'
  printf '{"promptId":"p2","type":"user","message":{"role":"user","content":"yes, continue"},"timestamp":"2026-11-10T10:05:00.000Z"}\n'
  asst msg_a2 claude-opus-5-5 2026-11-10T10:06:00.000Z high 100 0 0 20000 300
  printf '{"promptId":"p3","type":"user","message":{"role":"user","content":"<command-name>/regent:status</command-name>\\n<command-args></command-args>"},"timestamp":"2026-11-10T11:00:00.000Z"}\n'
  asst msg_a3 claude-opus-5-5 2026-11-10T11:01:00.000Z high 9999 0 0 0 9999
} > "$X/s1.jsonl"
printf '{"agentType":"regent:backend-dev","isBuiltIn":false}\n' > "$X/s1/subagents/agent-b.meta.json"
{
  printf '{"promptId":"p1","isSidechain":true,"type":"user","message":{"role":"user","content":"Implement T-02"},"timestamp":"2026-11-10T10:01:30.000Z"}\n'
  asst msg_b1 claude-sonnet-5-5 2026-11-10T10:03:00.000Z medium 50 4000 0 0 800
} > "$X/s1/subagents/agent-b.jsonl"
printf '{"promptId":"q1","type":"user","message":{"role":"user","content":"hello"},"timestamp":"2026-11-10T09:00:00.000Z"}\n' > "$X/s2.jsonl"
tool() { # id name input-json — a tool_use line: the change directory written decides the run of a bugfix
  printf '{"message":{"model":"claude-opus-5-5","id":"%s","type":"message","role":"assistant","content":[{"type":"tool_use","id":"tu_%s","name":"%s","input":%s}],"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":100}},"type":"assistant","timestamp":"2026-11-10T12:01:00.000Z","effort":"high"}\n' "$1" "$1" "$2" "$3"
}
mkdir -p "$P/ai/changes/fix-login"
{
  printf '{"promptId":"r1","type":"user","message":{"role":"user","content":"<command-name>/regent:bugfix</command-name>\\n<command-args>login button does nothing</command-args>"},"timestamp":"2026-11-10T12:00:00.000Z"}\n'
  tool msg_c1 Read '{"file_path":"ai/changes/add-login/proposal.md"}'
  tool msg_c1 Write '{"file_path":"C:\\\\p\\\\ai\\\\changes\\\\fix-login\\\\proposal.md","content":"x"}'
  tool msg_c2 Bash '{"command":"git add ai/changes/fix-login/tasks.md ai/changes/fix-login/design.md"}'
  printf '{"promptId":"r2","type":"user","message":{"role":"user","content":"<command-name>/regent:hotfix</command-name>\\n<command-args>crash</command-args>"},"timestamp":"2026-11-10T13:00:00.000Z"}\n'
  tool msg_c3 Edit '{"file_path":"ai/changes/gone-change/tasks.md"}'
} > "$X/s3.jsonl"

name="wrong usage"
run; expect_code 2

# opus 5.5: 1000*4 + 2000*8 (1h write) + 10000*0.2 + 500*20 = 32000; 100*4 + 20000*0.2 + 300*20 = 10400
# sonnet 5.5 (subagent, 5m write): 50*2 + 4000*2.5 + 800*10 = 18100  → 60500 / 1e6 = 0.0605
name="usage.md: totals of the change"
run add-login; expect_code 0
expect_has '# Usage: add-login'
expect_has '| Cost USD | 0.06 |'
expect_has '| Active seconds | 240 |'
expect_has '| Runs | 1 |'
expect_has '| Prompts | 2 |'
expect_has '| Calls | 3 |'
expect_has '| Input tokens | 1150 |'
expect_has '| Cache write tokens | 6000 |'
expect_has '| Cache read tokens | 30000 |'
expect_has '| Output tokens | 1600 |'
expect_has '| Regent | 1.5.0 |'
expect_has '| Prices | 2026-11-03 |'

name="usage.md: run and breakdown by model, effort and agent"
expect_has '| 2026-11-10 10:00 | `/regent:apply` | 1.5.0 | 4m | 2 | 3 | 1k | 6k | 30k | 2k | $0.06 |'
expect_not '10:01 | `/regent:apply`'
expect_has '| `/regent:apply` | claude-opus-5-5 | high | main | 2 | 1k | 2k | 30k | 800 | $0.04 |'
expect_has '| `/regent:apply` | claude-sonnet-5-5 | medium | regent:backend-dev | 1 | 50 | 4k | 0 | 800 | $0.02 |'
expect_not '9999'

name="a change without runs"
mkdir -p "$P/ai/changes/other"
run other; expect_code 3

name="a run without a change name — the change directory its calls wrote to"
run fix-login; expect_code 0
expect_has '| 2026-11-10 12:00 | `/regent:bugfix` | ? | 1m | 1 | 2 |'
expect_has '| Calls | 2 |'
expect_not '/regent:hotfix'

name="/regent:propose before its change directory exists — counted once the directory appears"
printf '%s\n' '{"promptId":"n1","type":"user","message":{"role":"user","content":"<command-name>/regent:propose</command-name> <command-args>brand-new</command-args>"},"timestamp":"2026-11-10T14:00:00.000Z"}' > "$X/s4.jsonl"
tool msg_d1 Write '{"file_path":"ai/changes/brand-new/proposal.md","content":"x"}' >> "$X/s4.jsonl"
run brand-new; expect_code 3
run --tsv; expect_not "$(printf '\tbrand-new\t')"
mkdir -p "$P/ai/changes/brand-new"
run brand-new; expect_code 0; expect_has '| Runs | 1 |'

name="tsv records for the dashboard"
run --tsv; expect_code 0
expect_not "$(printf '\tgone-change\t')"
expect_has "$(printf 'R\ts1:p1\tadd-login\t/regent:apply\t1.5.0\ts1\t')"
expect_has "$(printf '\tclaude-sonnet-5-5\tmedium\tregent:backend-dev\t1\t50\t4000\t0\t0\t800\t0.0181')"
expect_has "$(printf 'P\t2026-11-03')"
expect_not '/regent:status'

name="archived change matched without its date prefix"
mv "$P/ai/changes/add-login" "$P/ai/changes/archive-tmp"; mkdir -p "$P/ai/changes/archive"
mv "$P/ai/changes/archive-tmp" "$P/ai/changes/archive/2026-11-11-add-login"
run add-login; expect_code 0; expect_has '| Cost USD | 0.06 |'

name="cache: a session whose subagent wrote is parsed again"
sleep 1
asst msg_b2 claude-sonnet-5-5 2026-11-10T10:04:00.000Z medium 0 0 0 0 1000 >> "$X/s1/subagents/agent-b.jsonl"
run add-login; expect_code 0
expect_has '| Output tokens | 2600 |'

echo "usage tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
