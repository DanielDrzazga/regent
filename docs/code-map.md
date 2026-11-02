# Mapa kodu — Graphify (opcjonalnie)

Agenci Regenta lokalizują pliki i zależności przez zapytania do grafu kodu
([Graphify](https://github.com/Graphify-Labs/graphify)) zamiast przez Grep/Glob, gdy taki graf
istnieje w projekcie. Bez niego wszystko działa dokładnie jak dotąd — to rozszerzenie, nie
zależność. Reguła dla agentów: [`context/code-map.md`](../context/code-map.md).

## Instalacja (izolowana)

Graphify to pakiet Pythona (`graphifyy` na PyPI, linkowany z README repo `Graphify-Labs/graphify`,
licencja Apache-2.0). Instaluj izolowanie — `pipx` albo `venv` — nie globalnie:

```bash
pipx install graphifyy          # albo: python3 -m venv .venv && .venv/bin/pip install graphifyy
```

CLI musi być w `PATH` sesji Claude Code (`graphify --help`), żeby Bash agentów go znalazł.

## Budowa i aktualizacja grafu

```bash
graphify extract . --code-only --out ai/graph
```

- `--code-only` — indeksuje wyłącznie kod (lokalny parser AST, tree-sitter), bez LLM, bez klucza
  API i bez sieci; pomija pliki dokumentów/obrazów/PDF całkowicie (zweryfikowane: 0 węzłów z
  Markdownu).
- `--out ai/graph` — graf trafia do `ai/graph/graphify-out/graph.json` (katalog `ai/` jest
  osobisty i globalnie ignorowany — `/regent:init` Krok 0.5 — więc graf nie trafia do repo).
- To samo polecenie aktualizuje graf przyrostowo (cache AST per plik) — uruchom je ponownie po
  zmianach w kodzie. **Buduje i aktualizuje tylko sesja główna albo użytkownik** — subagent,
  nawet gdy zauważy nieaktualny graf, nie wywołuje Graphify.
- `/regent:init` proponuje zbudowanie grafu, gdy CLI jest dostępne i grafu jeszcze nie ma
  (Krok 0.75), razem z `.graphifyignore` zawierającym `*.md` — zabezpieczenie, gdyby ktoś później
  ręcznie odpalił `graphify update` (ten, w przeciwieństwie do `extract --code-only`, domyślnie
  wciąga nagłówki Markdown jako węzły, choć bez LLM).
- Po pierwszym `/regent:init` to samo polecenie jest też celem Makefile: `make code-map`
  (`templates/Makefile.node.template`, i ten sam cel w ręcznie generowanym Makefile dla innych
  stacków) — wygodny skrót dla człowieka. Agenci wołają `graphify` bezpośrednio (reguła w
  `context/code-map.md`), nie przez `make`, bo działa identycznie przed i po Kroku 3 (generowanie
  Makefile) i nie zależy od tego, czy cel akurat jest w Makefile projektu.

### Dlaczego bez hooków Graphify

Regent nie uruchamia `graphify install`, `graphify hook install` ani trybu `--strict`. O tym,
kiedy sięgać do kodu, decydują reguły Regenta (`context/code-map.md`) — Graphify jest tylko
narzędziem wywoływanym przez Bash, nie osobnym agentem z własnymi hookami w projekcie.

### Pułapka: `cluster-only` i `label`

Graf z `extract --code-only` ma numeryczne społeczności (`community`), bez nazw
(`community_name`). Nazwanie ich wymaga `graphify cluster-only`/`graphify label`, a te **bez
`--no-label` próbują użyć LLM** — przy braku klucza API nawet shellują do lokalnego `claude -p`.
Regent tego nie wywołuje; jeśli robisz to ręcznie, zawsze dodaj `--no-label`.

## Polecenia używane przez agentów

```bash
graphify path "ModułA" "ModułB" --graph ai/graph/graphify-out/graph.json    # ścieżka A → B
graphify explain "Nazwa" --graph ai/graph/graphify-out/graph.json          # kto woła X / kogo woła X
graphify affected "Nazwa" --graph ai/graph/graphify-out/graph.json         # co zależy od X
graphify god-nodes --graph ai/graph/graphify-out/graph.json               # centralne węzły (moduły-huby)
```

Wynik wskazuje plik i linię (`source_file`, `source_location`) — agent czyta treść przez `Read`.
`query`/`path`/`explain` mają sufit kosztu: `query` domyślnie `--budget 2000` tokenów.

## Prywatność i sieć

Graf buduje się lokalnie z kodu, bez LLM i bez sieci (`--code-only` zweryfikowane offline —
zablokowane proxy, brak kluczy API, budowa i aktualizacja przechodzą). Nie trafia do repo
(`ai/` jest osobisty). Kod i dane z pracy etatowej — jak zawsze w tym repo — zostają poza nim
(`.claude/rules/privacy.md`); graf z repo firmowego budujesz i czytasz tylko lokalnie, na
komputerze firmowym.

## Kiedy się opłaca

Pomiar na trzech repo (`scripts/code-map-compare.sh`, szczegóły w sekcji „Wyniki” w
[`docs/plans/code-map-graphify.md`](plans/code-map-graphify.md)) pokazuje, że **rozmiar repo nie
jest jedynym czynnikiem** — liczy się też, jak łatwo znaleźć odpowiedź samym Grep:

- **Małe, znane repo** (`notes-app` w evalach, kilka plików) — koszt budowy grafu i wywołań CLI
  jest wyższy niż prosty Grep. Oczekiwane, nie regresja.
- **Pytanie, które Grep rozwiązuje jednym trafieniem** (unikalna nazwa symbolu, mało wystąpień)
  bywa droższe z grafem **niezależnie od rozmiaru repo** — na realnym backendzie z ~500 plikami
  wariant z grafem wypadł wyraźnie drożej (koszt, tokeny i czas powyżej progu szumu) dla pytania
  o wpływ zmiany jednego, dobrze nazwanego zdarzenia domenowego. Dodatkowe zapytanie do grafu
  dokłada kroki, które Grep i tak by wykonał szybciej.
- **Repo średniej wielkości z pytaniem wymagającym kilku przeskoków zależności** (np. „co zależy
  od tego pliku” przez więcej niż jeden import) — graf wygrywa wyraźnie: na publicznym repo
  średniej wielkości (~95 plików) `/regent:explore` z grafem wyszedł o ~19% taniej i ~15%
  szybciej przy tej samej jakości; `/regent:init --detect` na tym samym repo — podobny czas
  (~14% szybciej), koszt w granicach szumu.

**Praktyczna reguła:** graf pomaga najbardziej, gdy pytanie brzmi „co zależy od X” albo „ścieżka
A → B” przez nieoczywisty, wielomodułowy łańcuch — nie przy pytaniach, które i tak rozwiązuje
jeden dobry Grep.

## Ograniczenia zaobserwowane

- DI przez parametr konstruktora (np. NestJS `constructor(private x: FooService)`) nie daje
  krawędzi wywołania — `graphify path` między klasami wstrzykiwanymi przez konstruktor spada do
  wspólnego `contains` pliku, nie realnej zależności. Grep po nazwie typu bywa tu dokładniejszy.
- Graf nie zapisuje commita ani znacznika czasu porównywalnego z `HEAD` — świeżość sprawdza się
  heurystycznie (`find -newer`, patrz `context/code-map.md`), nie dowodowo.
