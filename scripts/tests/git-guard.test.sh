#!/usr/bin/env bash
# Testy scripts/hooks/git-guard.sh — JSON hooka PreToolUse na stdin, oczekiwany kod wyjścia;
# zakres: projekt SDD (ai/docs/), projekt bez SDD, GIT_GUARD_FORCE.
# Użycie: bash scripts/tests/git-guard.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/git-guard.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/git-guard.XXXXXX")
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/sdd/ai/docs" "$T/plain"
PROJECT="$T/sdd"
pass=0
fail=0

# expect <kod> <komenda> [description]
expect() {
  json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"%s"}}' "$2" "${3:-}")
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$PROJECT" "$BASH" "$HOOK" >/dev/null 2>&1
  code=$?
  if [ "$code" -eq "$1" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: '$2' → kod $code, oczekiwano $1"; fi
}

# blokowane
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

# przepuszczane
expect 0 'git add src/a.ts tests/a.test.ts'
expect 0 'git add ./src/a.ts'
expect 0 'git commit -m \"feat: add login\"'
expect 0 'git commit --amend -m \"x\"'
expect 0 'git status'
expect 0 'ls -A'
expect 0 'git status' 'przed git add . sprawdzam stan'
expect 0 'echo \"--no-verify to zly pomysl\"'
expect 0 'git commit -m \"drop -a flag\"'
expect 0 'git add \"src/a b.ts\" src/c.ts'
expect 0 'git commit -m \"x\" --no-edit'
expect 0 'git -c core.autocrlf=false commit -m x'
expect 0 'git config --get core.hooksPath'

# atrybucja AI w treści commita lub PR — sprawdzana w danych (cudzysłowy, heredoc)
expect 2 'git commit -m \"feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\"'
expect 2 'git commit -m \"feat: x\n\nco-authored-by: claude opus\"'
expect 2 "git commit -F - <<'EOF'\nfeat: x\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>\nEOF"
expect 2 "git commit -m \\\"\$(cat <<'EOF'\nfeat: x\n\nGenerated with [Claude Code](https://claude.com/claude-code)\nEOF\n)\\\""
expect 2 'git commit -m \"fix: y\n\nhttps://claude.ai/code/session_abc\"'
expect 2 'git -C repo commit -m \"x\n\nnoreply@anthropic.com\"'
expect 2 'gh pr create --title x --body \"opis\n\nGenerated with Claude Code\"'
expect 2 'git merge --no-ff -m \"merge\n\nCo-Authored-By: Claude\" feat/x'
expect 0 'git commit -m \"feat: x\n\nCo-Authored-By: Jan Kowalski <jan@example.com>\"'
expect 0 'git commit -m \"docs: opisz zakaz stopki Co-Authored-By\"'
expect 0 'echo \"Co-Authored-By: Claude\"'
expect 0 'git log --grep \"Co-Authored-By: Claude\"'
expect 0 'gh pr view 12'

# wiele linii: każda linia to osobne polecenie; treść heredoca, cudzysłowów i komentarzy to dane
expect 0 'git commit -q -m init\ntmux new-session -d -s s -n lead'
expect 0 "cat > plik <<'EOF'\nNie używaj git add . ani git commit -n\nEOF"
expect 0 'cat > plik <<\"EOF\"\ngit add -A\nEOF'
expect 0 'cat <<EOF > plik\ngit commit -a\nEOF\ngit status'
expect 0 'cat <<-EOF\n\tgit add .\n\tEOF\ngit status'
expect 0 'git commit -m \"feat: x\n\nopis -n i -a\"'
expect 0 'git commit -m \"cytat \\\" -n\"'
expect 0 "# don't stage everything\ngit status"
expect 0 'git commit -F - <<< \"msg -n\"'
expect 2 'cat > f <<EOF\ntekst\nEOF\ngit add .'
expect 2 'git commit -n -F - <<EOF\nmsg\nEOF'
expect 2 'cat <<EOF && git add .\nx\nEOF'
expect 2 "# don't\ngit add .\necho 'x'"
expect 2 'git commit \\\n-n -m x'
expect 2 'cat <<< \"x\"\ngit add .'
expect 2 'echo $((1<<2))\ngit add .'
expect 2 'cat <<EOF\ngit add .'
expect 2 'git commit -m \"x -n'

# zakres: poza projektem SDD przepuszcza, GIT_GUARD_FORCE=1 wymusza
PROJECT="$T/plain"
expect 0 'git add .' 'projekt bez ai/docs'
expect 0 'git commit -m \"x\" --no-verify' 'projekt bez ai/docs'
export GIT_GUARD_FORCE=1
expect 2 'git add .' 'projekt bez ai/docs, GIT_GUARD_FORCE=1'
unset GIT_GUARD_FORCE
# bez CLAUDE_PROJECT_DIR decyduje bieżący katalog
code=$(cd "$T/sdd" && printf '%s' '{"tool_input":{"command":"git add ."}}' | env -u CLAUDE_PROJECT_DIR "$BASH" "$HOOK" >/dev/null 2>&1; echo $?)
if [ "$code" -eq 2 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: bez CLAUDE_PROJECT_DIR w projekcie SDD → kod $code, oczekiwano 2"; fi

echo "git-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
