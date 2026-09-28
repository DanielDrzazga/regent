# ai/docs, logowanie i observability

`ai/docs/` to **jedyne źródło prawdy** o projekcie dla AI. Generuje je `/regent:init` z szablonów
w `templates/docs/`, a komendy i agenci czytają je przez Read.

## Struktura `ai/docs/`

```
ai/docs/
├── stack/
│   └── technology.md            # runtime, framework, DB, MQ, testy, porty
├── patterns/
│   ├── architecture.md          # typ, warstwy, kierunek zależności, moduły
│   ├── di-patterns.md           # (opcjonalny) wstrzykiwanie zależności
│   ├── testing-patterns.md      # (opcjonalny) piramida, mocks-first, helpers
│   ├── exception-patterns.md    # (opcjonalny) hierarchia wyjątków, handler
│   ├── logging-patterns.md      # (opcjonalny) logger: ścieżka, API, poziomy
│   └── frontend-patterns.md     # (opcjonalny) stack UI: framework, komponenty, stan, klient API
├── conventions/
│   ├── naming.md                # pliki, klasy, DB, API, log action
│   ├── code-style.md            # linter/formatter, zasady jakości
│   └── git-workflow.md          # branching, commity (1 linia, max 100 znaków)
├── domain/
│   └── glossary.md              # (opcjonalny) słownik domeny: terminy, relacje, niejednoznaczności
├── adr/                         # (opcjonalny, nie z /regent:init) ADR-y — tworzy architect
└── observability/               # (autorskie, NIE z /regent:init) dashboardy/alerty
```

Wymagane: `technology`, `architecture`, `naming`, `code-style`, `git-workflow`.
Opcjonalne (generowane jeśli wykryte): `di/testing/exception/logging/frontend-patterns`.
`frontend-patterns.md` to źródło prawdy dla agenta `regent:frontend-dev` — bez niego nie
implementuje UI (analogia do `logging-patterns.md` ↔ `/regent:logging`).

## Zasady utrzymania

- Zmiany w `ai/docs/` prowadź przez `/regent:revise` — inni agenci z nich czytają, więc zmiana
  „po cichu" rozjeżdża im kontekst.
- Szablony w `templates/docs/` to **skeletony** z placeholderami `[...]`; realia konkretnego
  projektu wypełnia `/regent:init` per projekt.

## Logowanie (`logging-patterns.md`)

Źródło prawdy dla `/regent:logging` i agenta `regent:logging-engineer`. Opisuje **istniejący** logger:
ścieżkę importu, API (`business()` / `technical()` lub natywne), poziomy (`debug`→`fatal`),
konwencję `action` (`RZECZOWNIK_CZASOWNIK`, UPPERCASE, EN), zasady bezpieczeństwa.

Twarde reguły instrumentacji:

- Tylko ID encji w `context` — **zero PII/sekretów**.
- Jeden log per operacja — nie w pętli / hot-path.
- Nie loguj w `domain/` — tylko application/infrastructure/interface.
- Nie buduj/rozszerzaj loggera — to instrumentacja, nie `LoggerModule`.

Brak pliku → `/regent:logging` pyta użytkownika (nie zgaduje ścieżki loggera).

## Observability (opcjonalnie)

Jeśli projekt utrzymuje `ai/docs/observability/` (np. dashboardy/alerty Kibany), akcje `action`
często są zaszyte na sztywno w filtrach paneli — więc **zmiana `action` cicho psuje dashboard**.

Framework egzekwuje refleksję (nie budowanie dashboardów):

- `/regent:logging` Krok 4.5 i `regent:logging-engineer` — sygnalizują dodanie/zmianę/usunięcie `action`.
- `/regent:verify` Etap 7 — warunkowa checklista z `observability/maintenance.md`.
- `logging-patterns.md` — sekcja linkująca do observability.

Typowa zawartość `observability/`: `maintenance.md` (mapa „zmiana w kodzie → co zrobić”),
`kibana-dashboard.md`, `dashboard-panels.md`, `alerts/` (definicje reguł). Tworzysz je ręcznie —
`/regent:init` ich nie generuje (są zbyt środowiskowe: index patterns, webhooki).
