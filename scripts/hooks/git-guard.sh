#!/usr/bin/env bash
# git-guard.sh — hook PreToolUse (Bash) dla projektów SDD: barierki git egzekwowane deterministycznie.
#
# Blokuje (kod 2 — Claude Code zatrzymuje wywołanie i pokazuje agentowi komunikat z stderr):
#   git add . | ./ | :/ | -A | --all | -u   — stage całości wciąga cudze zmiany do commitu zmiany
#   git commit -a | --all                   — to samo, tylnymi drzwiami
#   --no-verify, git commit -n              — pomija hooki pre-commit, czyli bramkę testów
#
# Rejestracja: hooks/hooks.json pluginu. Zakres: projekt SDD (ai/docs/ w korzeniu projektu,
# ${CLAUDE_PROJECT_DIR} albo bieżący katalog) — poza nim hook przepuszcza wszystko.
# GIT_GUARD_FORCE=1 wymusza barierki także bez ai/docs/ (np. repo samego pluginu).
# Wejście: JSON hooka na stdin; sprawdzane jest wyłącznie pole tool_input.command.

set -u

[ -d "${CLAUDE_PROJECT_DIR:-$PWD}/ai/docs" ] || [ "${GIT_GUARD_FORCE:-}" = 1 ] || exit 0

# Wyciąga wartość pierwszego klucza "command" z JSON-a (bez jq/pythona — przenośnie).
cmd=$(awk '
  { s = s $0 "\n" }
  END {
    i = index(s, "\"command\"")
    if (!i) exit
    s = substr(s, i + 9)
    sub(/^[ \t\r\n]*:[ \t\r\n]*"/, "", s)
    out = ""; esc = 0; n = length(s)
    for (j = 1; j <= n; j++) {
      c = substr(s, j, 1)
      if (esc) { out = out ((c == "n" || c == "t") ? " " : c); esc = 0; continue }
      if (c == "\\") { esc = 1; continue }
      if (c == "\"") break
      out = out c
    }
    print out
  }')

[ -n "$cmd" ] || exit 0

# Treść w cudzysłowach (komunikat commita, echo) to dane, nie flagi — wycinamy ją przed dopasowaniem.
cmd=$(printf '%s\n' "$cmd" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")

block() {
  echo "SDD git-guard: $1" >&2
  echo "Zamiast tego: $2" >&2
  exit 2
}

# git z opcjami globalnymi: -C <katalog>, -c <klucz=wartość>
GIT='(^|[;&|(`[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'

if printf '%s\n' "$cmd" | grep -qE "${GIT}add[[:space:]]+([^;&|]*[[:space:]])?(\.|\./|:/|-[A-Za-z]*[Au][A-Za-z]*|--all|--update)([[:space:];&|)]|$)"; then
  block "git add całości (. / ./ / :/ / -A / --all / -u) wciąga do commitu pliki spoza zmiany." \
        "git add z listą konkretnych plików z raportu (np. git add src/a.ts tests/a.test.ts)."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}commit[[:space:]]+([^;&|]*[[:space:]])?(-[A-Za-z]*n[A-Za-z]*)([[:space:];&|)]|$)"; then
  block "git commit -n to --no-verify: pomija hooki pre-commit (bramkę testów i lint)." \
        "napraw przyczynę, przez którą hook nie przechodzi; commit bez testów łamie regułę SDD."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}commit[[:space:]]+([^;&|]*[[:space:]])?(-[A-Za-z]*a[A-Za-z]*|--all)([[:space:];&|)]|$)"; then
  block "git commit -a / --all stage'uje wszystkie zmodyfikowane pliki." \
        "git add z listą plików, potem git commit -m \"…\"."
fi
if printf '%s\n' "$cmd" | grep -qE "${GIT}[^;&|]*--no-verify"; then
  block "--no-verify pomija hooki pre-commit (bramkę testów i lint)." \
        "napraw przyczynę, przez którą hook nie przechodzi; commit bez testów łamie regułę SDD."
fi
exit 0
