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

Wymaga `jq`.

1. Z katalogu sklonowanego repo skopiuj skrypt do katalogu `scripts/` w swojej
   konfiguracji Claude Code i nadaj prawa wykonywania (jeśli framework masz już
   wgrany w `~/.claude`, skrypt jest na miejscu — pomiń `cp`):

   ```bash
   cp scripts/statusline.sh ${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh
   chmod +x ${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh
   ```

2. Dodaj wpis do `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
     }
   }
   ```

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
