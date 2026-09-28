# Agent teams i regent-watch — praca agentów na żywo w tmux

Dwie rzeczy razem:

1. **Wykonanie** — natywne [agent teams](https://code.claude.com/docs/en/agent-teams) Claude Code
   w trybie split-pane: każdy członek zespołu to osobna sesja Claude Code we własnym panelu tmux.
   Można z nim rozmawiać wprost — wystarczy kliknąć jego panel.
2. **Przegląd** — `regent-watch`, osobne polecenie w oddzielnym oknie tmux: agenci z bieżącą akcją,
   oś czasu zdarzeń, tokeny i koszt, blokady i błędy. Tylko odczyt.

Agent teams to funkcja **eksperymentalna** Claude Code. Sprawdzone na wersji 2.1.280; format plików
zespołu może się zmienić (fakty ze spike'a: [plans/agent-teams-view.md](plans/agent-teams-view.md)).

## Zanim włączysz

- **Koszt.** Każdy członek zespołu ma własny kontekst i własny prompt systemowy. Lead i dwóch
  członków na Haiku przy trywialnym zadaniu kosztowali razem 0,46–0,67 USD (smoke i spike), z czego
  lead — 0,26–0,32 USD. Przy Opusie i realnej pracy koszt rośnie wprost z liczbą członków. Małe
  zespoły, tani model dla członków, zadania niezależne od siebie.
- **Delegacja SDD się zmienia.** Z włączonymi teams subagent, któremu Claude nada nazwę
  (parametr `name` narzędzia Agent), startuje jako **członek zespołu**, a nie subagent. Dotyczy
  to też agentów pluginu (`regent:architect`, `regent:code-reviewer` itd.). Taki agent nie oddaje
  raportu jak subagent, tylko pracuje obok jako osobna sesja, więc pętla pytań i bramki
  akceptacji ze skilli działają inaczej. Claude potrafi nazwać subagenta sam, bez prośby — zespół
  może powstać niepostrzeżenie.
- **Tylko wybrany projekt.** Z obu powodów teams włączasz w `.claude/settings.local.json`
  konkretnego projektu, **nigdy globalnie** w `~/.claude/settings.json`. Globalne włączenie
  zmieniłoby delegację w każdej sesji, także w projektach z pracy.
- **Wznawianie.** `/resume` nie przywraca członków zespołu; po wznowieniu lead może pisać do
  członków, których już nie ma — poproś go wtedy o nowych.

## Włączenie w projekcie

W katalogu projektu, w `.claude/settings.local.json` (plik lokalny, poza repo projektu):

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
  "teammateMode": "tmux"
}
```

To wystarcza — spike potwierdził, że `env` i `teammateMode` z ustawień projektu działają bez
zmiennej w powłoce. Członkowie zespołu dziedziczą `--plugin-dir`, więc dostają kontekst pluginu,
a git-guard działa także w ich sesjach.

Wyłączenie: `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"` w tym samym pliku — Claude Code
wczytuje zmianę od razu, bez restartu sesji.

Wymagania:

- tmux (albo iTerm2 z `it2`); panele nie działają w Windows Terminal, terminalu VS Code i Ghostty —
  tam członkowie zespołu pracują w jednym terminalu (tryb in-process), a `regent-watch` działa normalnie;
- Node 24 dla `regent-watch`.

## Praca z zespołem

```bash
tmux new -s praca                      # albo istniejąca sesja tmux
cd <projekt> && claude --plugin-dir <klon repo regent>
```

W sesji poproś wprost o zespół i model członków, np.: „Utwórz agent team z dwoma członkami:
`api` i `testy`, obaj na modelu haiku. `api` robi …, `testy` robi …". Lead tworzy wspólną listę
zadań, a członkowie dostają panele w **oknie leada** (lead po lewej, członkowie w stosie po prawej).

Członkowie pytają o uprawnienia w panelu leada, więc typowe operacje warto dopuścić wcześniej —
edycje **zawężone do projektu**: `"Edit(/**)"` w `permissions.allow` pliku `settings.local.json`
(reguła `Edit` obejmuje też `Write`, a `/` oznacza katalog projektu). Nie dopuszczaj gołego
`Write` ani `Edit`: w smoke'u członek na Haiku zapisał plik pod złą ścieżką bezwzględną, w katalogu
domowym, i nic go nie zatrzymało.

Zamknięcie: poproś leada, żeby zamknął członków (shutdown); zatwierdzony shutdown zamyka panel
członka. Słabszy model potrafi źle odpowiedzieć na prośbę o shutdown (widać to w `regent-watch`
jako błędy `SendMessage`) — wtedy wyjdź z leada (`/exit`) i wybierz „Exit and stop tasks":
Claude Code zatrzyma członków, zamknie ich panele i usunie katalog zespołu.

## regent-watch

Pakiet: [`tools/watch/`](../tools/watch/) (Node 24, TypeScript, Ink) — poza komponentami pluginu,
nie ładuje go Claude Code.

### Instalacja

```bash
cd <klon repo regent>/tools/watch
npm install        # zależności + build do dist/
npm link           # opcjonalnie: polecenie regent-watch w PATH
```

Bez `npm link` uruchamiasz `node <klon repo regent>/tools/watch/dist/cli.js`.

### Uruchomienie

W katalogu projektu (widok znajduje najnowszą sesję tego katalogu):

```bash
regent-watch                     # najnowsza sesja projektu
regent-watch --session 9421a5dd  # konkretna: pełne ID, prefiks albo session-<8 znaków>
```

W tmux — w osobnym oknie. Członkowie zespołu dzielą okno leada: w smoke'u panel widoku otwarty obok
leada trafił do stosu członków i skurczył się do jednej trzeciej wysokości (20 z 60 wierszy):

```bash
tmux new-window -n watch -c "#{pane_current_path}" regent-watch
```

Gdy lead działa bez zespołu (sami subagenci), wystarczy panel obok:
`tmux split-window -h -c "#{pane_current_path}" regent-watch`. Widok nie uruchamia się sam —
żadnego hooka.

Klawisze: `↑`/`↓` albo `k`/`j` — przewijanie osi czasu, `PgUp`/`PgDn` — strona,
`g`/`G` — początek i koniec (koniec = śledzenie na żywo), `q` — wyjście.

### Co pokazuje

Ekran ze smoke'a (w trakcie pracy zespołu, skrócony):

```
regent-watch sesja b9f5a519 · smoke-teams

Agenci
AGENT          MODEL      STATUS        CZAS  TOKENY    KOSZT   !  AKCJA
lead           haiku-4-5  myśli          2 s    340k   ≈$0.09
alpha          haiku-4-5  pracuje        2 s    131k   ≈$0.05      Bash Wait 15 seconds
beta           haiku-4-5  myśli          2 s     79k   ≈$0.03   2
RAZEM                                           550k   ≈$0.17

Oś czasu (21, na żywo)
18:15:21 lead           @ → beta: Assign task #2 to beta
18:15:23 lead           + alpha (haiku)
18:15:25 lead           + beta (haiku)
18:15:30 alpha          · Bash Wait 15 seconds
18:15:30 beta           ✗ Read: File does not exist.
18:15:34 beta           ⊘ Bash: SDD git-guard: git add całości …

Blokady i błędy (2)
18:15:30 beta           błąd narzędzia Read: File does not exist.
18:15:34 beta           blokada hooka git-guard.sh Bash: SDD git-guard: git add całości …
```

Po zamknięciu sesji wszyscy mają status `zamknięty`, a wiersz RAZEM dostaje koszt policzony przez
Claude Code, np. `RAZEM … 2.2M ≈$0.39    wg Claude Code: $0.46`. Subagenci mają wiersze
`<rodzic>›<typ>`, np. `lead›Explore`.

- **Agenci** — lead, członkowie zespołu (w kolejności dołączenia) i subagenci (`<rodzic>›<typ>`).
  Status: `pracuje` (narzędzie w toku — akcja i czas od jego startu), `myśli` (model generuje
  odpowiedź), `czeka` (koniec tury), `zakończony` (subagent skończył), `zamknięty` (członek po
  shutdownie albo sesja zamknięta). Kolumna `!` — liczba blokad i błędów agenta.
- **Tokeny i koszt** — tokeny przetworzone przez agenta (wejście, zapis i odczyt cache, wyjście),
  z deduplikacją po `message.id`, jak w `session-tokens.sh`. Koszt `≈` to szacunek z cennika API
  i dolna granica: zapytania poboczne Claude Code nie trafiają do transkryptu. Gdy wszystkie sesje
  się zamkną, wiersz RAZEM pokazuje też koszt policzony przez Claude Code.
- **Oś czasu** — prompty (`>`), narzędzia (`·`), spawny (`+`), wiadomości między agentami (`@`),
  błędy (`✗`), blokady hooków (`⊘`), ponowienia API (`↻`) i końce tur (`─`).
- **Blokady i błędy** — ostatnie pięć: blokada hooka (z nazwą skryptu, np. `git-guard.sh`),
  odmowa uprawnień, błąd narzędzia, błąd API.

### Skąd bierze dane

| Źródło | Co z niego bierze |
|---|---|
| `~/.claude/projects/<projekt>/<sesja>.jsonl` | lead: zdarzenia, tokeny, błędy; `cost-state` przy zamknięciu |
| `~/.claude/projects/<projekt>/<sesja członka>.jsonl` | członek zespołu — rozpoznany po `teamName` i `agentName` w rekordach |
| `~/.claude/projects/<projekt>/<sesja>/subagents/agent-*.jsonl` (+ `.meta.json`) | subagenci i ich typ |
| `~/.claude/teams/session-<8 znaków>/config.json` | kto z zespołu jeszcze jest (po shutdownie członek znika) i jego kolor |

Plików zadań (`~/.claude/tasks/`) i skrzynek (`…/inboxes/`) widok nie czyta: są ulotne (znikają
po doręczeniu i po ukończeniu zadań), a wiadomości i tak widać w transkryptach. `CLAUDE_CONFIG_DIR`
zmienia katalog `~/.claude`.

## Prywatność

`regent-watch` czyta transkrypty lokalnie i niczego nie zapisuje ani nie wysyła. Transkrypty na
maszynie mieszanej mogą zawierać treść z projektów z pracy — widok pokazuje je tylko w Twoim
terminalu. Testy pakietu używają wyłącznie syntetycznych fixture'ów (`tools/watch/test/fixtures/`).

## Ograniczenia

- Funkcja eksperymentalna: nazwy pól i plików mogą się zmienić. Parsery pomijają nieznane rekordy
  i pola; zmianę formatu wychwycą testy na fixture'ach dopiero po ich odtworzeniu z nowej wersji.
- Jeden zespół na sesję; członkowie nie tworzą własnych zespołów.
- Status członka po shutdownie widać tylko wtedy, gdy katalog zespołu jeszcze istnieje; po wyjściu
  z leada wszyscy są `zamknięty`.
- Członek zespołu pracujący w innym katalogu niż lead jest znajdowany przez `cwd` z `config.json`
  — tylko dopóki zespół żyje.
