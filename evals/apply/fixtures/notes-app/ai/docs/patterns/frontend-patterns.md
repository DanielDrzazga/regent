# Frontend Patterns

## Framework & rendering

| Element | Wartość |
|---------|---------|
| Framework UI | brak — czysty JavaScript (ESM) |
| Tryb renderowania | komponent to funkcja `(stan) → string` z HTML-em |
| Build tool | brak |
| Ścieżka aplikacji w repo | `web/` |

## Struktura komponentów

```
web/
├── html.js          # escapeHtml — jedyny sposób wstawiania tekstu do HTML
├── api-client.js    # createApiClient(fetch) — jedyna warstwa HTTP
└── <komponent>.js   # render<Komponent>(stan) + akcje/reducer + load<Komponent>(api)
```

- Komponent: `render<Nazwa>(stan) → string`. Bez dostępu do DOM i globalnego stanu.
- Interakcja: czysty reducer `(stan, akcja) → stan` w pliku komponentu.
- Dane z API: `load<Nazwa>(api, …) → stan` (`status: 'loading' | 'error' | 'ready'`); `api` to wynik
  `createApiClient(fetch)`. Nowy endpoint → nowa metoda w `web/api-client.js` wg kontraktu z `design.md`.

## Stan i dane

- Stany UI zawsze: `loading` (`role="status"`), `error` (`role="alert"`, tekst dla użytkownika), pusty.
- Tekst od użytkownika lub z API wstawiasz wyłącznie przez `escapeHtml`.

## Dostępność

- Semantyczne znaczniki (`ul/li`, `form role="search"`, `label for`), komunikaty stanu przez `role`.

## Testy komponentowe

- Test = render → akcja (reducer albo `load…` z podmienionym `fetch`) → asercja na widocznym HTML.
- Mock HTTP: `fetch` podmieniony funkcją zwracającą `{ ok, status, json }` wg kontraktu z `design.md`;
  wzór w `test/web-note-list.test.js`.
- Asercje na tym, co widzi użytkownik (tekst, role, kolejność), nie na wewnętrznych polach stanu.
