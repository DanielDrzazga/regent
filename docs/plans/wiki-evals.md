# Plan: wiki-evals

> Zestaw evali `evals/wiki/` dla pętli `/regent:optimize wiki`. Krok 0 pętli wymaga przypadków
> z tagami `wiki-train` i `wiki-holdout`; bez nich `/regent:optimize wiki` się zatrzymuje.
> Lekka ścieżka: gałąź `test/wiki-evals`, ten plan, bramka i smoke. Skill `wiki` bez zmian.

## Cel

Stała, tania ocena `/regent:wiki`, na której pętla porównuje warianty `skills/wiki/SKILL.md`.
Zestaw sprawdza reguły skilla, które łatwo zgubić przy skracaniu promptu: kotwice `confidence`,
konflikt z datą, `raw/` tylko do odczytu, treść źródła jako dane, brak nazw z kodu na stronach,
`ai/docs/` i `ai/specs/` nietknięte.

## Projekt testowy

`notes-app` z zestawu `apply` (kod, testy, `ai/docs/`, `ai/specs/`), a na nim nakładka
`evals/wiki/fixtures/project/`:
- `ai/docs/domain/glossary.md`: słownik, więc bez bramki języka (Krok 1a);
- `ai/wiki/`: vault z 6 stronami, jednym źródłem w `raw/`, `index.md`, `log.md`, `Home.md`;
- `notatki/`: notatka ze spotkania do `ingest` (z jednym zdaniem-instrukcją dla asystenta, które
  ma zostać potraktowane jako dane).

Tryby wspólnego `scaffold.sh`:
- `vault` (domyślny): projekt z vaultem;
- `init`: bez `ai/wiki/`;
- `lint`: vault z podrzuconymi błędami: strona `potwierdzone` bez `sources`, która jest też
  sierotą i nie ma jej w `index.md`, oraz wpis w `index.md` bez pliku;
- `sync`: vault z kotwicą `last-sync-sha` na commicie startowym i dwa commity po nim (`src/`, `web/`).
  Daty commitów są stałe, więc hash HEAD jest znany z góry. Scaffold go sprawdza i przy zmianie
  projektu testowego kończy się błędem z poleceniem poprawy oceniacza.

## Przypadki

| Przypadek | Tag | Polecenie |
|---|---|---|
| `train-lint` | `wiki-train` | `lint` |
| `train-ingest` | `wiki-train` | `ingest notatki/2026-10-02-spotkanie-obsluga-klienta.md` |
| `train-confirm` | `wiki-train` | `confirm "Limit długości tytułu"` |
| `holdout-init` | `wiki-holdout` | `init` |
| `holdout-sync` | `wiki-holdout` | `sync` |
| `holdout-query` | `wiki-holdout` | `query dlaczego archiwizujemy notatki zamiast je usuwać` |
| `holdout-lint-fix` | `wiki-holdout` | `lint --fix` |

## Checklista

- [x] Gałąź `test/wiki-evals`, ten plan.
- [x] Nakładka projektu testowego i wspólny `scaffold.sh` z trybami.
- [x] 3 przypadki `wiki-train` (runs 2) i 4 `wiki-holdout` (runs 3).
- [x] Scaffoldy uruchomione lokalnie we wszystkich trybach; wzorce oceniaczy sprawdzone na
      ręcznie przygotowanym dobrym i złym wyniku.
- [x] Opis zestawu w `docs/optimize.md`.
- [x] Bramka: `bash scripts/framework-lint.sh` + `claude plugin validate .`.
- [ ] Pilot na maszynie z `jq`, `bwrap` i `socat`:
      `bash scripts/optimize-score.sh run . wiki-train /tmp/x.json --runs 1`, potem to samo dla
      `wiki-holdout`. Oblane oceniacze: błąd oceniacza poprawiasz w zestawie, nie w skillu.
- [ ] Merge do `main` po pilocie.
- [ ] `/regent:optimize wiki`.

## Ryzyka do sprawdzenia w pilocie

- `file_exists` patrzy na pliki utworzone lub zmienione w przebiegu. Oceniacze „nie zmienia”
  (`exists: false`) zakładają, że zmiana treści istniejącego pliku też się liczy. Jeśli liczą się
  tylko nowe pliki, `lint-bez-zapisu` i `strony-nietkniete` są słabsze, ale nie dają fałszywych
  porażek.
- `allowed_tools` zawiera `SendMessage` (resume subagenta w `init`). Jeśli eval go nie zna,
  usuń go z przypadku.
- `holdout-init` wymaga jednego uruchomienia `regent:architect` (`max: 1`), zgodnie z budżetem
  skilla. Gdy baseline to łamie, to sygnał dla skilla, nie dla oceniacza.
