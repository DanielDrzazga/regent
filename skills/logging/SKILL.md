---
description: Instrumentacja istniejącego kodu logami wg logging-patterns.md projektu
disable-model-invocation: true
argument-hint: <ścieżka-lub-opis> [--level debug|info|warn|error|fatal] [--type business|technical]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:logging — Dodaj logi do kodu

**Cel:** Instrumentuj istniejący kod logami na właściwych poziomach (debug → fatal),
zgodnie z wzorcem logowania projektu. NIE buduje loggera — używa istniejącego.

```
/regent:logging <ścieżka-lub-opis> [opcje]

Opcje:
  --level debug|info|warn|error|fatal   Wymuś/ogranicz poziom
  --type business|technical             Wymuś typ logów

Przykład:
/regent:logging src/modules/messenger/application/whatsapp-sender.service.ts
/regent:logging "consumer webhooków WhatsApp"
/regent:logging src/modules/template-management --type business
```

---

## Agent (delegacja — WYMAGANE)

Instrumentację deleguj do subagenta `regent:logging-engineer` (model: sonnet, uruchom narzędziem
Task). Nie dobieraj i nie wstawiaj logów „w miejscu" w głównej sesji — inaczej model
z `agents/logging-engineer.md` nie zostanie użyty.

---

## Krok 0: Walidacja (przenośna — bez zaszytych ścieżek)

Sprawdź czy istnieje `ai/docs/patterns/logging-patterns.md`.

```
✅ Jest → to źródło prawdy: ścieżka loggera + API + zasady. Idź do Kroku 1.

❌ Brak → ZAPYTAJ użytkownika (AskUserQuestion), nie zgaduj:
   (a) Użyć natywnego loggera frameworka teraz (ogólne zasady standardu)
   (b) Przerwać — najpierw utworzyć ai/docs/patterns/logging-patterns.md / wdrożyć standard
   (c) Wskazać ścieżkę loggera ręcznie
```

❗ NIE zakładaj żadnej ścieżki loggera (`src/core/...`, `src/logger/`, …) — czytaj ją z wzorca.

---

## Krok 1: Wczytaj wzorzec + zlokalizuj cel

Subagent `regent:logging-engineer` czyta **bezpośrednio przez Read**:

```
ZAWSZE:
1. ai/docs/patterns/logging-patterns.md   ← ścieżka loggera + API + zasady
2. Wskazane pliki celu (z argumentu komendy)

NIE skanuj całego src/. Jeśli cel to opis (nie ścieżka) → Grep/Glob TYLKO by znaleźć pliki.
```

`regent:logging-engineer` identyfikuje punkty logowania: wejścia/wyjścia operacji, zdarzenia domenowe,
integracje zewnętrzne, bloki `catch`/błędy, istotne gałęzie warunkowe.

---

## Krok 2: Plan instrumentacji (DO AKCEPTACJI)

Deleguj do `regent:logging-engineer` w trybie PLAN (zwraca tabelę w raporcie — bez zmian w kodzie).
Sesja główna pokazuje tabelę użytkownikowi i czeka na zatwierdzenie:

```markdown
## Plan logowania: {cel}

| Plik:linia | level | type | action | Uzasadnienie |
|------------|-------|------|--------|--------------|
| sender.service.ts:42 | info | BUSINESS | MESSAGE_SENT | Wysłano wiadomość |
| sender.service.ts:55 | error | TECHNICAL | META_API_ERROR | Błąd Meta API w catch |

Zatwierdzasz? (tak/nie/popraw)
```

**CZEKAJ.** `tak` → implementacja (kontynuuj TEGO SAMEGO subagenta — resume po agentId —
z komunikatem „plan zaakceptowany, implementuj"). `popraw: ...` → kontynuuj subagenta
z poprawkami i pokaż tabelę ponownie.

---

## Krok 3: Implementacja

```
→ Dodaj logi przez API z wzorca (business()/technical() lub natywne wg ustaleń Kroku 0)
→ Wstrzyknij logger przez DI jeśli klasa go nie ma (wg ścieżki z wzorca)
→ @LogDuration / @WithEventContext gdy pasują (nie dubluj logu requestu)
→ action: RZECZOWNIK_CZASOWNIK, UPPERCASE, EN
→ context: TYLKO ID encji — zero PII/sekretów
→ Jeden log per operacja — nie w pętli/hot-path
→ NIE zmieniaj logiki biznesowej
```

---

## Krok 4: Testy nie czerwone

```
Subagent uruchamia wąsko testy zmienionych modułów:
→ make test-unit PATTERN={moduł}   (lub make test gdy brak celu wąskiego)

Mock loggera = no-op; bez nowych asercji na logi.
Testy mają tylko nie wywalać się przy dodanych logach.
```

Atomic commit — SESJA GŁÓWNA, wyłącznie pliki wymienione w raporcie subagenta:

```bash
git add src/modules/messenger/application/whatsapp-sender.service.ts
git commit -m "chore: (KEY) add structured logging to WhatsAppSenderService"
```

---

## Krok 4.5: Synchronizacja z observability (warunkowa)

```
Jeśli istnieje ai/docs/observability/ ORAZ zmiana DODAJE / ZMIENIA NAZWĘ / USUWA
logowaną `action` (lub zmienia `type`/`module`):

→ Przeczytaj ai/docs/observability/maintenance.md i zasygnalizuj refleksję:
   dashboardy/alerty Kibany filtrują po zaszytej liście `action` — nowa/zmieniona
   akcja NIE pojawi się sama. To FLAGA, nie budowanie dashboardów.

Brak ai/docs/observability/ → pomiń ten krok (nieobowiązkowy).
```

W raporcie (Krok 5) wypisz `⚠️ Observability` z listą nowych/zmienionych `action`, jeśli dotyczy.

---

## Krok 5: Raport (zwięzły)

```markdown
## Logging: {cel} — Done

Logi: N (info: x, warn: y, error: z, debug: w)
Typy: BUSINESS: a, TECHNICAL: b
Pliki: [lista]
⚠️ Observability: nowe/zmienione action → [lista] (sprawdź maintenance.md) — jeśli dotyczy
Commit: abc1234
```

---

## WAŻNE Rules

✅ **ZAWSZE:**
- Źródło prawdy = `ai/docs/patterns/logging-patterns.md` (także ścieżka loggera); brak → zapytaj
- To instrumentacja istniejącego loggera — logger buduje `/regent:propose`, nie ta komenda
- `action` EN UPPERCASE; `business()` dla domeny, `technical()` dla reszty/błędów
- W `context` wyłącznie ID encji — dane osobowe i sekrety zostają poza logiem
- Loguj na granicach modułów; `domain/` zostaje czysty, hot-path i pętle bez logów
- Request loguje istniejący interceptor / axios logger — instrumentuj to, czego nie pokrywa
- Plan instrumentacji → akceptacja (sesja główna) → kod (kontynuacja subagenta)
- Testy wąsko po instrumentacji (subagent); commit w sesji głównej po zielonych testach
- Gdy istnieje `ai/docs/observability/` i zmieniasz `action` → zasygnalizuj sync (Krok 4.5)

❌ **Barierka:** `git add` wyłącznie z listą plików.
