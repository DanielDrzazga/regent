# Git Workflow

> Wypełnij na podstawie historii git i konfiguracji wykrytych przez `/regent:init`.

## Branching

| Element | Wartość |
|---------|---------|
| Model | [trunk-based / gitflow] |
| Gałąź główna | [main / master] |
| Format brancha | `<type>/<KEY>-<short-description>` |

Przykłady: `feat/PROJ-123-user-registration`, `fix/PROJ-124-duplicate-email`, `hotfix/2025-03-20-payment-500`.

## Commity (Conventional Commits)

**Format:** `<type>: (<KEY>) <opis, imperatyw>`

**Limity:** cała linia **max 100 znaków**, **jedna linia — bez body**. Długi opis = commit za duży → rozbij.

| Type | Zastosowanie |
|------|--------------|
| feat | Nowa funkcjonalność |
| fix | Naprawa buga |
| refactor | Refactoring (bez zmiany zachowania) |
| test | Testy |
| chore | Zależności, konfiguracja, CI |
| docs | Dokumentacja |
| perf | Wydajność |

Przykład: `feat: (PROJ-123) add global error handling middleware`

## Zasady

- Atomic commits — 1 commit = 1 logiczna zmiana.
- Wiadomość commita: **jedna linia, max 100 znaków, bez body**.
- **NIGDY** `git add .` / `git add -A` — zawsze konkretne pliki.
- **NIGDY** commit bez przejścia testów; **NIGDY** `--no-verify`.
- `git push` tylko na wyraźną prośbę.
- Klucz zadania (Jira/inny) w każdym commicie; jeśli brak → `NONE`.

## Pull Requests / Merge

- [Strategia — np. squash / merge commit]
- [Wymagane review / CI green przed merge]
- `ai/` jest osobisty i globalnie ignorowany — do MR trafia kod i testy, a plan (cel, wymagania
  z AC, decyzje) niesie opis MR generowany w `/regent:verify` Etap 9. Reviewer czyta najpierw opis
  (czy plan jest dobry), potem kod (czy go realizuje).
- `/regent:archive` po merge MR — twoje `ai/specs/` rośnie tylko o kod, który wszedł.
- Temat commita squash zawiera klucz ticketu (`feat: (KEY) …`) — po nim `sdd-check stale`
  rozpoznaje pracę z cyklu SDD.
