# Agent teams — praca agentów na żywo w tmux

Natywne [agent teams](https://code.claude.com/docs/en/agent-teams) Claude Code w trybie split-pane:
każdy członek zespołu to osobna sesja Claude Code we własnym panelu tmux. Można z nim rozmawiać
wprost — wystarczy kliknąć jego panel.

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
  tam członkowie zespołu pracują w jednym terminalu (tryb in-process).

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
członka. Słabszy model potrafi źle odpowiedzieć na prośbę o shutdown — wtedy wyjdź z leada
(`/exit`) i wybierz „Exit and stop tasks": Claude Code zatrzyma członków, zamknie ich panele
i usunie katalog zespołu.

## Ograniczenia

- Funkcja eksperymentalna: format plików zespołu może się zmienić.
- Jeden zespół na sesję; członkowie nie tworzą własnych zespołów.
