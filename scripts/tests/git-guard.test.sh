#!/usr/bin/env bash
# Testy scripts/hooks/git-guard.sh — JSON hooka PreToolUse na stdin, oczekiwany kod wyjścia.
# Użycie: bash scripts/tests/git-guard.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/../hooks/git-guard.sh"
pass=0
fail=0

# expect <kod> <komenda> [description]
expect() {
  json=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"%s"}}' "$2" "${3:-}")
  printf '%s' "$json" | "$BASH" "$HOOK" >/dev/null 2>&1
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

echo "git-guard tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
