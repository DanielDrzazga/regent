---
description: Emergency fix na produkcji — minimalna zmiana (max 3 pliki), szybki deploy, monitoring, plan rollbacku
disable-model-invocation: true
argument-hint: <opis-problemu>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:hotfix — Pilny fix na produkcji

**Cel:** Emergency fix — minimalna zmiana, szybki deploy, monitoring po fix.

```
/regent:hotfix <opis-problemu>

Przykład:
/regent:hotfix "payment endpoint returns 500 for all users"
/regent:hotfix "authentication bypass on admin panel"
```

---

## Agent (delegacja — WYMAGANE)

Mimo trybu awaryjnego fix produkcyjny wymaga jakości — implementację (test reprodukujący
+ minimalna zmiana) deleguj do dev-agenta **wg obszaru buga**: kod backendu → `regent:backend-dev`,
kod frontendu → `regent:frontend-dev` (model: sonnet, narzędzie Task). Bug na styku → root cause
po JEDNEJ stronie. Nie rób tego „w miejscu" w głównej sesji.

---

## ⚠️ SCOPE GUARD

```
Hotfix MUSI być:
□ Max 3 pliki zmienione
□ Max 2 moduły dotknięte
□ Czas implementacji: < 30 minut

Jeśli przekracza → "To nie jest hotfix. Użyj /regent:bugfix."
```

---

## Krok 1: Przeczytaj konwencje

```
Przeczytaj:
- ai/docs/conventions/git-workflow.md
- ai/docs/patterns/architecture.md

Brak ai/docs/ (projekt bez SDD)? → NIE blokuj awarii: konwencje wywnioskuj
z git log -10 i struktury repo, działaj dalej.
```

---

## Krok 2: Utwórz branch

```bash
git checkout -b hotfix/{KEY}-{short-description}
# lub jeśli brak ticket:
git checkout -b hotfix/{YYYY-MM-DD}-{short-description}
```

---

## Krok 3: Quick Root Cause

```
## Root Cause (quick analysis)

### Symptom
[Co się dzieje — error message, behavior]

### Cause
[Dlaczego — szybka analiza]

### Fix
[Co zmieniamy — minimalna zmiana]

### Risk
[Ryzyko fixa — co może pójść nie tak]
```

---

## Krok 4: Implementacja

Deleguj → dev-agent wg obszaru root cause (`regent:backend-dev` / `regent:frontend-dev` — patrz sekcja
„Agent (delegacja)"); sam uruchamia testy, commit robi sesja główna:

```
1. Napisz test reprodukujący problem
2. Napraw bug (MINIMALNA zmiana!)
3. Verify: test przechodzi
4. Verify: inne testy przechodzą
```

```bash
make test   # brak Makefile → natywny runner testów ze stacku (kontrakt `make` w CLAUDE.md).
            # Awaria produkcyjna NIE jest powodem, by pominąć test — jest powodem, by go zawęzić.

# Single atomic commit (typ hotfix — patrz tabela typów w /regent:commit)
git add [specific files]
git commit -m "hotfix: (KEY) fix payment endpoint 500 error"
```

---

## Krok 5: Deploy

```
⚠️ CZEKAJ NA POTWIERDZENIE UŻYTKOWNIKA

Deploy ready:
□ Test przechodzi
□ Lint przechodzi
□ Single commit
□ Max 3 pliki

Push? (tak/nie)
```

```bash
# Po zatwierdzeniu
git push origin hotfix/{branch-name}
```

Wdrożenie: wg obowiązującego w organizacji procesu deploy (poza zakresem SDD).

---

## Krok 6: Post-fix

```
Po deploy:
□ Monitor logs (15 minut)
□ Verify fix w production
□ Root cause analysis (dokładna — follow-up przez /regent:bugfix, patrz WAŻNE)
□ Regression test dodany permanentnie
```

---

## Krok 7: Rollback (gdy fix nie działa)

```
Kryteria rollbacku (którekolwiek):
□ Symptom nadal występuje po deploy
□ NOWE błędy w logach po deploy
□ Pogorszenie metryk (error rate, latency)

Procedura:
1. git revert {commit-hotfixa} → push → redeploy wg obowiązującego procesu deploy
   (decyzję o redeploy potwierdza użytkownik)
2. Poinformuj: rollback wykonany, produkcja w stanie sprzed fixa
3. Wróć do analizy → kolejna iteracja /regent:hotfix lub eskalacja do /regent:bugfix
   (jeśli problem wymaga > 3 plików / głębszej zmiany — to nie jest hotfix)
```

---

## WAŻNE

- **Speed > perfection** — napraw, deploy, potem proper fix
- **Minimal** — nie refaktoruj, nie ulepszaj
- **Monitor** — obserwuj po deploy; przygotowany rollback (Krok 7)
- **Follow up** — zawsze: root cause + regresja + artefakty przez `/regent:bugfix`
  (a gdy proper fix wymaga większej zmiany — pełny `/regent:propose`)
- **Commit po zielonym teście** — także tutaj; hotfix skraca artefakty, nie testy

Timeline: 15-30 minut MAX
