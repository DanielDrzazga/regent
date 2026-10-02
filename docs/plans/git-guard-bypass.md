# Plan: git-guard-bypass

> Dwie luki w `scripts/hooks/git-guard.sh` (hook PreToolUse pluginu i tego repo), znalezione przy
> przeglądzie hooków ECC (`block-no-verify.js`). Lekka ścieżka: gałąź `fix/git-guard-bypass`, ten
> plan, bramka i smoke.

## Błąd

Sprawdzone na skrypcie z `main` (2026-10-02, `GIT_GUARD_FORCE=1`):

1. `git -c core.hooksPath=/dev/null commit -m x` przechodzi (kod 0), choć `--no-verify` jest
   blokowane. Podmiana katalogu hooków pomija pre-commit tak samo jak `--no-verify`.
2. `git commit -m "feat: x` + `Co-Authored-By: Claude <noreply@anthropic.com>"` przechodzi.
   Atrybucja AI w commicie to objaw dryfu agentów; dziś pilnuje jej tylko `attribution`
   w ustawieniach Claude Code — konfiguracja maszyny, a nie straż. Na maszynie bez tego ustawienia
   albo gdy agent dopisze stopkę sam, nic jej nie łapie.

## Decyzje

| Decyzja | Wartość |
|---|---|
| Obejście hooków | blokada `-c core.hooksPath` (z `=` i bez — sam klucz to wartość `true`) i `--config-env=core.hooksPath=…` w poleceniu `git`; klucz bez rozróżniania wielkości liter, jak w git |
| `git config core.hooksPath` | poza zakresem — odczyt jest poprawny, a odróżnienie zapisu od odczytu wzorcem grozi fałszywymi blokadami |
| Atrybucja — gdzie | polecenia tworzące treść w historii lub PR: `git commit`, `git merge`, `gh pr create`, `gh pr edit`, `gh pr merge` |
| Atrybucja — co | w surowym poleceniu (z danymi: cudzysłowy, heredoc), bez rozróżniania wielkości liter: `Co-Authored-By:` z `claude` lub `anthropic` w tej samej linii, `Generated with/by [Claude`, `noreply@anthropic.com`, link `claude.ai/code/session` |
| Atrybucja — czego nie | współautor-człowiek w `Co-Authored-By`, stopka w `echo` bez commita, `git log --grep` |
| Znane ograniczenia | hook łapie dryf, nie celowe obejście: klucz w cudzysłowie (`-c "core.hooksPath=…"`) przechodzi, jak dziś `git add "."`; komunikat z pliku (`git commit -F msg.txt`) nie jest czytany |
| Zakres | `git-guard.sh`, jego testy i opisy blokad w `skills/init/SKILL.md` (Krok 3.5) i `docs/README.md` |

## Taski

- [x] T1: testy regresji (czerwone przed poprawką): warianty `-c core.hooksPath` (wielkość liter,
  bez `=`, po `-C`, `--config-env`), stopka w `-m`, w heredocu, w `$(cat <<'EOF' … EOF)`, w `gh pr
  create --body`, link do sesji; przepuszczane: inny klucz `-c`, `git config --get core.hooksPath`,
  współautor-człowiek, `echo` stopki, `git log --grep`
- [x] T2: poprawka w `git-guard.sh`; nagłówek skryptu opisuje nowe blokady i to, że atrybucję
  sprawdza się w danych
- [x] T3: opisy blokad w `skills/init/SKILL.md` Krok 3.5 i `docs/README.md`
- [x] T4: bramka — `bash scripts/framework-lint.sh` (testy w `/bin/bash` 3.2 i bashu z PATH) +
  `claude plugin validate .`
- [x] T5: smoke w tej sesji (hook repo czyta skrypt przy każdym wywołaniu): oba polecenia z sekcji
  „Błąd” zablokowane, zwykły commit tej zmiany przechodzi
- [x] T6: merge `fix/git-guard-bypass` → `main`, push, usunięcie gałęzi

## Przebieg (2026-10-02)

- T1: 22 nowe przypadki; przed poprawką 15 czerwonych — wszystkie nowe blokady, przepuszczane
  zielone od początku.
- T2: surowe polecenie z JSON-a (`raw`) zostaje obok polecenia bez danych (`cmd`): blokada
  `core.hooksPath` patrzy na `cmd` (`grep -i`), atrybucja — na `cmd` (czy to commit, merge, gh pr)
  i `raw` (stopka). Reguły sprzed zmiany bez zmian. 72 testy zielone w bashu 3.2 i 5; awk bez zmian,
  więc bez ponownego przebiegu w gawk i mawk.
- Wydajność (pomiar): heredoc 243 KB — 1,1 s (przed zmianą 260 KB — 1,3 s).
- T4: `framework-lint.sh` — errors=0 warnings=0; `claude plugin validate .` — tylko brak `version`.
- T5: w sesji z hookiem repo zablokowane `git -c core.hooksPath=/dev/null commit --dry-run -m x`
  i `git commit --dry-run` ze stopką `Co-Authored-By: Claude` w `$(cat <<'EOF' … EOF)`; commit
  tej zmiany przeszedł.
