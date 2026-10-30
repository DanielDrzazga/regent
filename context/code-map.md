# Regent — mapa kodu (Graphify)

> Wstrzykiwany, gdy w projekcie jest zbudowany graf: `ai/graph/graphify-out/graph.json`.

Graf **lokalizuje** pliki i zależności — treść i tak czytasz przez `Read`. Ten sam budżet,
tylko taniej trafiasz do właściwego miejsca.

## Sprawdź aktualność

```bash
find . -newer ai/graph/graphify-out/graph.json -not -path './ai/*' -not -path './.git/*' \
  -not -path './node_modules/*' -type f 2>/dev/null | head -1
```

Wynik niepusty (albo błąd CLI) → graf nieaktualny. Pracuj jak dotąd (Grep/Glob) i dopisz
w raporcie jedną linię: „graf nieaktualny — `graphify extract . --code-only --out ai/graph`
(sesja główna)".

## Polecenia (gdy graf jest aktualny)

```bash
graphify path "ModułA" "ModułB" --graph ai/graph/graphify-out/graph.json    # ścieżka A → B
graphify explain "Nazwa" --graph ai/graph/graphify-out/graph.json          # kto woła X / kogo woła X
graphify affected "Nazwa" --graph ai/graph/graphify-out/graph.json         # co zależy od X (wpływ zmiany)
```

Wynik wskazuje plik i linię (`source_file`, `source_location`) — czytaj je przez `Read`.
Nazwa nierozpoznana albo niejednoznaczna (kod wyjścia 4 albo 3) → wróć do Grep/Glob dla tego
jednego zapytania, resztę pracy prowadź dalej przez graf.

## Barierki

- Graf buduje i aktualizuje **tylko sesja główna albo użytkownik**
  (`graphify extract <ścieżka> --code-only --out ai/graph`) — subagent, nawet gdy zauważy
  nieaktualny graf, nie uruchamia Graphify ani go nie aktualizuje.
- `graphify cluster-only` i `graphify label` bez `--no-label` próbują nazwać społeczności przez
  LLM (nawet przez lokalne `claude -p`, gdy nie ma klucza API) — Regent ich nie wywołuje; graf ma
  numeryczne społeczności (`community`), to wystarczy do lokalizowania.
