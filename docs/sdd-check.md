# sdd-check — deterministyczna walidacja artefaktów

`scripts/sdd-check.sh` sprawdza artefakty SDD w projekcie **skryptem, nie modelem**. Liczenie
checkboxów, porównywanie numerów REQ i zbiorów AC to praca, w której model się myli i płaci
za nią tokenami — skrypt robi ją powtarzalnie w ułamku sekundy.

Skrypt jest **read-only**: niczego nie zapisuje, tylko raportuje. Wołają go komendy frameworka
w bramkach; możesz uruchomić go też sam, w katalogu głównym projektu:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh <tryb> [argumenty]
```

## Tryby

| Tryb | Co sprawdza | Kto woła |
|------|-------------|----------|
| `change <nazwa>` | Status w proposal.md; delta: tylko sekcje ADDED/MODIFIED/REMOVED/INVARIANTS/Notes, każdy REQ ma AC, REMOVED ma Powód, brak placeholderów, refactor ma INV; tasks: checkboxy, ID, odwołania REQ/AC, `weryfikacja:`, pokrycie każdego AC taskiem | `/regent:propose` 3a, `/regent:apply` Krok 0 i 4.5, `/regent:verify` Krok 0, `/regent:archive` Krok 1 |
| `preflight <nazwa>` | delta wobec `ai/specs/`: numer ADDED wolny (także wobec innych aktywnych zmian), MODIFIED/REMOVED wskazuje istniejący REQ, MODIFIED nie gubi AC z main spec | `/regent:propose` 3a, `/regent:archive` Krok 0 |
| `postmerge <nazwa>` | main specs po merge: bez nagłówków delty i linii Było/Usunięte AC, bez duplikatów REQ, zbiór AC każdego REQ = zbiór z delty | `/regent:archive` po Kroku 2 |
| `drift <nazwa>` | czy pliki z „Affected Files" zmieniły się od `Commit HEAD` z verification.md | `/regent:archive` Krok 0, `/regent:status` |
| `diff <nazwa> [baza]` | fakty dla review: usunięte testy, dodane `.skip/.only/xit`, testy z mniejszą liczbą asercji, pliki spoza „Affected Files" | `/regent:verify` przed Etapami 2-4 |
| `next-req` | następny wolny numer REQ (max z `ai/specs/`, aktywnych zmian i archiwum + 1) | `/regent:propose` Krok 2 |
| `status` | jedna linia na aktywną zmianę: Status, taski x/y, werdykt weryfikacji | `/regent:status` |
| `index` | spis wymagań: `domena: REQ-NNN tytuł (AC: n)` — mapa `ai/specs/` bez czytania całych plików | `regent:spec-writer` (przez prompt z `/regent:propose`) |
| `stale` | pliki z „Affected Files" zarchiwizowanych zmian, zmienione później poza cyklem SDD (commit cyklu = hash w tasks.md, klucz ticketu z proposal w temacie — przeżywa squash — albo dotyka `ai/changes/`) | `/regent:status --drift` |

## Wynik

```
ERROR ai/changes/x/specs/auth.md:14 REQ-001/AC-2 jest w main spec, a nie ma go w bloku MODIFIED …
WARN  ai/changes/x/tasks.md:9 T-04 bez weryfikacja:
INFO  tasks.md: 2/5 zrobione
RESULT: ERROR (errors=1 warnings=1)
```

Kod wyjścia: `0` — brak ERROR, `1` — są ERROR, `2` — błędne użycie. **ERROR** łamie kontrakt
artefaktu (merge zgubiłby dane, format jest nieczytelny dla kolejnych komend). **WARN** to
sygnał do decyzji — komenda, która woła skrypt, mówi, co z nim zrobić. **INFO** to fakt.

## Formaty, na których polega skrypt

- Wymaganie: `### REQ-NNN: Nazwa`; AC pod nim: `- [ ] AC-n: …` (format: `templates/spec-template.md`).
- Usunięcie AC w MODIFIED: `**Usunięte AC:** AC-3 — powód`; AC przepisane bez zmian: dopisek `(bez zmian)`
  na końcu linii (pomijane w pokryciu AC przez taski, zakazane w main spec).
- Task: `- [ ] T-NN: [TAG] opis — REQ-NNN/AC-n — pliki: … — weryfikacja: …` (format: `agents/spec-writer.md`);
  lista `REQ-001/AC-1, AC-3`, zakres `REQ-001/AC-1..3`, całe wymaganie `REQ-001`, refactor `INV-1`.
- `**Usunięte AC:**` w jednej linii (`AC-3 — powód`) albo z listą punktów pod spodem.
- Nagłówki `####` pod REQ (np. scenariusze) nie kończą bloku REQ; `#`–`###` kończą.
- Status: wiersz `| Status | Approved |` albo linia `Status: Approved`.
- Weryfikacja: linie `Verdict: PASS` i `Commit HEAD: <hash>` w verification.md.
- Ślad taska po commicie: `✅ (commit: <hash> · testy: AC-1 → plik › test; …)` (`/regent:apply` 4c) —
  `ai/` jest lokalny, więc to główne powiązanie commitów z cyklem. Bazę `diff` wyznacza kolejno:
  najstarszy commit dotykający katalogu zmiany → najstarszy hash z tasks.md → merge-base z gałęzią
  główną. `stale` uznaje commit za cyklowy po hashu, kluczu ticketu w temacie (całe słowo),
  dotknięciu `ai/changes/` albo po zawartości plików równej zapisanemu commitowi (squash).

Bloki kodu i komentarze HTML są pomijane — instrukcje z szablonów nie są treścią.

## Testy

```bash
bash scripts/tests/sdd-check.test.sh     # fixture'y w katalogu tymczasowym; uruchamia je też framework-lint.sh
```

Skrypt celuje w bash 3.2 (domyślny na macOS) i POSIX awk — bez tablic asocjacyjnych w bashu
i bez rozszerzeń gawk.
