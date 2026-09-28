# Agent teams i regent-watch — praca agentów na żywo w tmux

Dwie rzeczy razem:

1. **Wykonanie** — natywne [agent teams](https://code.claude.com/docs/en/agent-teams) Claude Code
   w trybie split-pane: każdy członek zespołu to osobna sesja Claude Code we własnym panelu tmux.
   Można z nim rozmawiać wprost — wystarczy kliknąć jego panel.
2. **Przegląd** — `regent-watch`, osobne polecenie w oddzielnym oknie tmux, w stylu mission control
   z OpenRig: aktywne sesje z całej maszyny, agenci z bieżącą akcją i kontekstem, oś czasu, graf,
   tokeny i koszt, zdrowie, blokady i błędy. Tylko odczyt.

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
nie ładuje go Claude Code. Wygląd i nawigacja wzorowane na mission control z OpenRig: drzewo
sesji i agentów po lewej, zakładki po prawej, podsumowanie w stopce.

### Instalacja

```bash
cd <klon repo regent>/tools/watch
npm install        # zależności + build do dist/
npm link           # opcjonalnie: polecenie regent-watch w PATH
```

Bez `npm link` uruchamiasz `node <klon repo regent>/tools/watch/dist/cli.js`.

### Uruchomienie

```bash
regent-watch                     # aktywne sesje z całej maszyny; na starcie wybrana najnowsza
                                 # sesja projektu z bieżącego katalogu
regent-watch --session 9421a5dd  # na starcie wybrana ta sesja (ID, prefiks albo session-<8 znaków>)
regent-watch --active 240        # okno aktywności w minutach (domyślnie 60)
```

Sesja jest na liście, gdy jej transkrypt zmienił się w oknie `--active` albo gdy ma żywy zespół.
Sesja wskazana na starcie zostaje na liście zawsze.

W tmux — w osobnym oknie. Członkowie zespołu dzielą okno leada: w smoke'u panel widoku otwarty obok
leada trafił do stosu członków i skurczył się do jednej trzeciej wysokości (20 z 60 wierszy):

```bash
tmux new-window -n watch -c "#{pane_current_path}" regent-watch
```

Gdy lead działa bez zespołu (sami subagenci), wystarczy panel obok:
`tmux split-window -h -c "#{pane_current_path}" regent-watch`. Widok nie uruchamia się sam —
żadnego hooka. Najlepiej wygląda od 100 kolumn szerokości; w węższym terminalu tabela chowa
kolumny MODEL i TOKENY, a akcję agenta przenosi do linii pod nim.

### Ekran

Przykład na syntetycznych danych z testów (terminal 100 × 20):

```
╭─ SESJE  11:00:39 ──────────╮╭─ sesja 11111111 · demo ────────────────────────────────────────────╮
│ ▪ demo  2                  ││ [ Tabela ]   Oś czasu     Graf     Przegląd     Zdrowie            │
│   ▾ ⠋ sesja 11111111   4   ││                                                                    │
│     ● lead            1%   ││ AGENT            KONTEKST    STATUS         CZAS    KOSZT   !      │
│     ├ ⠋ alpha         1%   ││ ────────────────────────────────────────────────────────────────── │
│     ├ ○ beta          0%   ││ lead               1% ▫▫▫▫▫ ● czeka        16 s   ≈$0.00           │
│     └ ○ Explore       0%   ││ alpha              1% ▫▫▫▫▫ ⠋ pracuje      30 s   ≈$0.00   1       │
│   › ● sesja 44444444   1   ││    └ Bash Uruchom testy                                            │
│ ▪ inny  1                  ││ beta               0% ▫▫▫▫▫ ○ zamknięty           ≈$0.00   1       │
│   › ⠋ sesja 55555555   1 ▲ ││   Explore          0% ▫▫▫▫▫ ○ zakończo…           ≈$0.00           │
│                            ││ ────────────────────────────────────────────────────────────────── │
│ UWAGA (1)                  ││ RAZEM                                            13k tok.   ≈$0.01 │
│   ▲ lead inny · ponowieni… ││                                                                    │
╰────────────────────────────╯╰────────────────────────────────────────────────────────────────────╯
3 sesji · 6 agentów · 2 pracuje · 1 wymaga uwagi · ≈$0.02   11:00:21 lead (demo) @ → beta: Prośba o…
↑↓ wybór · ←→ zwiń/rozwiń · Enter szczegóły · Tab/1–5 widok · PgUp/PgDn przewiń · t tmux · / filtr …
```

**Drzewo (SESJE)** — projekty z aktywnymi sesjami, w nich sesje (`▾` rozwinięta, `›` zwinięta),
a pod sesją lead, członkowie zespołu i subagenci (`├`/`└`). Przy każdym agencie: kropka statusu,
procent kontekstu i znak zdrowia. Na dole sekcja **UWAGA** — agenci ze wszystkich sesji, którzy
wymagają uwagi; Enter na wierszu przechodzi do agenta.

**Stopka** — liczba sesji i agentów, ilu pracuje, ilu wymaga uwagi, łączny koszt ≈ oraz ostatnie
zdarzenie ze wszystkich sesji; w drugiej linii klawisze albo komunikat (np. po `t`).

**Zakładki sesji** (`Tab` albo `1`–`5`):

1. **Tabela** — agenci: kontekst z paskiem `▪▪▫▫▫`, status z animacją, czas stanu, tokeny, koszt,
   liczba blokad i błędów `!`, bieżąca akcja (albo pierwszy problem zdrowia); wiersz RAZEM.
2. **Oś czasu** — zdarzenia wszystkich agentów sesji, najnowsze na dole; przewinięta oś trzyma
   oglądany fragment, `G` wraca do śledzenia na żywo.
3. **Graf** — drzewo pudełek: lead → członkowie zespołu → subagenci; ramka w kolorze statusu
   (żółta albo czerwona — zdrowie), na krawędzi `✉n↓m↑` — wiadomości lead → członek i członek → lead;
   wiadomości między członkami pod grafem.
4. **Przegląd** — sesja (ID, projekt, czas trwania, stan), agenci wg statusu, tokeny wg rodzaju
   (wejście, zapis i odczyt cache, wyjście), koszt wg modelu, narzędzia wg liczby wywołań z błędami,
   wiadomości i spawny, problemy wg rodzaju.
5. **Zdrowie** — każdy agent: `●` ok, `▲` uwaga, `✗` problem, z powodami.

**Szczegóły agenta** (wybór agenta w drzewie): pasek kontekstu z rozmiarem i oknem modelu, tokeny
wg rodzaju, koszt (i koszt wg Claude Code po zamknięciu), bieżąca akcja i czas, panel tmux, zdrowie,
ostatnie zdarzenia i błędy agenta, ID sesji i ścieżka transkryptu.

### Klawisze

| Klawisz | Działanie |
|---|---|
| `↑` `↓` (`k` `j`) | wybór w drzewie |
| `→` `←` (`l` `h`) | rozwiń / zwiń sesję; `←` na agencie wraca do sesji |
| `Enter` | rozwiń sesję; na wierszu w UWAGA — przejdź do agenta |
| `Esc` | wróć do sesji, wyczyść filtr, zamknij pomoc |
| `Tab`, `1`–`5` | zakładka sesji |
| `PgUp` `PgDn`, `g` `G` | przewijanie prawego panelu; `G` na osi czasu — na żywo |
| `t` | przełącz tmux na panel wybranego agenta |
| `/` | filtr drzewa: projekt, sesja albo agent (`Enter` — zatwierdź, `Esc` — wyczyść) |
| `?` | pomoc z legendą symboli |
| `q` | wyjście |

**Skok `t`** zmienia tylko fokus tmux (`select-window` + `select-pane`), danych nie dotyka. Członek
zespołu: jego panel z `config.json` albo z wyniku spawnu. Lead: panel w oknie członków, który nie
jest członkiem ani samym widokiem — dlatego skok do leada działa tylko przy żywym zespole. Subagent:
skok do panelu rodzica. Poza tmux widok pokazuje komunikat zamiast skoku.

### Symbole i progi

- Status: animacja `⠋` zielona — `pracuje` (narzędzie w toku, akcja i czas od jego startu),
  niebieskozielona — `myśli` (model generuje odpowiedź), `●` — `czeka` (koniec tury),
  `○` — `zakończony` (subagent) albo `zamknięty` (członek po shutdownie, sesja zamknięta).
- Kontekst: rozmiar po ostatnim wywołaniu API (wejście + zapis i odczyt cache). Okna transkrypt nie
  zapisuje, więc procent liczony od okna z tabeli modeli (Haiku 4.5 — 200k, pozostałe — 1M).
- Zdrowie: kontekst ≥ 150k albo 75% okna — uwaga, ≥ 250k albo 90% — problem (progi jak statusline);
  z ostatnich 30 min: błąd API — problem, blokada hooka, odmowa uprawnień, ponowienia API, co
  najmniej 3 błędy narzędzi — uwaga; narzędzie albo tura bez nowych rekordów ponad 10 min — uwaga.
  Agenci zamknięci i zakończeni nie są oceniani.
- Tokeny: przetworzone przez agenta (wejście, zapis i odczyt cache, wyjście), z deduplikacją po
  `message.id`, jak w `session-tokens.sh`. Koszt `≈` to szacunek z cennika API i dolna granica:
  zapytania poboczne Claude Code nie trafiają do transkryptu. Po zamknięciu sesji widać też koszt
  policzony przez Claude Code (`wg Claude Code`).
- Oś czasu: prompty (`>`), narzędzia (`·`), spawny (`+`), wiadomości między agentami (`@`),
  błędy (`✗`), blokady hooków (`⊘`), ponowienia API (`↻`), końce tur (`─`).

### Skąd bierze dane

| Źródło | Co z niego bierze |
|---|---|
| `~/.claude/projects/*/` | lista aktywnych sesji: `mtime` transkryptów, co 5 s |
| `~/.claude/projects/<projekt>/<sesja>.jsonl` | lead: zdarzenia, tokeny, kontekst, błędy, wysłane wiadomości, wyniki spawnu; `cost-state` przy zamknięciu |
| `~/.claude/projects/<projekt>/<sesja członka>.jsonl` | członek zespołu — rozpoznany po `teamName` i `agentName` w rekordach, dołączony do sesji leada |
| `~/.claude/projects/<projekt>/<sesja>/subagents/agent-*.jsonl` (+ `.meta.json`) | subagenci i ich typ |
| `~/.claude/teams/session-<8 znaków>/config.json` | kto z zespołu jeszcze jest (po shutdownie członek znika), kolor, panel tmux; żywy katalog trzyma sesję na liście |

Plików zadań (`~/.claude/tasks/`) i skrzynek (`…/inboxes/`) widok nie czyta: są ulotne (znikają
po doręczeniu i po ukończeniu zadań), a wiadomości i tak widać w transkryptach. `CLAUDE_CONFIG_DIR`
zmienia katalog `~/.claude`. Transkrypty czytane są przyrostowo; tożsamość pliku (lead czy członek
zespołu) sprawdzana raz.

## Prywatność

`regent-watch` czyta transkrypty lokalnie i niczego nie zapisuje ani nie wysyła. Widok pokazuje
**aktywne sesje z całej maszyny** — na maszynie mieszanej także sesje z projektów z pracy, tylko
w Twoim terminalu. Zrzutów ekranu z takimi sesjami nie wklejaj do repo ani opisów zmian; przykłady
w dokumentacji i testy pakietu używają wyłącznie syntetycznych danych (`tools/watch/test/fixtures/`).

## Ograniczenia

- Funkcja eksperymentalna: nazwy pól i plików mogą się zmienić. Parsery pomijają nieznane rekordy
  i pola; zmianę formatu wychwycą testy na fixture'ach dopiero po ich odtworzeniu z nowej wersji.
- Jeden zespół na sesję; członkowie nie tworzą własnych zespołów.
- Status członka po shutdownie widać tylko wtedy, gdy katalog zespołu jeszcze istnieje; po wyjściu
  z leada wszyscy są `zamknięty`.
- Członek zespołu pracujący w innym katalogu niż lead jest znajdowany przez `cwd` z `config.json`
  — tylko dopóki zespół żyje.
- „Needs you” z OpenRig (agent czeka na Twoją zgodę) nie jest widoczne w transkrypcie — wymagałoby
  hooka `Notification`; osobna zmiana.
- Brak obsługi myszy (Ink jej nie ma) i paska poleceń — wszystko z klawiatury.
- Animacja pracy przerysowuje ekran 4 razy na sekundę: przy pracujących agentach widok zużywa
  ok. 5–12% jednego rdzenia (pomiar: 9 sesji, terminal 200 × 50); gdy nikt nie pracuje, animacja stoi.
