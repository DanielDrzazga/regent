# Contributing — SDD Framework

Dziękujemy za wkład. To repo to **zbiór promptów** (komendy, agenci, szablony) — nie ma tu
kodu aplikacyjnego, więc „testem” jest spójność, przenośność i zgodność z filozofią SDD.

## Zasady ogólne

- **Przenośność** — nic nie może zakładać konkretnego stacku ani ścieżek projektu. Realia projektu
  opisuje `ai/docs/` (generowane przez `/regent:init`), a komendy/agenci czytają je jako źródło prawdy.
- **Oszczędność tokenów** — agenci czytają docelowe pliki przez Read (nie skanują `src/`);
  testy w pętli TDD uruchamiają wąsko (moduł/pattern), pełny `make check` tylko w bramkach.
- **Kontrakt subagenta** — subagent nie rozmawia z użytkownikiem w trakcie pracy: bramki
  akceptacji prowadzi sesja główna, artefakty do akceptacji agent zwraca w raporcie
  (szczegóły w `context/sdd.md`).
- **Zwięzłość** — komendy i agenci mają być krótkie i konkretne; bez rozwlekłych opisów.
- **Język** — dokumentacja i treść: polski; `action`/kod/identyfikatory: angielski.

## Dodanie nowego skilla (`skills/<nazwa>/SKILL.md`)

Struktura zgodna z istniejącymi skillami (nazwa katalogu bez sufiksu, wywołanie `/regent:<nazwa>`):

0. Frontmatter YAML: `description` (do listy komend), `argument-hint` (gdy są argumenty),
   `allowed-tools` (dla komend read-only, np. `/regent:explore`, `/regent:status`).
1. Nagłówek `# /regent:<nazwa> — <cel>` + jednozdaniowy cel.
2. Blok użycia z argumentami i przykładami.
3. Kroki (numerowane) z jasnym punktem **akceptacji użytkownika** przed zapisem/zmianami.
4. Sekcja „WAŻNE Rules” — **formułowana pozytywnie** (`✅ ZAWSZE`): opisuje zachowanie,
   które ma nastąpić, nie to, którego ma nie być. Zakaz (`❌`) zostaw wyłącznie tam, gdzie
   jest twardą barierką, której nie da się wyrazić pozytywnie (np. „read-only: bez Edit/Write”),
   i sparuj go wtedy z celem. Powód w sekcji „Jak pisać prompty”.
5. Jeśli skill deleguje pracę — wskaż, którego **agenta** uruchamia, pełną nazwą `regent:<agent>`.

Po dodaniu dopisz skill do tabeli w `README.md` i `context/sdd.md`.

## Jak pisać prompty (komendy i agenci)

Prompt czyta model, nie człowiek — a model reaguje na sformułowania inaczej, niż podpowiada
intuicja.

**Prowadź pozytywem, nie zakazem.** Zakaz wnosi zakazane zachowanie do kontekstu i czyni je
*bardziej* dostępnym, nie mniej („nie myśl o słoniu”). Negacja jest słabym modyfikatorem —
silnie aktywowane pojęcie ją przykrywa, więc zakaz w połowie czyta się jak instrukcja.
Napisz, co ma się stać:

```
❌ „Nie dawaj PASS bez testu na AC”        →  ✅ „PASS wymaga testu na każde AC”
❌ „Nie pisz verbose raportów”             →  ✅ „Raport: werdykt + file:line, bez cytowania kodu”
❌ „NIE skanuj src/”                       →  ✅ „Czytaj przez Read pliki wskazane w design.md”
```

Gdy reguła istnieje już w wersji pozytywnej, **zakaz-bliźniak jest duplikatem** — usuń go,
zamiast trzymać obie formy. Barierka nie do wyrażenia pozytywnie (uprawnienia, granice
narzędzi) zostaje jako `❌`, ale ze wskazaniem celu.

**Używaj pojęć, nie opisów.** Nazwa, która żyje w pretreningu modelu, uruchamia całą klasę
wzorców; opis tego samego — nie. `Feature Envy` działa, „funkcja za dużo sięga do cudzych
danych” działa słabiej. Powtarzaj pojęcie jako termin, nie rozwijaj go za każdym razem w zdanie.

**Pomiń to, co model i tak robi.** Instrukcja, której model domyślnie przestrzega („najpierw
zreprodukuj błąd”, „sprawdź logi”, „pisz czytelny kod”), płaci koszt kontekstu i nic nie wnosi.
Gdy całe zdanie nic nie zmienia — skasuj zdanie, nie skracaj go.

**Kryterium ukończenia ma być sprawdzalne.** „Osiągnięto zrozumienie” zaprasza do przedwczesnego
zakończenia; „każde AC ma test” i „verification.md zapisany (verdict + data + commit HEAD)”
rozstrzygają się binarnie. Gdy kryterium jest nieostre — najpierw je zaostrz.

**Jedno źródło.** Regułę opisz w jednym miejscu i odsyłaj do niego; opis powtórzony w drugim
pliku rozjeżdża się przy pierwszej zmianie. Dotyczy to także tej zasady: nie powtarzaj jej
w komendach.

## Dodanie/zmiana agenta (`agents/<nazwa>.md`)

Front-matter (YAML) — **wymagane pola**:

```yaml
---
name: <nazwa>
description: >
  <opis po angielsku — kiedy używać agenta>
model: opus | sonnet | haiku | inherit
tools: Read, Grep, Glob, Bash          # dobierz do roli; role oceniające BEZ Edit/Write
---
```

- `model` **musi** być realnym polem YAML — nigdy `<!-- model: ... -->` (inaczej nie zadziała).
- Claude Code rozpoznaje tylko `name`, `description`, `tools`, `model` — inne klucze
  (np. `language`) są ignorowane; reguły językowe zapisuj w TREŚCI promptu.
- Dobór modelu: **opus** (wysoki koszt błędu / głębokie rozumowanie — design, security, review),
  **sonnet** (implementacja, pisanie, instrumentacja logów), **haiku** (bardzo proste, powtarzalne zadania).
- Dobór `tools`: role oceniające (review, audyt) i projektujące — read-only (`Read, Grep, Glob, Bash`);
  role implementujące — z `Edit, Write`.
- Treść: Rola → „Przed rozpoczęciem” (co czytać) → Odpowiedzialności/Checklisty → Zasady →
  **Format raportu końcowego** (subagent komunikuje się wyłącznie raportem).
- **Słownik werdyktów agenta weryfikującego: `PASS / WARN / BLOCK`** — jeden dla wszystkich.
  Kryterium FAIL w `/regent:verify` opiera się na tych trzech słowach; własny dialekt
  (`OK/RYZYKA`, `GAPS`, `APPROVED`) sprawia, że blokujący werdykt przechodzi jako PASS.
  Znaczenie progów opisz pod nagłówkiem — patrz `dba.md`, `qa-engineer.md`.

## Dodanie szablonu

- Artefakt zmiany → `templates/<nazwa>-template.md`.
- Plik `ai/docs/` → `templates/docs/<nazwa>.md` (skeleton z placeholderami `[...]`, nie realia
  konkretnego projektu). Podłącz go w `/regent:init` (lista generowanych plików).

## Walidacja lokalna

Przed każdym commitem uruchom lint — w repo z promptami to on jest testem:

```bash
bash scripts/framework-lint.sh      # RESULT: OK → można commitować
```

Sprawdza frontmatter agentów i skilli, istnienie każdego wskazanego skilla/agenta/szablonu/skryptu,
prefiks `regent:` przy agentach, zgodność tabel w `context/sdd.md` i `README.md` z `skills/`
i `agents/`, wycofane nazwy (także dawne `-sdd`) oraz
**regresje** — wzorce naprawionych błędów promptów (`forbid`/`require` w sekcji 7 skryptu).
Naprawiasz błąd promptu → dopisz regułę regresji w tym samym commicie. Lint uruchamia też
testy skryptów (`scripts/tests/*.test.sh`) — zmieniasz `sdd-check.sh` → dopisz przypadek testowy.

**Skrypty w `scripts/`** celują w bash 3.2 (domyślny na macOS) i POSIX awk: bez tablic
asocjacyjnych w bashu, bez rozszerzeń gawk, wyrażenia regularne do awk przez `ENVIRON`
(nie `-v`, które interpretuje sekwencje ucieczki). Skrypt wołany przez komendę jest read-only.

## Commity

`<type>: (<KEY>) <opis>` — **jedna linia, max 100 znaków, bez body**. Typy: `feat`, `fix`,
`hotfix`, `refactor`, `test`, `chore`, `docs`, `perf`. Bez ticketu → bez `(KEY)`.
Atomic commits (1 commit = 1 logiczna zmiana), nigdy `git add .`.
