# Plan: plugin-hooks

> Zmiana 2 z 3 migracji (`plugin-import` → `plugin-hooks` → `retire-home-sdd`). Lekka ścieżka:
> gałąź `feat/plugin-hooks`, ten plan, bramka i smoke. Mechanikę robi sesja główna, bez subagentów.

## Cel

Plugin `regent` sam dostarcza to, co dziś daje `~/.claude`: reguły SDD i rolę partnera w kontekście
sesji i subagentów, barierkę git-guard oraz statusline — bez ręcznych wpisów wskazujących
`~/.claude`. Plugin jest włączony tylko w projektach testowych; włączenie globalne i usunięcie
starego frameworka robi zmiana 3.

## Decyzje (2026-09-28)

| Decyzja | Wartość |
|---|---|
| Kontekst | `context/role.md` zawsze, `context/sdd.md` tylko w projektach z `ai/docs/` — w sesji (`SessionStart`) i w subagentach (`SubagentStart`), z pominięciem `Explore` i `Plan` (jak dziś z `CLAUDE.md`) |
| git-guard | tylko projekty SDD: skrypt działa, gdy `${CLAUDE_PROJECT_DIR}/ai/docs/` istnieje; poza nim przepuszcza. `GIT_GUARD_FORCE=1` wymusza (repo `regent` nie ma `ai/`) |
| Statusline | `SessionStart` kopiuje `statusline.sh` i `session-tokens.sh` do `${CLAUDE_PLUGIN_DATA}/bin/` (stała ścieżka, przetrwa aktualizacje); `statusLine` w `~/.claude/settings.json` przełącza zmiana 3 |
| Instalacja | tylko projekty testowe z lokalnego marketplace; globalnie — zmiana 3 (bez okna z podwójnym kontekstem) |

## Taski

- [ ] T1: smoke odłożony z `plugin-import` — pusty repo testowy, `claude -p … --plugin-dir`:
  - `/regent:status` ładuje się, `sdd-check.sh` rusza przez `${CLAUDE_PLUGIN_ROOT}`;
  - lista agentów zawiera 9 × `regent:<agent>`;
  - jedna delegacja do `regent:<agent>` — tylko za zgodą (agent na Opusie kosztuje)
- [ ] T2: `scripts/hooks/session-context.sh` + `scripts/tests/session-context.test.sh`:
  - `SessionStart` → zwykły stdout: `role.md`, a przy `ai/docs/` także `sdd.md`;
  - `SubagentStart` → JSON `hookSpecificOutput.additionalContext` (escaping w awk, bez jq);
    `agent_type` `Explore` / `Plan` → nic
- [ ] T3: `scripts/hooks/sync-bin.sh` — kopiuje `statusline.sh` i `session-tokens.sh` do
  `${CLAUDE_PLUGIN_DATA}/bin/`, tylko gdy się różnią; test w `scripts/tests/`
- [ ] T4: git-guard — zakres: `ai/docs/` w `${CLAUDE_PROJECT_DIR:-$PWD}` albo `GIT_GUARD_FORCE=1`;
  nowe przypadki w `git-guard.test.sh` (projekt SDD blokuje, projekt bez SDD przepuszcza, force blokuje)
- [ ] T5: `hooks/hooks.json` — `SessionStart` (session-context, sync-bin), `SubagentStart`
  (session-context), `PreToolUse` z matcherem `Bash` (git-guard); lint: każda ścieżka
  `${CLAUDE_PLUGIN_ROOT}/…` z `hooks.json` istnieje
- [ ] T6: `statusline.sh` — `stat -f '%z'` (tylko BSD) → `wc -c`, shebang `#!/usr/bin/env bash`;
  `scripts/tests/statusline.test.sh` (fixture JSON + transkrypt → linia z modelem i tokenami)
- [ ] T7: `/regent:init` Krok 3.5 — zamiast wpisu hooka w projekcie: informacja, że git-guard
  rejestruje plugin i działa przy `ai/docs/`; regresja w lincie: `skills/init/SKILL.md` bez
  `$HOME/.claude/scripts/hooks/git-guard.sh`
- [ ] T8: repo `regent` — git-guard z `GIT_GUARD_FORCE=1` w śledzonym `.claude/settings.json`
  (`$CLAUDE_PROJECT_DIR/scripts/hooks/git-guard.sh`), usunięcie wpisu z `.claude/settings.local.json`
- [ ] T9: dokumentacja — `docs/statusline.md` (ustawienie `statusLine` na ścieżkę z `${CLAUDE_PLUGIN_DATA}`),
  README (hooki pluginu), `docs/README.md` (nowe skrypty)
- [ ] T10: bramka — `bash scripts/framework-lint.sh` w obu bashach + `claude plugin validate .`
- [ ] T11: instalacja testowa — lokalny marketplace z katalogu repo, plugin w zakresie `local`
  dwóch projektów testowych (z `ai/docs/` i bez); `claude -p` sprawdza: kontekst `role.md` w obu,
  `sdd.md` tylko w SDD, git-guard blokuje `git add .` tylko w SDD, `bin/statusline.sh` w danych pluginu
- [ ] T12: merge `feat/plugin-hooks` → `main`, push

## Poza zakresem (zmiana 3: `retire-home-sdd`)

Włączenie pluginu w zakresie `user` na każdej maszynie (w tym Fedora), usunięcie SDD z `~/.claude`
(agents, commands, templates, scripts, reguły SDD i „Twoja rola" z `CLAUDE.md`), przełączenie
`statusLine`, sprzątanie wpisów git-guard wskazujących `$HOME/.claude/…` w projektach,
zamrożenie `claude-sdd-framework` z odnośnikiem, decyzja o `disable-model-invocation` dla skilli.

## Ryzyka

- **Podwójny kontekst w projektach testowych** — tam stary `CLAUDE.md` i hook pluginu wstrzykują
  te same reguły; akceptowalne, bo tylko w testach (T11).
- **JSON bez jq** — escaping `role.md` + `sdd.md` (cudzysłowy, backslashe, taby, nowe linie)
  w awk; test sprawdza poprawność (parser JSON, gdy dostępny).
- **Koszt kontekstu subagentów** — ok. 200 linii w każdym subagencie; tyle samo co dziś
  z `CLAUDE.md`, więc bez zmiany kosztu.
- **Zakres git-guard** — przy `ai/docs/` w podkatalogu (monorepo) skrypt patrzy na korzeń projektu
  (`CLAUDE_PROJECT_DIR`), jak `/regent:init`.
