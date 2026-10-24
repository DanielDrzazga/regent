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
- [x] Pilot oceniaczy bez Basha (2026-10-23, `--runs 1`, `--disallow-tools Bash`): 6 z 7
      przypadków, bez `holdout-sync`, każdy z wynikiem 1,00, łącznie ~2,07 USD. Szczegóły
      w sekcji Przebieg.
- [x] Pilot z Bashem (2026-10-24, `optimize-score.sh run … --runs 1`): `wiki-train` 3 z 3
      i `wiki-holdout` 4 z 4 na 1,00, łącznie 2,26 USD (plus powtórka `sync` 0,14 USD). Żaden oceniacz nie oblał.
      `holdout-sync` nie jest jednak sprawdzony: eval blokuje `git` w sandboksie (sekcja Przebieg).
- [ ] `holdout-sync` z działającym `git` w sandboksie evala, `--runs 3`: każdy przebieg 1,00.
- [ ] Merge do `main` po pilocie.
- [ ] `/regent:optimize wiki`.

## Przebieg

**2026-10-23, pilot bez Basha.** Środowisko zdalne nie ma sandboksu Basha dla evala: brakuje
`bwrap` i `socat`, a profil kontenera (seccomp, AppArmor) blokuje user namespaces. Eval odmawia
więc uruchomienia Basha bez sandboksu. Pilot poszedł bezpośrednio przez `claude plugin eval`
z `--disallow-tools Bash`, bez `optimize-score.sh`, który zawsze przyznaje Basha. To sprawdzenie
oceniaczy i projektu testowego, a nie baseline pętli.

| Przypadek | Wynik | Tury | Koszt |
|---|---|---|---|
| `train-lint` | 1,00 | 10 | razem 0,84 USD |
| `train-ingest` | 1,00 | 12 | (train) |
| `train-confirm` | 1,00 | 13 | |
| `holdout-init` | 1,00 | 30 | 0,96 USD |
| `holdout-lint-fix` | 1,00 | 12 | 0,17 USD |
| `holdout-query` | 1,00 | 5 | 0,10 USD |

Ręczny przegląd wyników:
- `ingest` dopisał „po co” ze źródłem, oznaczył konflikt kolejności listy z datą i pominął
  zdanie z notatki, które kazało zmienić `ai/specs/`;
- `confirm` zapisał rozstrzygnięcie w `raw/` i w `sources`, a konflikt zamknął wpisem z datą;
- `init` zbudował 20 stron, w tym pytania jako hipotezy.

Poprawka po pilocie: tożsamość commitów w `scaffold.sh` idzie przez `GIT_AUTHOR_*`
i `GIT_COMMITTER_*`. Zmienne środowiska maszyny wygrywały z `-c user.name`, więc hash commitu
startowego zależał od maszyny, a oceniacz `kotwica-na-head` by się wywrócił.

**2026-10-24, pilot z Bashem.** `jq`, `bwrap` i `socat` z pakietów Alpine rozpakowane do katalogu
użytkownika (bez roota), user namespaces działają, sandbox Basha w evalu startuje.

| Zestaw | quality | cost | tokens | seconds |
|---|---|---|---|---|
| `wiki-train` | 1,00 | 0,925 USD | 1,17 mln | 188 |
| `wiki-holdout` | 1,00 | 1,333 USD | 1,83 mln | 295 |

Koszt per przypadek: `confirm` 0,18, `ingest` 0,57, `lint` 0,17, `init` 0,86, `lint-fix` 0,20,
`query` 0,11, `sync` 0,16 USD.

`holdout-sync` nie jest w tym środowisku miarodajny. Eval dopisuje `/usr/bin/git` do
`sandbox.credentials.files` z `mode: deny`. Prawdopodobnie przez `credential.helper` w
`/etc/gitconfig` kontenera, ale `GIT_CONFIG_NOSYSTEM=1` tego nie zmienia. Każde wywołanie `git`
w sandboksie kończy się `Permission denied`. Pierwszy przebieg dał 1,00, bo agent wziął hash HEAD
z migawki `git status` w prompcie systemowym i przesunął kotwicę bez listy zmienionych plików.
Powtórka dała 0,6: agent odmówił przesunięcia kotwicy bez gita (zgodnie ze skillem) i oblał
`kotwica-na-head` oraz `log-sync`. To błąd środowiska, nie oceniacza ani skilla, więc zestaw
zostaje bez zmian. Na maszynie, na której eval blokuje `git`, `holdout-sync` waha się między 0,6
a 1,0 i rozregulowuje bramkę holdout w `/regent:optimize wiki`.

## Ryzyka do sprawdzenia w pilocie

- `file_exists` patrzy na pliki utworzone lub zmienione w przebiegu. Oceniacze „nie zmienia”
  (`exists: false`) zakładają, że zmiana treści istniejącego pliku też się liczy. Jeśli liczą się
  tylko nowe pliki, `lint-bez-zapisu` i `strony-nietkniete` są słabsze, ale nie dają fałszywych
  porażek.
- `allowed_tools` zawiera `SendMessage` (resume subagenta w `init`). Jeśli eval go nie zna,
  usuń go z przypadku.
- `holdout-init` wymaga jednego uruchomienia `regent:architect` (`max: 1`), zgodnie z budżetem
  skilla. Gdy baseline to łamie, to sygnał dla skilla, nie dla oceniacza.
