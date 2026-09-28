# Plan: watch-ui

> Druga zmiana `regent-watch` (po `agent-teams-view`): interfejs w stylu OpenRig. Lekka ścieżka:
> gałąź `feat/watch-ui`, ten plan, bramka i smoke. Odpowiada na otwarte pytanie z wizji — „który
> aspekt OpenRig się spodobał”: podgląd wszystkiego w jednym miejscu (potrzeby A i H).

## Cel

`regent-watch` wygląda i działa jak mission-control z OpenRig (wzór:
`openrig/assets/readme/openrig-agents-working.gif`): po lewej drzewo aktywnych sesji i agentów
z kropką statusu i procentem kontekstu, po prawej zakładki, na dole podsumowanie i ostatnie zdarzenie.
Nawigacja strzałkami, Enter — szczegóły, `t` — skok do panelu tmux agenta.

## Decyzje (2026-09-28)

| Decyzja | Wartość |
|---|---|
| Układ | jak OpenRig: drzewo po lewej (wybór strzałkami), zakładki po prawej, pasek podsumowania i klawisze na dole |
| Widoki | Tabela, Oś czasu, Graf, Szczegóły agenta + „inne wartościowe z OpenRig” `[delegowane]` → Przegląd, Zdrowie, sekcja Uwaga, filtr `/`, pomoc `?`, stopka z ostatnim zdarzeniem |
| Graf | wchodzi — zastrzeżenie zgłoszone (najdroższy, przy 2–4 agentach wnosi najmniej); decyzja użytkownika: tak |
| Skok do tmux | tak: `t` przełącza okno i panel tmux na wybranego agenta (`select-window` / `select-pane`); dane dalej tylko do odczytu |
| Sesje | aktywne wszędzie: wszystkie sesje na maszynie ze zmianą w ostatniej godzinie (`--active <min>`), pogrupowane po projekcie; sesja z bieżącego katalogu wybrana na starcie |
| Poza zakresem | pasek poleceń z Tab-uzupełnianiem, mysz (Ink jej nie obsługuje), „Needs you” (czekanie na zgodę widać dopiero przez hook `Notification` — osobna zmiana), kolejka i health OpenRig (własny demon) |

## Taski

- [x] T1: model danych — kontekst agenta (ostatnie wywołanie: input + zapis + odczyt cache; okno wg
  modelu: Haiku 200k, pozostałe 1M), zdrowie agenta (progi kontekstu jak statusline: 150k / 250k;
  blokady, odmowy, błędy i ponowienia API; narzędzie > 10 min; brak aktywności > 10 min), krawędzie
  grafu (spawn, wiadomości w obie strony, subagenci), przegląd sesji (czas, tokeny wg rodzaju,
  koszt wg modelu, narzędzia wg liczby wywołań); testy
- [x] T2: sesje na całej maszynie — skan `~/.claude/projects/*/` co 5 s, sesja aktywna = zmiana
  transkryptu w oknie `--active` (domyślnie 60 min) albo żywy katalog zespołu; transkrypty członków
  pod ich leadem (po `teamName`), nie jako osobne sesje; `--session` dalej działa; testy
- [x] T3: szkielet UI — ramki z tytułami, drzewo (projekt → sesja → lead, członkowie, subagenci)
  z kropką statusu, animacją pracy i % kontekstu, sekcja Uwaga, zakładki `1`–`5` / `Tab`, stopka:
  podsumowanie + ostatnie zdarzenie + klawisze, pomoc `?`, filtr `/`
- [x] T4: zakładki sesji — Tabela (kontekst z paskiem, status, akcja, czas, tokeny, koszt, `!`),
  Oś czasu (wszyscy albo wybrany agent — `a`), Przegląd, Zdrowie, Graf (drzewo pudełek: lead →
  członkowie → subagenci, liczba wiadomości na krawędziach, wiadomości między członkami pod grafem)
- [x] T5: szczegóły agenta (Enter / wybór agenta w drzewie) — pasek kontekstu, rozbicie tokenów
  i kosztu, bieżąca akcja, panel tmux, zdrowie, ostatnie zdarzenia i błędy agenta
- [x] T6: skok do tmux `t` — członek: `tmuxPaneId` z `config.json`; lead: panel w oknie członków,
  który nie jest członkiem ani samym widokiem; bez tmux albo bez panelu — komunikat w stopce
- [x] T7: testy UI (ink-testing-library: każda zakładka, nawigacja, filtr, pomoc) na syntetycznych
  fixture'ach; drugi projekt w fixture'ach do testu wielu sesji
- [x] T8: dokumentacja — `docs/agent-teams.md` (nowy ekran, klawisze, sesje z całej maszyny,
  prywatność), README pakietu bez zmian w strukturze repo
- [x] T9: bramka — `bash scripts/framework-lint.sh` + `claude plugin validate .` + w `tools/watch/`
  `npm test` i `npm run typecheck`
- [x] T10: smoke bez kosztu tokenów — transkrypty ze spike'a i smoke'a `agent-teams-view` oraz bieżąca
  sesja; zrzuty `tmux capture-pane` każdej zakładki; skok `t` w tmux
- [x] T11: merge `feat/watch-ui` → `main`, push

## Ryzyka

- **Prywatność** — „aktywne wszędzie” pokazuje na ekranie sesje z projektów z pracy (Mac mieszany):
  widok tylko czyta lokalnie; zrzuty ze smoke'a z nazwami projektów z pracy nie trafiają do repo ani
  dokumentacji — przykłady w dokumentacji wyłącznie z projektów syntetycznych.
- **Złożoność** — wizja ostrzega przed nadmiarem; każda zakładka to czysta funkcja modelu + cienki
  komponent, testowane osobno. Graf ograniczony do drzewa (bez dowolnych krawędzi między pudełkami).
- **Wydajność** — skan całego `~/.claude/projects` co 5 s: tylko `stat` plików, czytanie początku
  pliku raz (pamięć tożsamości), tail przyrostowy wyłącznie dla aktywnych sesji.
- **Okno kontekstu** — transkrypt go nie zawiera; wartość z tabeli modeli może się różnić od
  ustawień sesji (np. wariant 200k) — procent opisany jako szacunek, próg zdrowia liczony w tokenach.
- **Skok do panelu leada** — heurystyka (panel w oknie członków); bez zespołu lead nie ma panelu
  do wskazania.

## Przebieg (2026-09-28)

- T1–T7: model widoku (kontekst, zdrowie, krawędzie grafu, przegląd), `Workspace` (sesje z całej
  maszyny), UI z linii-danych: panele to czyste funkcje `Line[]`, Ink tylko rysuje. 61 testów
  (w tym UI: każda zakładka, nawigacja, filtr, pomoc, skok `t` z podmienionym tmux). Fixture'y
  rozszerzone o kolory w wyniku spawnu, wiadomości między członkami i drugi projekt.
- Odstępstwo od T4: zamiast przełącznika `a` na osi czasu zdarzenia wybranego agenta są w jego
  szczegółach (sekcja OSTATNIE ZDARZENIA) — mniej trybów do zapamiętania.
- Wąski terminal: przy 100 kolumnach tabela chowa MODEL i TOKENY, a akcję przenosi do linii pod
  agentem (jak kolumna WORK w OpenRig).
- Wydajność (fakt z pomiaru): React bez `NODE_ENV` działał w trybie deweloperskim — ok. 26% CPU
  i 416 MB. Po trybie produkcyjnym ustawianym w `cli.ts` przed importem Reacta, `incrementalRendering`,
  limicie 8 klatek/s i animacji co 250 ms: ok. 5–12% jednego rdzenia i 150–270 MB przy pracujących
  agentach (9 sesji, 200 × 50). Profil CPU: czas idzie w rysowanie Ink (ANSI, szerokość znaków);
  warstwa danych — ok. 2 ms na odświeżenie.
- T10 (smoke bez tokenów): na żywo 9 sesji z okna 4 h (tylko projekty prywatne), bieżąca sesja
  z własną akcją Bash na żywo; transkrypty smoke'a `agent-teams-view`: tabela z kosztem wg Claude
  Code 0,46 USD, graf z `✉4↓3↑` / `✉5↓4↑`, oś czasu z blokadą git-guard, przegląd, zdrowie. Skok `t`
  w tmux na syntetycznych danych z prawdziwymi panelami: członek → jego panel, lead → panel w oknie
  członków (heurystyka zadziałała).
