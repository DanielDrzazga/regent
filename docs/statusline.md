# Statusline — licznik kontekstu

Pasek na dole terminala pokazujący na żywo, ile kontekstu zajmuje sesja. Długie sesje
zużywają najwięcej tokenów (zwłaszcza subagentowe), a bez wskaźnika nie widać, kiedy
kontekst urósł na tyle, że warto zrobić `/clear`. Statusline to uwidacznia.

Skrypt: [`scripts/statusline.sh`](../scripts/statusline.sh).

## Jak wygląda

```
Opus  ctx 9% (90k/1000k)  $0.30                     ← zielono, spokojnie
Opus  ctx 18% (180k/1000k)  ⚠ obserwuj  $1.10        ← żółto
Opus  ctx 27% (270k/1000k)  ⛔ czas na /clear  $2.20  ← czerwono
```

Pokazuje: model, procent okna, tokeny (zajęte / max), etykietę progu i koszt sesji.

## Instalacja

Wymaga `jq` i włączonego pluginu `regent`. Hook `SessionStart` pluginu
([`scripts/hooks/sync-bin.sh`](../scripts/hooks/sync-bin.sh)) kopiuje skrypt do stałej ścieżki
w danych pluginu, która przetrwa aktualizacje — katalog pluginu w cache zmienia się z każdą wersją,
więc `statusLine` nie może wskazywać na niego wprost:

```
~/.claude/plugins/data/regent-inline/bin/statusline.sh      # claude --plugin-dir (dziś)
~/.claude/plugins/data/regent-regent/bin/statusline.sh      # po publikacji: regent@regent z marketplace
```

Dziś statusline działa ze starego frameworka (`~/.claude/scripts/statusline.sh`). Po publikacji
pluginu raz na maszynie dodaj wpis do `~/.claude/settings.json` (plugin nie może ustawić
`statusLine` głównej sesji):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/plugins/data/regent-regent/bin/statusline.sh\""
  }
}
```

W tym samym katalogu leży `session-tokens.sh` — zużycie tokenów sesji per prompt:
`bash ~/.claude/plugins/data/regent-regent/bin/session-tokens.sh`.

Statusline odświeża się po każdej odpowiedzi asystenta.

## Progi

Progi są liczone od **bezwzględnej liczby tokenów**, nie od procentu okna:

| Zakres | Kolor | Etykieta |
|--------|-------|----------|
| < 150k | zielony | (brak) |
| 150k–250k | żółty | `⚠ obserwuj` |
| > 250k | czerwony | `⛔ czas na /clear` |

**Dlaczego bezwzględne, a nie procent:** przy oknie 1M (`opus[1m]`) procent ostrzega
o wiele za późno — 80% z miliona to 800k tokenów, czyli kontekst już bardzo drogi.
Bezwzględne progi ostrzegają wtedy, gdy realnie robi się kosztownie, niezależnie od
rozmiaru okna. Jeśli pracujesz na zwykłym oknie 200k, możesz progi podnieść — edytuj
wartości `150000` / `250000` w skrypcie.

## Skąd bierze dane

Claude Code przekazuje skryptowi na stdin JSON z gotową sekcją `context_window`
(m.in. `total_input_tokens`, `context_window_size`, `used_percentage`) oraz `cost`.
Nie trzeba parsować transkryptu sesji.

## Ograniczenie

To wskaźnik, nie automat — nie przerywa pracy ani nie wykonuje `/clear` za Ciebie.
Decyzję o wyczyszczeniu kontekstu podejmujesz sam. Jest to jednak jedyne miejsce
w Claude Code, które zna rzeczywistą liczbę tokenów kontekstu (hooki jej nie
otrzymują), więc do świadomego pilnowania kosztu w zupełności wystarcza.
