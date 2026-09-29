# Plan: git-guard-multiline

> Poprawka błędu w `scripts/hooks/git-guard.sh` (hook PreToolUse pluginu i tego repo). Lekka
> ścieżka: gałąź `fix/git-guard-multiline`, ten plan, bramka i smoke.

## Błąd

Hook sprawdza całe polecenie Bash jako jedną linię, więc blokuje poprawne polecenia. Dwa przypadki
z 2026-09-28 (sesja `agent-teams-view`):

1. `git commit -q -m init`, a w następnej linii `tmux new-session -d -s s -n lead` — blokada jako
   `git commit -n`. Przyczyna: przy wyciąganiu polecenia z JSON-a `\n` zamieniane jest na spację,
   a wzorzec `[^;&|]*` przechodzi wtedy z `git commit` do `-n` innego polecenia.
2. Heredoc z tekstem o `git add .` (np. `cat > plik <<'EOF'` z dokumentacją) — blokada jako
   `git add .`. Przyczyna: treść heredoca jest sprawdzana jak polecenie.

Skutek: fałszywe blokady u agentów w każdym projekcie SDD z pluginem i w tym repo
(`GIT_GUARD_FORCE=1`).

## Decyzje

| Decyzja | Wartość |
|---|---|
| Linie | `\n` z JSON-a zostaje nową linią; każda linia to osobne polecenie (grep dopasowuje linia po linii) |
| Heredoc | treść `<<SŁOWO`, `<<'SŁOWO'`, `<<"SŁOWO"`, `<<-SŁOWO` do linii zamykającej wycinana przed dopasowaniem; linia z `<<` zostaje (jest poleceniem); `<<<` to nie heredoc |
| Cudzysłowy | wycinane na całym tekście (także wielolinijkowym) automatem stanów zamiast `sed` per linia; niezamknięty cudzysłów zostaje w tekście (wolimy fałszywą blokadę niż przepuszczenie) |
| Komentarze | `#` na początku słowa poza cudzysłowem — do końca linii (np. `# don't`, który rozjechałby cudzysłowy) |
| Łamanie linii | `\` + nowa linia poza cudzysłowem skleja linie — `git commit \` + `-n` dalej blokowane |
| Zakres | tylko `git-guard.sh` i jego testy; reguły blokad bez zmian |

## Taski

- [x] T1: testy regresji (czerwone przed poprawką): oba przypadki z sesji, polecenie po zamknięciu
  heredoca, `<<` w jednej linii z blokowanym poleceniem, wielolinijkowy komunikat commita, komentarz
  z apostrofem, łamanie linii `\`, `<<<`
- [x] T2: poprawka w `git-guard.sh` (nowe linie, heredoc, cudzysłowy i komentarze, łamanie linii);
  nagłówek skryptu opisuje, co jest danymi, a co poleceniem
- [x] T3: bramka — `bash scripts/framework-lint.sh` (testy w `/bin/bash` 3.2 i bashu z PATH) +
  `claude plugin validate .`
- [x] T4: smoke w tej sesji (hook repo czyta skrypt przy każdym wywołaniu): polecenia, które
  zablokował 2026-09-28, przechodzą; `cd /nie-ma && git add .` dalej blokowane
- [x] T5: merge `fix/git-guard-multiline` → `main`, push; pamięć o obejściu do aktualizacji

## Przebieg (2026-09-29)

- T1: 18 nowych przypadków; przed poprawką 6 czerwonych — oba z sesji, `<<'EOF'`, `<<"EOF"`,
  `<<-EOF` i jedno przepuszczenie: `# don't` rozjeżdżał cudzysłowy i chował `git add .` w następnej
  linii (stara wersja przepuszczała blokowane polecenie, nie tylko blokowała poprawne).
- T2: wyciąganie z JSON-a i odcinanie danych to dwa etapy awk (`extract`, `commands_only`); reguły
  blokad bez zmian. Heredoc tylko ze słowem-identyfikatorem, więc `$((1<<2))` nie połyka dalszych
  linii. 50 testów zielonych w awk z macOS, gawk (Fedora) i mawk (Debian), w bashu 3.2 i 5.
- Wydajność (fakt z pomiaru): heredoc 260 KB — 1,3 s (stara wersja 2,95 s), 22 KB — 0,05 s.
- T3: `framework-lint.sh` — errors=0 warnings=0; `claude plugin validate .` — tylko brak `version`.
- T4: w sesji z hookiem repo przeszły `git commit` + `tmux new-session … -n lead` w następnej linii
  i heredoc z tekstem o `git add .`; `cd /nie-ma && git add .` dalej zablokowane.
