---
description: Systematyczna diagnoza problemu — reprodukcja, analiza, root cause; fix przez /regent:bugfix
disable-model-invocation: true
argument-hint: <opis-problemu>
allowed-tools: Read, Grep, Glob, Bash
---

# /regent:debugging — Systematyczne diagnozowanie problemów

**Cel:** Systematyczne podejście do debugowania — ciasna pętla pass/fail, hipotezy, root cause.
**Granica:** ta komenda DIAGNOZUJE. Naprawa idzie przez `/regent:bugfix` (dev/staging) lub
`/regent:hotfix` (produkcja) — tam są artefakty, test regresji i zamknięcie przez `/regent:archive`.

```
/regent:debugging <opis-problemu>

Przykład:
/regent:debugging "API returns 500 on user creation"
/regent:debugging "tests pass locally but fail in CI"
/regent:debugging "memory usage grows over time"
```

---

## Agent (delegacja)

Brak dedykowanego subagenta „debugger" — reprodukcja, zbieranie informacji i testowanie
hipotez (kroki 1-4) prowadzone są w głównej sesji. Zakres komendy kończy się na
potwierdzonym root cause — dalej handoff do `/regent:bugfix` (Krok 5).

---

## Krok 1: Zbuduj ciasną pętlę (BRAMKA — to jest sedno tej komendy)

> **Dlaczego:** mając sygnał pass/fail, który świeci na czerwono na **tym** bugu, przyczynę
> znajdziesz — bisekcja, hipotezy i instrumentacja tylko go konsumują. Bez niego czytanie kodu
> nie zastąpi pomiaru. Tu wkładasz nieproporcjonalnie dużo wysiłku; reszta komendy jest mechaniczna.

**Pętla to jedna komenda**, którą już uruchomiłeś i której wyjście pokazujesz. Czterech cech
szuka się w tej kolejności:

```
□ CZERWONA   — świeci na TYM bugu (a nie „testy przechodzą, ale coś nie działa")
□ DETERMINISTYCZNA — ten sam wynik w kółko
□ SZYBKA     — sekundy, nie minuty
□ AGENT-RUNNABLE — uruchamialna bez klikania w UI
```

**Drabina — sięgaj po kolejne szczeble, aż pętla powstanie:**

```
1.  Failing test (wąsko: pojedynczy plik/pattern)     ← zacznij tutaj
2.  curl / żądanie HTTP z zapisanym wyjściem
3.  CLI + fixture + diff snapshotu
4.  Headless browser (E2E na jednym scenariuszu)
5.  Replay zapisanego trace'u / requestu z logów
6.  Jednorazowy harness (skrypt wołający moduł wprost)
7.  Pętla property/fuzz — 1000 losowych wejść, szukasz pierwszego czerwonego
8.  Harness pod `git bisect run`
9.  Pętla różnicowa: wersja działająca vs zepsuta, to samo wejście
10. Skrypt bash z krokami dla człowieka                ← ostateczność
```

**Bug niedeterministyczny:** celem jest **wyższy wskaźnik powtarzalności**, nie czysta
reprodukcja. Bug 50% jest debugowalny, 1% nie jest — podnieś go pętlą (powtórzenia,
zrównoleglenie, sztuczne opóźnienia), zanim ruszysz dalej.

**Sekrety:** pętlę buduj na zmiennych środowiskowych — poświadczenie zostaje w środowisku,
poza tym, co pokazujesz w raporcie.

### Bramka wyjścia z Kroku 1

```
□ Potrafię nazwać JEDNĄ komendę
□ Uruchomiłem ją co najmniej raz
□ Pokazuję wywołanie i jego wyjście (zredagowane)
□ Jest czerwona na tym bugu
```

❗ **Dopóki ta komenda nie istnieje, zostajesz w Kroku 1.** Przyłapanie się na czytaniu kodu
w poszukiwaniu teorii przed zbudowaniem pętli jest sygnałem, że trzeba wrócić tutaj —
skok do hipotezy jest dokładnie tym błędem, któremu ta komenda zapobiega.

---

## Krok 1.5: Zminimalizuj pętlę

Tnij po jednym elemencie: krok, pole payloadu, zależność, plik konfiguracyjny.

**Gotowe, gdy każdy pozostały element jest nośny** — usunięcie któregokolwiek gasi czerwone
światło. Minimalna pętla kurczy przestrzeń hipotez w Kroku 3 i staje się czystym testem
regresji w `/regent:bugfix`.

---

## Krok 2: Reprodukcja i kontekst

Pętla z Kroku 1 jest już wykonywalnym zapisem reprodukcji — tu dopisujesz to, czego nie niesie.

```
### Expected: [co powinno się stać]
### Actual:   [co się dzieje]
### Error:    [dokładny komunikat / stack trace]

### Powtarzalność: [zawsze | X% prób | tylko gdy: ...]

### Środowisko (gdy ma znaczenie dla buga)
- Runtime / wersje zależności istotnych dla ścieżki
- Różnica lokalnie vs CI vs produkcja

### Ostatnie zmiany
git log --oneline -10   → czy pętla jest zielona na commicie sprzed zmiany?
```

---

## Krok 3: Hipotezy

### 3a. Wygeneruj 3-5 hipotez NARAZ

> **Dlaczego naraz:** pojedyncza hipoteza zakotwicza na pierwszym prawdopodobnym pomyśle
> i reszta diagnozy szuka już tylko jej potwierdzenia.

Każda hipoteza **falsyfikowalna**, w formacie z przewidywaniem:

```
H1: [przyczyna]
    Jeśli H1, to [zmiana X] zgasi czerwone światło pętli.
    Ranking: [wysoki | średni | niski]   Uzasadnienie: [1 zdanie]
```

Hipoteza bez dającego się sformułować przewidywania to przeczucie — zaostrz ją albo odrzuć.

### 3b. Checkpoint u użytkownika (nieblokujący)

Pokaż listę rankowaną **zanim** zaczniesz testować. Użytkownik często zna domenę na tyle,
by przestawić kolejność w jednym zdaniu. Brak odpowiedzi → testujesz wg własnego rankingu.

### 3c. Testuj po kolei — pętlą, nie czytaniem kodu

```
H1 → [zmiana testowa] → pętla: czerwona/zielona → POTWIERDZONA | ODRZUCONA
```

**Logi debugowe taguj unikalnym prefiksem**, np. `[DEBUG-a4f2]`. Sprzątanie na końcu to
jeden `grep`: otagowane znikają, nieotagowane zostają w kodzie na zawsze.

---

## Krok 4: Root Cause

```
## Root Cause Analysis

### Direct Cause
[Co bezpośrednio powoduje problem]

### Contributing Factors
[Co przyczynia się do problemu — np. brak walidacji, race condition]

### Why Not Caught Earlier
[Dlaczego nie zostało wykryte wcześniej — brak testu, edge case]
```

---

## Krok 5: Handoff do naprawy

```
Root cause potwierdzony → przekaż diagnozę dalej:

→ /regent:bugfix "{opis}" — standardowa ścieżka (artefakty, test regresji, /regent:archive)
→ /regent:hotfix "{opis}" — gdy problem jest NA PRODUKCJI i krytyczny

Przekaż do komendy naprawczej — diagnoza jest już zrobiona, `/regent:bugfix` zaczyna od gotowego:
- **komendę pętli** (Krok 1, po minimalizacji) → staje się tam testem regresji
- **root cause** (Krok 4) i listę zaangażowanych plików

Naprawa należy do `/regent:bugfix` / `/regent:hotfix` — tam powstają artefakty, test regresji
i zamknięcie przez `/regent:archive`.
```

---

## Gdy diagnoza utyka

- **Pętla za wolna lub migocząca** → wróć do Kroku 1 i zaciśnij ją. Pętla 30-sekundowa i
  migocząca jest ledwie lepsza od żadnej; 2-sekundowa deterministyczna to zupełnie inna praca.
- **Wszystkie hipotezy odrzucone** → przestrzeń szukania jest za wąska. Rozszerz o warstwę
  niżej (runtime, zależność, konfiguracja środowiska), wygeneruj nowe 3-5.
- **Bug znika przy obserwacji** → race condition albo zależność od czasu; pętla różnicowa
  (szczebel 9) i sztuczne opóźnienia zamiast logów.

Timeline: 30-120 minut
