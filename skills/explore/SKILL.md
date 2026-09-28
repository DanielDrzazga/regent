---
description: Analiza read-only — zbadaj temat, porównaj opcje, bez plików i commitów
disable-model-invocation: true
argument-hint: <temat> | --discovery <inicjatywa>
allowed-tools: Task, Read, Grep, Glob, AskUserQuestion, SendMessage, Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(ls:*)
---

# /regent:explore — Zbadaj temat bez commitowania

**Cel:** Zbadaj, przeanalizuj, porównaj opcje — bez tworzenia plików czy commitów. Czysto eksploracyjna komenda.

```
/regent:explore <temat>
/regent:explore --discovery <inicjatywa>

Przykład:
/regent:explore how authentication is implemented
/regent:explore impact of adding websockets
/regent:explore compare Redis vs Memcached for caching
/regent:explore --discovery "koordynacja zleceń terenowych dla firm geodezyjnych"
```

---

## Agent (delegacja — WYMAGANE)

Analizę deleguj do subagenta `regent:architect` (model: opus, uruchom narzędziem Task) —
to najsilniejszy reasoner i właściciel analizy repo (jak w `/regent:init`). Jakość eksploracji
zależy od modelu, dlatego nie prowadź jej „w miejscu" w głównej sesji.

❗ Tryb **read-only**: subagent NIE tworzy plików ani commitów — tylko analizuje i raportuje
(`regent:architect` nie ma narzędzi Edit/Write, a `allowed-tools` tej komendy wymusza read-only
także w sesji głównej).

---

## Zasady

1. **Read-only** — nie twórz plików, nie modyfikuj kodu
2. **Analityczny** — zbierz fakty, porównaj opcje, oceń trade-offs
3. **Konwersacyjny** — output w konwersacji, nie w plikach

---

## Typy eksploracji

### Analiza kodu
```
Jak działa [moduł/feature]?
→ Przeczytaj kod, zrozum flow, opisz architekturę
```

### Porównanie opcji
```
Opcja A vs Opcja B?
→ Porównaj: pros/cons, effort, risk, fit z architekturą
```

### Impact analysis
```
Co się zmieni jeśli [zmiana]?
→ Zidentyfikuj affected files, modules, tests
→ Oszacuj ryzyko i effort
```

### Research
```
Jak zaimplementować [feature]?
→ Zbadaj opcje, sprawdź docs, zaproponuj podejście
```

### Discovery (`--discovery`)
```
Nowy produkt albo duża inicjatywa — co budujemy i w jakich zmianach?
→ Wywiad, synteza, kandydaci na zmiany SDD, werdykt — sekcja „Tryb --discovery"
```

---

## Format output

```markdown
## Explore: [temat]

### Findings
[Co odkryto]

### Options (jeśli porównanie)
| Aspekt | Opcja A | Opcja B |
|--------|---------|---------|
| ... | ... | ... |

### Recommendation
[Co polecam i dlaczego]

### Werdykt
BUDUJEMY / DOPRECYZUJ ([czego brakuje do decyzji]) / NIE BUDUJEMY ([dlaczego])

### Wejście do /regent:propose (gdy BUDUJEMY)
- Problem: [1-2 zdania]
- Zakres IN / OUT: [...]
- Rozstrzygnięte w eksploracji: [kwestia → decyzja] — trafiają do logu jako DECYZJA
- Otwarte: [kwestie] — pierwszy frontier Challenge

### Następne kroki
→ /regent:propose ... (BUDUJEMY — wklej blok „Wejście do /regent:propose")
→ /regent:explore ... (DOPRECYZUJ)
```

---

## Tryb `--discovery` — nowy produkt lub duża inicjatywa

**Kiedy:** nowy produkt od zera albo inicjatywa o niejasnym zakresie, za którą stoi kilka zmian
SDD. Pojedyncza, zrozumiała zmiana → od razu `/regent:propose`.

### D1. Wywiad (SESJA GŁÓWNA — max 2 rundy)

**Runda 1 — problem i ludzie**
```
1. Jaki ból rozwiązujemy i skąd wiesz, że istnieje?
2. Kto go ma i kogo boli najbardziej? (persony — kim są, w którym momencie ich boli)
3. Jak radzą sobie dziś? (obejścia, konkurencja)
4. Dlaczego teraz?
```

**Runda 2 — zakres i miary**
```
1. Co musi być w pierwszej wersji, żeby sprawdzić wartość?
2. Czego świadomie nie robimy na start?
3. Ograniczenia: techniczne, czasowe, zależności od innych zespołów i systemów?
4. Po czym poznamy, że działa? (miara sukcesu)
```

Po każdej rundzie czekaj na odpowiedzi. Pytanie, na które odpowiada już argument komendy,
pomijasz; braki dopytujesz konkretnie w rundzie 2.

### D2. Synteza (deleguj → `regent:architect`)

Przekaż w prompcie komplet odpowiedzi, kontekst (`ai/docs/`, `ai/specs/`, kod — jeśli istnieją;
projekt od zera → sam wywiad), format D3 i checklistę:

```
□ Problem przed rozwiązaniem — każdy kandydat ma personę i efekt mierzalny w kategoriach jej
  bólu z wywiadu; kandydat bez tego → wycięty albo w OPEN QUESTIONS
□ Kandydat 1 = walking skeleton: najcieńszy przekrój end-to-end, który sprawdza hipotezę MVP
  na personie z największym bólem
□ Fundament (auth, tenant, role, schemat) wchodzi w najmniejszym potrzebnym zakresie do
  pierwszego kandydata, który go używa; jego rozbudowa to kandydat z własnym efektem dla persony
□ MVP minimalne — reszta do „Out of scope" z powodem
□ Jeden kandydat = jedna zmiana SDD (propose → archive), przez wszystkie warstwy — warstwy
  dzielą taski ([BE]/[FE]/[DB]), nie kandydatów; rozmiar S/M/L wg tabeli budżetu
  w CLAUDE.md — kandydat większy niż L dzielisz
□ Słabe punkty pomysłu nazwane wprost — założenia bez dowodu z wywiadu to ryzyka
□ Zakres oceny: wykonalność produktowa i techniczna — pricing, CAC, LTV zostają po stronie użytkownika
```

`OPEN QUESTIONS` z raportu → zadaj je użytkownikowi i kontynuuj tego samego subagenta
(`SendMessage`) z odpowiedziami.

### D3. Wynik (raport w rozmowie)

```markdown
## Discovery: [inicjatywa] — Werdykt: BUDUJEMY / DOPRECYZUJ ([czego brakuje]) / NIE BUDUJEMY ([dlaczego])

**Problem:** [1-2 zdania] | **Persony:** [kto] | **Value proposition:** [1-2 zdania]

### Kandydaci na zmiany SDD
| # | Zmiana (kebab-case) | Dla kogo | Efekt (mierzalny) | Rozmiar | Zależy od |
|---|---------------------|----------|-------------------|---------|-----------|
| 1 | ... | ... | ... | S/M/L | — |

Kolejność: [dlaczego ta — max 3 punkty]

### Out of scope
- [co] — [dlaczego]

### Ryzyka i słabe punkty
- [ryzyko] — [co je zmniejsza]

### Wejście do /regent:propose (kandydat 1, gdy BUDUJEMY)
[pola jak w „Format output"]

### OPEN QUESTIONS
- [decyzje użytkownika — lub „brak"]
```

### D4. Handoff wg werdyktu

- **BUDUJEMY** → `/regent:propose {kandydat-1}` z blokiem „Wejście do /regent:propose"; projekt bez
  `ai/docs/` najpierw przechodzi `/regent:init` (w pustym repo — wywiad o stack).
  Kandydaci 2..N → tracker, gdy sesja ma go podłączonego — zasady jak w `/regent:propose` Krok 4
  (zgoda przez `AskUserQuestion`, lista przed utworzeniem); rodzic: ticket inicjatywy, jeśli
  użytkownik go poda. Klucze utworzonych zadań wypisujesz w raporcie. Bez trackera lista zostaje
  w raporcie.
- **DOPRECYZUJ** → braki, które użytkownik rozstrzyga od ręki, zamykasz przez `OPEN QUESTIONS`
  (kontynuacja subagenta, D2); braki wymagające danych z zewnątrz (rozmowy z użytkownikami,
  pomiary) → ponów `/regent:explore --discovery`, gdy dane będą.
- **NIE BUDUJEMY** → koniec; uzasadnienie zostaje w rozmowie.

---

## WAŻNE

- **Tryb read-only** — analiza kończy się raportem w rozmowie; pliki i commity powstają
  dopiero w `/regent:propose` (to barierka: `allowed-tools` nie zawiera Write/Edit)
- Jedyna akcja poza rozmową — eksport kandydatów do trackera w `--discovery` — dzieje się
  poza repo i za zgodą użytkownika
- Eksploracja jest bezpieczna i odwracalna

Timeline: 5-30 minut
