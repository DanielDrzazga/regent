#!/usr/bin/env bash
# git-guard.sh — PreToolUse (Bash) hook for SDD projects: git guardrails enforced deterministically.
#
# Blocks (code 2 — Claude Code stops the call and shows the agent the stderr message):
#   git add . | ./ | :/ | -A | --all | -u   — staging everything pulls foreign changes into the change's commit
#   git commit -a | --all                   — the same, through the back door
#   --no-verify, git commit -n              — skips pre-commit hooks, i.e. the test gate
#   git -c core.hooksPath… | --config-env=core.hooksPath=…  — swaps the hooks directory: same as --no-verify
#   AI attribution in git commit | merge, gh pr create | edit | merge — Co-Authored-By with Claude/Anthropic,
#                                           "Generated with [Claude", noreply@anthropic.com, a
#                                           claude.ai/code/session link (drift symptom; the repo does not mark AI work)
#
# Registration: the plugin's hooks/hooks.json. Scope: SDD project (ai/docs/ in the project root,
# ${CLAUDE_PROJECT_DIR} or the current directory) — outside it the hook lets everything through.
# GIT_GUARD_FORCE=1 enforces the guardrails without ai/docs/ too (e.g. the plugin's own repo).
# Input: hook JSON on stdin; only the tool_input.command field is checked.
#
# Command vs data: each line is a separate command (`\` at the end of a line joins them). Data,
# not checked: quoted text (multi-line too), a comment from `#` at the start of a word, heredoc
# body (<<WORD, <<'WORD', <<"WORD", <<-WORD) up to the closing line; `<<<` is not a heredoc.
# An unclosed quote or heredoc stays in the text — a false block beats letting it through.
# Exception: AI attribution is checked in the whole text, data included, because the commit
# message and PR description are data; the command itself (commit, merge, gh pr) — without it.
# The hook catches drift, not deliberate bypass: a quoted key (-c "core.hooksPath=…") and a
# message from a file (git commit -F file) pass.

set -u

[ -d "${CLAUDE_PROJECT_DIR:-$PWD}/ai/docs" ] || [ "${GIT_GUARD_FORCE:-}" = 1 ] || exit 0

# Extracts the value of the first "command" key from the JSON (no jq/python — portable);
# JSON \n and \t become a newline and a tab.
extract() {
  awk '
    { s = s $0 "\n" }
    END {
      i = index(s, "\"command\"")
      if (!i) exit
      s = substr(s, i + 9)
      sub(/^[ \t\r\n]*:[ \t\r\n]*"/, "", s)
      esc = 0; n = length(s)
      for (j = 1; j <= n; j++) {
        c = substr(s, j, 1)
        if (esc) { printf "%s", (c == "n") ? "\n" : (c == "t") ? "\t" : (c == "r") ? "" : c; esc = 0; continue }
        if (c == "\\") { esc = 1; continue }
        if (c == "\"") break
        printf "%s", c
      }
      print ""
    }'
}

# Keeps only what the shell executes (see header: command vs data).
# States: N — command, S — '…', D — "…"; hc > 0 — body lines of heredoc no. hc.
commands_only() {
  awk '
    { L[NR] = $0 }
    END {
      st = "N"; nh = 0; hc = 0
      for (r = 1; r <= NR; r++) {
        line = L[r]
        if (hc) {
          t = line
          if (hs[hc]) sub(/^\t+/, "", t)
          if (t == hd[hc] && ++hc > nh) { hc = 0; nh = 0 }
          continue
        }
        n = length(line); cont = 0
        for (j = 1; j <= n; j++) {
          c = substr(line, j, 1)
          if (st == "S") { if (c == "\047") st = "N"; continue }
          if (st == "D") { if (c == "\\") j++; else if (c == "\"") st = "N"; continue }
          if (c == "\\") { if (j == n) cont = 1; else printf "%s", substr(line, ++j, 1); continue }
          if (c == "\047" || c == "\"") { st = (c == "\"") ? "D" : "S"; sr = r; sc = j; continue }
          if (c == "#" && (j == 1 || index(" \t;&|()", substr(line, j - 1, 1)))) break
          if (substr(line, j, 3) == "<<<") { printf "<<<"; j += 2; continue }
          if (substr(line, j, 2) == "<<") {
            k = j + 2; strip = 0; w = ""
            if (substr(line, k, 1) == "-") { strip = 1; k++ }
            while (k <= n && index(" \t", substr(line, k, 1))) k++
            q = substr(line, k, 1)
            if (q == "\047" || q == "\"") {
              e = index(substr(line, k + 1), q)
              if (e) { w = substr(line, k + 1, e - 1); k += e + 1 }
            } else {
              while (k <= n && substr(line, k, 1) ~ /[A-Za-z0-9_]/) { w = w substr(line, k, 1); k++ }
            }
            # Identifier word only: $((1<<2)) is not a heredoc.
            if (w ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { hd[++nh] = w; hs[nh] = strip; printf "<<%s", w; j = k - 1; continue }
          }
          printf "%s", c
        }
        if (st != "N" || cont) continue
        print ""
        if (nh) { hc = 1; hr = r + 1 }
      }
      if (st != "N") {
        printf "%s\n", substr(L[sr], sc)
        for (r = sr + 1; r <= NR; r++) print L[r]
      } else if (hc) {
        for (r = hr; r <= NR; r++) print L[r]
      }
    }'
}

raw=$(extract)
cmd=$(printf '%s\n' "$raw" | commands_only)

[ -n "$cmd" ] || exit 0

block() {
  echo "SDD git-guard: $1" >&2
  echo "Instead: $2" >&2
  exit 2
}

# git with global options: -C <dir>, -c <key=value>
GIT='(^|[;&|(`[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'

if printf '%s\n' "$cmd" | grep -qE "${GIT}add[[:space:]]+([^;&|]*[[:space:]])?(\.|\./|:/|-[A-Za-z]*[Au][A-Za-z]*|--all|--update)([[:space:];&|)]|$)"; then
  block "git add of everything (. / ./ / :/ / -A / --all / -u) pulls files outside the change into the commit." \
        "git add with a list of specific files from the report (e.g. git add src/a.ts tests/a.test.ts)."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}commit[[:space:]]+([^;&|]*[[:space:]])?(-[A-Za-z]*n[A-Za-z]*)([[:space:];&|)]|$)"; then
  block "git commit -n is --no-verify: skips pre-commit hooks (the test and lint gate)." \
        "fix the reason the hook fails; a commit without tests breaks the SDD rule."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}commit[[:space:]]+([^;&|]*[[:space:]])?(-[A-Za-z]*a[A-Za-z]*|--all)([[:space:];&|)]|$)"; then
  block "git commit -a / --all stages all modified files." \
        "git add with a list of files, then git commit -m \"…\"."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}[^;&|]*--no-verify"; then
  block "--no-verify skips pre-commit hooks (the test and lint gate)." \
        "fix the reason the hook fails; a commit without tests breaks the SDD rule."
fi
# Git config keys are case-insensitive (core.hookspath works the same).
HOOKS_PATH='(^|[;&|(`[:space:]])git[[:space:]]([^;&|]*[[:space:]])?(-c[[:space:]]*|--config-env[=[:space:]][[:space:]]*)core\.hookspath'
if printf '%s\n' "$cmd" | grep -qiE "$HOOKS_PATH"; then
  block "-c core.hooksPath / --config-env=core.hooksPath swaps the hooks directory, i.e. skips pre-commit like --no-verify." \
        "fix the reason the hook fails; a commit without tests breaks the SDD rule."
fi
WRITES="${GIT}(commit|merge)([[:space:];&|)]|\$)|(^|[;&|(\`[:space:]])gh[[:space:]]+pr[[:space:]]+(create|edit|merge)([[:space:];&|)]|\$)"
ATTRIBUTION='co-authored-by:.*(claude|anthropic)|generated (with|by) \[?claude|noreply@anthropic\.com|claude\.ai/code/session'
if printf '%s\n' "$cmd" | grep -qE "$WRITES" && printf '%s\n' "$raw" | grep -qiE "$ATTRIBUTION"; then
  block "AI attribution in the commit or PR text (Co-Authored-By with Claude, \"Generated with Claude…\", noreply@anthropic.com, session link)." \
        "remove these lines from the message; commits and PRs do not mark work as written by AI."
fi
exit 0
