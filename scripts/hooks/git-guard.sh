#!/usr/bin/env bash
# git-guard.sh — hook PreToolUse (Bash) dla projektów SDD: barierki git egzekwowane deterministycznie.
#
# Blokuje (kod 2 — Claude Code zatrzymuje wywołanie i pokazuje agentowi komunikat z stderr):
#   git add . | ./ | :/ | -A | --all | -u   — stage całości wciąga cudze zmiany do commitu zmiany
#   git commit -a | --all                   — to samo, tylnymi drzwiami
#   --no-verify, git commit -n              — pomija hooki pre-commit, czyli bramkę testów
#   git -c core.hooksPath… | --config-env=core.hooksPath=…  — podmienia katalog hooków: to samo co --no-verify
#   atrybucja AI w git commit | merge, gh pr create | edit | merge — Co-Authored-By z Claude/Anthropic,
#                                           „Generated with [Claude”, noreply@anthropic.com, link
#                                           claude.ai/code/session (objaw dryfu; repo nie oznacza pracy AI)
#
# Rejestracja: hooks/hooks.json pluginu. Zakres: projekt SDD (ai/docs/ w korzeniu projektu,
# ${CLAUDE_PROJECT_DIR} albo bieżący katalog) — poza nim hook przepuszcza wszystko.
# GIT_GUARD_FORCE=1 wymusza barierki także bez ai/docs/ (np. repo samego pluginu).
# Wejście: JSON hooka na stdin; sprawdzane jest wyłącznie pole tool_input.command.
#
# Polecenie a dane: każda linia to osobne polecenie (`\` na końcu linii je skleja). Danymi są
# i nie są sprawdzane: treść w cudzysłowach (także wielolinijkowa), komentarz od `#` na początku
# słowa, treść heredoca (<<SŁOWO, <<'SŁOWO', <<"SŁOWO", <<-SŁOWO) do linii zamykającej; `<<<`
# to nie heredoc. Niezamknięty cudzysłów lub heredoc zostaje w tekście — wolimy fałszywą
# blokadę niż przepuszczenie. Wyjątek: atrybucję AI sprawdza się w całym tekście, z danymi, bo
# komunikat commita i opis PR to właśnie dane; samo polecenie (commit, merge, gh pr) — bez nich.
# Hook łapie dryf, nie celowe obejście: klucz w cudzysłowie (-c "core.hooksPath=…") i komunikat
# z pliku (git commit -F plik) przechodzą.

set -u

[ -d "${CLAUDE_PROJECT_DIR:-$PWD}/ai/docs" ] || [ "${GIT_GUARD_FORCE:-}" = 1 ] || exit 0

# Wyciąga wartość pierwszego klucza "command" z JSON-a (bez jq/pythona — przenośnie);
# \n i \t z JSON-a zostają nową linią i tabulatorem.
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

# Zostawia z polecenia tylko to, co shell wykona (patrz nagłówek: polecenie a dane).
# Stany: N — polecenie, S — '…', D — "…"; hc > 0 — linie treści heredoca nr hc.
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
            # Tylko słowo-identyfikator: $((1<<2)) to nie heredoc.
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
# Klucz konfiguracji git nie rozróżnia wielkości liter (core.hookspath działa tak samo).
HOOKS_PATH='(^|[;&|(`[:space:]])git[[:space:]]([^;&|]*[[:space:]])?(-c[[:space:]]*|--config-env[=[:space:]][[:space:]]*)core\.hookspath'
if printf '%s\n' "$cmd" | grep -qiE "$HOOKS_PATH"; then
  block "-c core.hooksPath / --config-env=core.hooksPath podmienia katalog hooków, czyli pomija pre-commit jak --no-verify." \
        "napraw przyczynę, przez którą hook nie przechodzi; commit bez testów łamie regułę SDD."
fi
WRITES="${GIT}(commit|merge)([[:space:];&|)]|\$)|(^|[;&|(\`[:space:]])gh[[:space:]]+pr[[:space:]]+(create|edit|merge)([[:space:];&|)]|\$)"
ATTRIBUTION='co-authored-by:.*(claude|anthropic)|generated (with|by) \[?claude|noreply@anthropic\.com|claude\.ai/code/session'
if printf '%s\n' "$cmd" | grep -qE "$WRITES" && printf '%s\n' "$raw" | grep -qiE "$ATTRIBUTION"; then
  block "atrybucja AI w treści commita lub PR (Co-Authored-By z Claude, „Generated with Claude…”, noreply@anthropic.com, link do sesji)." \
        "usuń te linie z komunikatu; commity i PR-y nie oznaczają pracy jako napisanej przez AI."
fi
exit 0
