# Getting Started

Pierwsze uruchomienie frameworka w projekcie — krok po kroku.

## 0. Warunek wstępny

Plugin `regent` musi być zainstalowany (patrz [README → Użycie](../README.md#użycie)). Sprawdź,
że Claude Code go widzi: wpisz `/regent:` i Tab — lista powinna pokazać `/regent:init`,
`/regent:propose`, `/regent:apply` i resztę skilli.

> **`ai/` jest osobisty.** Wszystko, co framework tworzy w `ai/`, to Twój warsztat — katalog jest
> globalnie ignorowany (`/regent:init` Krok 0.5 sprawdzi to i zaproponuje wpis `/ai/`). Do repo
> produktu trafia kod, testy i `Makefile`; plan zmiany niesie opis MR z `/regent:verify`.

## 1. `/regent:init` — skonfiguruj projekt

W katalogu projektu:

```text
/regent:init            # auto-detekcja (--detect); alternatywnie /regent:init --manual
```

`/regent:init`:

- skanuje repo (package.json, tsconfig, eslint, docker, struktura, git log),
- generuje `ai/docs/` z szablonów (`templates/docs/`) wypełnionych realiami projektu,
- generuje `Makefile` (cele `test`, `lint`, `type-check`, `check`, ...),
- prezentuje wynik **do zatwierdzenia** — nic nie zapisuje bez `tak`.

Wygenerowane (wymagane): `stack/technology.md`, `patterns/architecture.md`,
`conventions/{naming,code-style,git-workflow}.md`. Opcjonalne (jeśli wykryto):
`patterns/{di,testing,exception,logging}-patterns.md`, `patterns/frontend-patterns.md`
(gdy projekt ma frontend).

> `ai/docs/observability/` **nie** jest generowane (zbyt środowiskowe) — tworzysz je ręcznie,
> jeśli utrzymujesz dashboardy/alerty.

## 2. `/regent:status` — sprawdź stan

```text
/regent:status
```

Pokaże, które pliki `ai/docs/` są wypełnione, aktywne zmiany, archiwum i sugestie.

## 3. Pierwsza zmiana: `/regent:propose`

```text
/regent:propose user-registration
```

1. **Wywiad** — jedna runda: problem, zachowanie, zakres, ograniczenia.
2. **Challenge** — agent sam ustala fakty w kodzie, a Ciebie pyta tylko o decyzje, rundami
   (do 4 pytań naraz, z rekomendacją). Większość małych zmian przechodzi od razu (`AKCEPTUJĘ`).
3. **Artefakty** w `ai/changes/user-registration/`: `proposal.md` (z logiem Decyzje i założenia),
   `specs/*.md` (delta z AC), `design.md`, `tasks.md` (każdy task wskazuje swoje AC).
4. **Kontrola spójności** i zapis jako `Draft` — czytasz pełne pliki z checklistą recenzenta.
5. `zatwierdzam` → `Approved` (dopiero wtedy `/regent:apply` ruszy) albo `popraw: ...`.

> **Istniejący projekt bez specyfikacji:** `ai/specs/` rośnie zmiana po zmianie — `/regent:init`
> celowo go nie generuje i nie opisujesz starego kodu na zapas. Pierwsza zmiana, która dotyka
> nieopisanego zachowania, dodaje je do delty jako ADDED („pierwsza specyfikacja istniejącego
> zachowania").

## 4. Implementacja: `/regent:apply`

```text
/regent:apply user-registration
```

TDD per task: 🔴 test → 🟢 kod → 🔵 refactor. Implementuje `regent:backend-dev` lub `regent:frontend-dev`
wg tagu taska (`[BE]`/`[FE]`); agent sam uruchamia testy (wąsko, per moduł/komponent);
atomic commit per task robi sesja główna po potwierdzonym GREEN.

## 5. Weryfikacja: `/regent:verify`

```text
/regent:verify user-registration
```

9 etapów (5-8 warunkowe). Wynik ląduje w `ai/changes/{nazwa}/verification.md`.
PASS → można archiwizować; FAIL → fix przez `/regent:apply`, re-run oblanych etapów.

## 6. Zamknięcie: `/regent:archive`

```text
/regent:archive user-registration
```

Merguje delta-specs do `ai/specs/` i przenosi zmianę do `ai/changes/archive/`.

## Dalej

- Barierki git w istniejącym projekcie SDD (hook `git-guard`): wpis z `/regent:init` Krok 3.5
  dodaj do `.claude/settings.json` projektu.
- Stan zmian liczony skryptem: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh status`
  (wszystkie tryby: [`sdd-check.md`](sdd-check.md)).
- Instrumentacja logami: `/regent:logging <ścieżka>` (wymaga `ai/docs/patterns/logging-patterns.md`).
- Analiza bez zmian: `/regent:explore <temat>`.
- Szczegóły cyklu: [`workflow.md`](workflow.md).
