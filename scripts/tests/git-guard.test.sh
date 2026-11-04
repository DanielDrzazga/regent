#!/usr/bin/env bash
# Tests for scripts/hooks/git-guard.sh — PreToolUse hook JSON on stdin, expected exit code;
# scope: SDD project (ai/docs/), non-SDD project, GIT_GUARD_FORCE.
# Usage: bash scripts/tests/git-guard.test.sh      (exit code 0 = all green)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/git-guard.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/git-guard.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/sdd/ai/docs" "$T/plain"
PROJECT="$T/sdd"
pass=0
fail=0

# expect <code> <command> [description]
expect() {
  json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"%s"}}' "$2" "${3:-}")
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$PROJECT" "$BASH" "$HOOK" >/dev/null 2>&1
  code=$?
  if [ "$code" -eq "$1" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: '$2' → code $code, expected $1"; fi
}

# blocked
expect 2 'git add .'
expect 2 'git add -A'
expect 2 'git add --all'
expect 2 'git add -u'
expect 2 'git add . && git commit -m \"x\"'
expect 2 'cd app && git add .'
expect 2 'git -C repo add -A'
expect 2 'git commit -am \"fix\"'
expect 2 'git commit -a -m \"fix\"'
expect 2 'git commit -m \"x\" --no-verify'
expect 2 'git push --no-verify'
expect 2 'git commit -n -m \"x\"'
expect 2 'git commit --all -m x'
expect 2 'git add ./'
expect 2 'git add :/'
expect 2 'git add -Av'
expect 2 'git -c core.autocrlf=false add .'
expect 2 'git -c core.hooksPath=/dev/null commit -m x'
expect 2 'git -c core.hookspath=/dev/null commit -m x'
expect 2 'git -c CORE.HOOKSPATH=x push'
expect 2 'git -c core.hooksPath commit -m x'
expect 2 'git -C repo -c core.hooksPath=/dev/null commit -m x'
expect 2 'git --config-env=core.hooksPath=HP commit -m x'
expect 2 'git status && git -c core.hooksPath=/tmp/h push'

# allowed
expect 0 'git add src/a.ts tests/a.test.ts'
expect 0 'git add ./src/a.ts'
expect 0 'git commit -m \"feat: add login\"'
expect 0 'git commit --amend -m \"x\"'
expect 0 'git status'
expect 0 'ls -A'
expect 0 'git status' 'checking state before git add .'
expect 0 'echo \"--no-verify is a bad idea\"'
expect 0 'git commit -m \"drop -a flag\"'
expect 0 'git add \"src/a b.ts\" src/c.ts'
expect 0 'git commit -m \"x\" --no-edit'
expect 0 'git -c core.autocrlf=false commit -m x'
expect 0 'git config --get core.hooksPath'

# AI attribution in commit or PR text — checked in data (quotes, heredoc)
expect 2 'git commit -m \"feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\"'
expect 2 'git commit -m \"feat: x\n\nco-authored-by: claude opus\"'
expect 2 "git commit -F - <<'EOF'\nfeat: x\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>\nEOF"
expect 2 "git commit -m \\\"\$(cat <<'EOF'\nfeat: x\n\nGenerated with [Claude Code](https://claude.com/claude-code)\nEOF\n)\\\""
expect 2 'git commit -m \"fix: y\n\nhttps://claude.ai/code/session_abc\"'
expect 2 'git -C repo commit -m \"x\n\nnoreply@anthropic.com\"'
expect 2 'gh pr create --title x --body \"description\n\nGenerated with Claude Code\"'
expect 2 'git merge --no-ff -m \"merge\n\nCo-Authored-By: Claude\" feat/x'
expect 0 'git commit -m \"feat: x\n\nCo-Authored-By: John Smith <john@example.com>\"'
expect 0 'git commit -m \"docs: describe the Co-Authored-By trailer ban\"'
expect 0 'echo \"Co-Authored-By: Claude\"'
expect 0 'git log --grep \"Co-Authored-By: Claude\"'
expect 0 'gh pr view 12'

# multiple lines: each line is a separate command; heredoc, quote and comment bodies are data
expect 0 'git commit -q -m init\ntmux new-session -d -s s -n lead'
expect 0 "cat > file <<'EOF'\nDo not use git add . or git commit -n\nEOF"
expect 0 'cat > file <<\"EOF\"\ngit add -A\nEOF'
expect 0 'cat <<EOF > file\ngit commit -a\nEOF\ngit status'
expect 0 'cat <<-EOF\n\tgit add .\n\tEOF\ngit status'
expect 0 'git commit -m \"feat: x\n\ndescription -n and -a\"'
expect 0 'git commit -m \"quote \\\" -n\"'
expect 0 "# don't stage everything\ngit status"
expect 0 'git commit -F - <<< \"msg -n\"'
expect 2 'cat > f <<EOF\ntext\nEOF\ngit add .'
expect 2 'git commit -n -F - <<EOF\nmsg\nEOF'
expect 2 'cat <<EOF && git add .\nx\nEOF'
expect 2 "# don't\ngit add .\necho 'x'"
expect 2 'git commit \\\n-n -m x'
expect 2 'cat <<< \"x\"\ngit add .'
expect 2 'echo $((1<<2))\ngit add .'
expect 2 'cat <<EOF\ngit add .'
expect 2 'git commit -m \"x -n'

# scope: outside an SDD project lets through, GIT_GUARD_FORCE=1 enforces
PROJECT="$T/plain"
expect 0 'git add .' 'project without ai/docs'
expect 0 'git commit -m \"x\" --no-verify' 'project without ai/docs'
export GIT_GUARD_FORCE=1
expect 2 'git add .' 'project without ai/docs, GIT_GUARD_FORCE=1'
unset GIT_GUARD_FORCE
# without CLAUDE_PROJECT_DIR the current directory decides
code=$(cd "$T/sdd" && printf '%s' '{"tool_input":{"command":"git add ."}}' | env -u CLAUDE_PROJECT_DIR "$BASH" "$HOOK" >/dev/null 2>&1; echo $?)
if [ "$code" -eq 2 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: no CLAUDE_PROJECT_DIR in an SDD project → code $code, expected 2"; fi

echo "git-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
