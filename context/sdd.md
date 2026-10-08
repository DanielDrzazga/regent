# Regent — reguły SDD

> Mapa skilli i agentów: `context/sdd-map.md`.

> **Zakres:** Reguły SDD (przepływ komend, zakazy, delegacja) obowiązują **tylko w projektach z katalogiem `ai/docs/`** lub gdy user jawnie inicjalizuje SDD przez `/regent:init`. W pozostałych projektach obowiązuje wyłącznie „Twoja rola" (`context/role.md`).

## Jak pracować ze specyfikacją

Spec jest kontraktem, nie sugestią. Ale zły spec to zły kontrakt.

Przed implementacją oceń czy spec ma sens:
- Czy AC są kompletne? Czy pokrywają edge case'y i błędy?
- Czy zakres jest realistyczny?
- Czy design nie wprowadza niepotrzebnej złożoności?

Jeśli coś jest niejasne lub błędne — **zatrzymaj się i zapytaj**, nie zgaduj.

## Czego nigdy nie rób

- Nie implementuj czegoś o czym wiesz że jest złe — najpierw zgłoś zastrzeżenia
- Nie pomijaj kroków SDD bo "to mała zmiana" — każda zmiana ma swój flow
- Nie rozszerzaj scope'u ponad to co jest w specyfikacji (scope creep)
- Nie commituj bez testów — nawet w hotfixie

## Przepływ pracy

Dokumentacja projektu: `ai/docs/` — komendy określają co i kiedy czytać.
Jeśli `ai/docs/` nie istnieje → `/regent:init` najpierw.

Struktura artefaktów SDD w projekcie (`ai/` jest osobisty i globalnie ignorowany — nie trafia do repo produktu):
- `ai/docs/` — wiedza o projekcie (stack, wzorce, konwencje)
- `ai/specs/` — main specs per domena (źródło prawdy po archiwizacji)
- `ai/changes/{nazwa}/` — aktywne zmiany (proposal, specs delta, design, tasks, verification)
- `ai/changes/archive/` — zamknięte zmiany

Każda zmiana funkcjonalna:
1. `/regent:propose` — spec przed kodem
2. `/regent:apply` — TDD: Red → Green → Refactor
3. `/regent:verify` — 9-etapowa weryfikacja (etapy 5-8 warunkowe)
4. `/regent:archive` — formalne zamknięcie (rezygnacja ze zmiany: `--abandon` — bez merge delty)

Skróty (uproszczona ścieżka) dozwolone tylko dla:
- `/regent:bugfix` — bug w dev/staging (uproszczone artefakty, ale kończy się przez `/regent:archive`)
- `/regent:hotfix` — krytyczny bug na produkcji (max 30 min, max 3 pliki / 2 moduły)

`/regent:refactor` to NIE skrót — pełny cykl propose → apply → verify → archive, zawsze z sekcją INVARIANTS w delta spec.

## Budżet subagentów (sufit kosztu)

Reguły oszczędzania (Krok 1b′ w `/regent:propose`, resume zamiast re-delegacji, kontekstowe czytanie
`ai/docs/`) mówią JAK oszczędzać, ale nie mówią ILE wolno wydać. Poniżej sufit — orientacyjny,
liczony **per komenda**, w uruchomieniach subagentów (resume tego samego agenta ≠ nowe
uruchomienie, dlatego resume jest zawsze tańsze).

| Rozmiar zmiany | `/regent:propose` | `/regent:apply` | `/regent:verify` | `/regent:archive` | **cykl razem** |
|---|---|---|---|---|---|
| **S** (1-3 taski, 1 moduł) | 1-2 | 1 | 1-2 | 1 | **≤ 6** |
| **M** (4-8 tasków, 1-2 moduły) | 2-3 | 1-3 | 2-4 | 1 | **≤ 11** |
| **L** (9+ tasków, 3+ moduły) | 3-5 | 3-6 | 4-6 | 1 | **≤ 18** |

Rozmiar bierz z `tasks.md` (`Size: S/M/L`); przed jego powstaniem — oszacuj.
Kolumna „cykl razem" to sufit dla JEDNEJ zmiany od propozycji do zamknięcia — to jego
przekroczenie boli użytkownika, nie pojedyncza komenda.

**Komendy poza cyklem** (`/regent:init`, `/regent:dependency-update`,
`/regent:logging`, `/regent:testing`, `/regent:code-review`, `/regent:refactor`, `/regent:bugfix`,
`/regent:hotfix`, `/regent:revise`, `/regent:explore`): **1 uruchomienie na krok delegujący**, poprawki
przez resume.

**Przekroczenie sufitu jest dozwolone, ale wymaga jednego zdania uzasadnienia** dla
użytkownika, np. *„4. subagent: security-auditor — zmiana dotyka autoryzacji"*. Sufit ma
wymuszać świadomość kosztu, nie blokować pracę.

**Najczęstsze przyczyny przekroczenia — sprawdź je, zanim odpalisz kolejnego agenta:**
- decyzje rozstrzygane sekwencyjnie po raportach zamiast rundami przed delegacją (`/regent:propose` Krok 1b′)
- re-delegacja od zera tam, gdzie wystarczał resume
- delegowanie pracy mechanicznej (zapis pliku, `mv`, tabela) — to robi sesja główna
- odpalanie agenta warunkowego „na wszelki wypadek" (np. `regent:security-auditor` przy zmianie
  bez nowych wejść — to opus, kosztuje)

## Commit

Komunikat commita to jedna linia wg `ai/docs/conventions/git-workflow.md` — bez body i stopek
(`Co-Authored-By` i podobnych). git-guard odrzuca atrybucję AI, a odrzucony commit to zmarnowana tura.

## Kontrakt `make` (jedno źródło — nie powtarzaj w komendach)

Komendy SDD wołają cele `make` (`check`, `test`, `lint`, `type-check`, `test-coverage`,
`deps-*`) jako **fasadę nad stackiem**, nie jako twardą zależność.

Gdy `Makefile` nie istnieje lub brakuje danego celu:
1. **Nie przerywaj pracy** — ustal natywny odpowiednik ze stacku (`ai/docs/stack/technology.md`,
   a gdy go brak — z manifestu: `package.json`, `pyproject.toml`, `go.mod`, `composer.json`).
2. Wykonaj natywną komendę i **powiedz jawnie, czego użyłeś zamiast `make X`**.
3. Po zakończeniu zadania zaproponuj uzupełnienie `Makefile`
   (`${CLAUDE_PLUGIN_ROOT}/templates/Makefile.node.template`) — przez `/regent:init` lub `/regent:revise`.

Wyjątek: gdy celu nie da się odtworzyć natywnie → **STOP i zapytaj użytkownika**. Nie zgaduj procedury.

## Konwencja nazw: namespace `regent:`

Komendy frameworka to skille pluginu `regent`, wywoływane jako `/regent:<nazwa>` — `/regent:propose`,
`/regent:apply`, `/regent:init`, `/regent:code-review` itd.

Powód: nazwy takie jak `init`, `status` czy `code-review` kolidują z wbudowanymi komendami
i skillami Claude Code — krótka forma `/<nazwa>` działa tylko wtedy, gdy nic innego jej nie zajmuje.
Prefiks pluginu rozstrzyga kolizję i daje korzyść uboczną: `/regent:` + Tab pokazuje cały
framework w jednym miejscu.

**W treści skilli, agentów i dokumentacji zawsze pełna forma `/regent:<nazwa>`**, także gdy krótka
dziś z niczym nie koliduje (wbudowanych komend przybywa). Agentów wskazuj pełną nazwą
`regent:<agent>`.
