# Plan: wiki-sync-edit

> Poprawka Kroku 5 (`sync`) w `skills/wiki/SKILL.md`. Lekka ścieżka: gałąź `fix/wiki-sync-edit`,
> ten plan, bramka i smoke.

## Kontekst

Pętla `/regent:optimize wiki` (tag `wiki-2026-10-24`, w `main` jako merge `perf/optimize-wiki-2026-10-24`)
skończyła się odrzuceniem przez holdout: `holdout-sync` 0,87. Powtórka ×3 dała 0,867 po pętli
i 0,80 na stanie sprzed pętli, więc błąd był w skillu wcześniej. Ślady pokazały dwie przyczyny:

1. Model zapisuje `last-sync-sha` i wpis w `log.md` przez `sed -i` albo `>>` w Bashu. Sandbox Basha
   daje `Read-only file system`, a model zamiast przejść na `Edit` kończy turę bez zapisu.
2. „Po akceptacji” bez wskazania narzędzia: model kończy turę pytaniem w tekście i nic nie zapisuje.
   Gdy akceptacja przejdzie, ostatnia wiadomość to samo potwierdzenie zapisu, bez `ingest`.

## Zmiana

Krok 5, zdanie „Po akceptacji”:
- akceptacja w tej samej turze przez `AskUserQuestion`;
- kotwica i log przez `Edit`, nie Bash;
- wiadomość końcowa powtarza strony do przejrzenia i `ingest`.

## Checklista

- [x] Zmiana w `skills/wiki/SKILL.md`
- [x] Sprawdzian `holdout-sync` ×3 po każdej części poprawki:
  - samo `Edit`: 0,867 (bez `sed -i`, jeden przebieg kończy się pytaniem w tekście);
  - z `AskUserQuestion`: 0,93 (kotwica i log 3/3, `proponuje-ingest` 2/3);
  - z wiadomością końcową: 1,00 (3/3)
- [x] Bramka: `bash scripts/framework-lint.sh`, `claude plugin validate .`
- [x] Smoke: `holdout-sync` ×3 i `train-lint` ×1 na gałęzi
- [x] Merge do `main` razem z wynikiem pętli, push (2026-10-30)
