# Frontend Patterns

> Opcjonalny. Generowany przez `/regent:init`, gdy projekt ma frontend. Wypełnij konkretami
> wykrytymi w repo (package.json, config bundlera, struktura komponentów) lub z wywiadu.
> To **źródło prawdy** dla agenta `regent:frontend-dev` — bez tego pliku nie implementuje UI.

## Framework & rendering

| Element | Wartość |
|---------|---------|
| Framework UI | [np. React 18 / Vue 3 / Svelte / Angular] |
| Tryb renderowania | [SPA / SSR / SSG / hybrydowy] |
| Build tool | [np. Vite / Next / Nuxt / webpack] |
| Ścieżka aplikacji w repo | [np. apps/web/ — istotne w monorepo; `.` gdy single-app] |

## Struktura komponentów

```
[drzewo katalogów — np.
src/
├── features/{feature}/     # komponenty, hooki, api per feature
├── components/             # współdzielone komponenty prezentacyjne
├── pages|routes/           # widoki/trasy
└── lib/                    # utilities
]
```

- Zasada podziału: [np. feature-based / atomic design / pages+components]
- [Prezentacyjne vs kontenerowe / smart vs dumb — jeśli projekt rozróżnia]
- Komponenty współdzielone → [gdzie i kiedy przenosić]

## Biblioteka komponentów / design system

| Element | Wartość |
|---------|---------|
| Biblioteka | [np. wewnętrzny DS / MUI / shadcn / brak — własne komponenty] |
| Ikony | [np. lucide / heroicons] |

- Zasada: **najpierw komponent z biblioteki**, custom tylko gdy biblioteka nie pokrywa przypadku.

## State management

| Rodzaj stanu | Narzędzie | Kiedy |
|--------------|-----------|-------|
| Lokalny (komponent) | [np. useState / ref] | [stan UI jednego komponentu] |
| Globalny (klient) | [np. Zustand / Pinia / Context / brak] | [np. sesja, motyw] |
| Server-state (dane z API) | [np. TanStack Query / SWR / store] | [cache odpowiedzi API] |

- Store'y/query definiowane w: [ścieżka]
- NIE trzymaj w stanie globalnym: [np. danych server-state, stanu formularzy]

## Warstwa API / klient HTTP

<!-- Kluczowa sekcja — frontend-dev NIE zgaduje, jak wołać backend. -->

| Element | Wartość |
|---------|---------|
| Klient HTTP | [np. wrapper na fetch / axios instance] |
| Ścieżka klienta | [np. src/lib/api-client.ts] |
| Definicje wywołań | [np. src/features/{feature}/api/] |
| Typy kontraktu | [ręczne w src/types/ / generowane z OpenAPI — komenda] |
| Auth headers | [np. interceptor dodaje Bearer z sesji] |
| Obsługa błędów | [np. ApiError + mapowanie kodów → komunikaty] |

- Zasada: API wywołuj **wyłącznie przez warstwę klienta** — nigdy „goły fetch" w komponencie.

## Routing

| Element | Wartość |
|---------|---------|
| Biblioteka | [np. React Router / file-based (Next) / Vue Router] |
| Definicje tras | [ścieżka lub konwencja plików] |
| Ochrona tras (auth guard) | [np. guard/layout sprawdzający sesję — ścieżka] |

## Styling

| Element | Wartość |
|---------|---------|
| Podejście | [np. CSS Modules / Tailwind / CSS-in-JS] |
| Tokeny / zmienne | [np. tailwind.config / theme.ts] |

- Zakazy: [np. style inline, kolory hardcoded poza tokenami]

## Formularze i walidacja

| Element | Wartość |
|---------|---------|
| Narzędzie formularzy | [np. react-hook-form / natywne / VeeValidate] |
| Walidacja | [np. zod — schematy w …] |

- Relacja do walidacji backendu: [np. schematy współdzielone z pakietu / duplikowane — backend jest źródłem prawdy]

## A11y

- Minimalne wymagania: [np. semantyczny HTML, obsługa klawiatury, focus management, aria-labels dla ikon]
- Kontrola: [np. eslint-plugin-jsx-a11y / axe w E2E / review manualny]

## i18n (jeśli dotyczy — usuń, gdy brak)

| Element | Wartość |
|---------|---------|
| Mechanizm | [np. i18next / vue-i18n] |
| Format kluczy | [np. feature.component.label] |
| Pliki tłumaczeń | [ścieżka] |

- Zasada: zero tekstów hardcoded w komponentach — wszystko przez klucze.

## Testy komponentowe

| Element | Wartość |
|---------|---------|
| Runner | [np. Vitest / Jest] |
| Biblioteka renderująca | [np. Testing Library (react/vue) / brak] |
| E2E przeglądarkowe | [np. Playwright / Cypress / brak] |
| Selektory | [np. role/label-first; data-testid tylko gdy brak roli] |
| Mock HTTP | [np. MSW / mock klienta API — jak] |
| Komendy | `make test-component`, `make test-e2e` |

- Testuj **zachowanie widoczne dla użytkownika** (render + interakcja + rezultat), nie wewnętrzny stan.
- Mock HTTP w testach komponentowych; realny backend TYLKO w E2E.
