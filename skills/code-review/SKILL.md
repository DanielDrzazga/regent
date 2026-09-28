---
description: Peer code review zmian (architektura, jakość, testy, wydajność) przez agenta code-reviewer
argument-hint: [--branch <branch>] [--scope <path>] [--files <lista>]
allowed-tools: Task, Read, Grep, Glob, Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(git branch:*)
---

# /regent:code-review — Przegląd zmian w kodzie

**Cel:** Przeprowadź peer code review sprawdzając architekturę, jakość, testy, wydajność.

```
/regent:code-review [opcje]

Opcje:
  --branch <branch>     Review konkretnego brancha
  --scope <path>        Review konkretnego katalogu/pliku
  --files <lista>       Review konkretnych plików

Przykład:
/regent:code-review
/regent:code-review --branch feat/PROJ-123-user-registration
/regent:code-review --scope src/modules/users/
```

---

## Agent (delegacja — WYMAGANE)

Cały przegląd deleguj do subagenta `regent:code-reviewer` (model: opus, uruchom narzędziem Task).
Nie rób review „w miejscu" w głównej sesji — inaczej model z `agents/code-reviewer.md`
nie zostanie użyty.

---

## Krok 1: Określ zakres

```bash
# Baza porównania: default branch z ai/docs/conventions/git-workflow.md;
# fallback: git symbolic-ref refs/remotes/origin/HEAD (main LUB master — nie zakładaj)

# Jeśli --branch
git diff {default-branch}..{branch} --stat

# Jeśli --scope
git diff --stat -- {scope}

# Jeśli brak opcji
git diff --stat                    # unstaged
git diff --cached --stat           # staged
```

---

## Krok 2: Przeczytaj kontekst

Subagent `regent:code-reviewer` czyta **bezpośrednio przez Read**:
```
1. ai/docs/patterns/architecture.md
2. ai/docs/conventions/naming.md
3. ai/docs/conventions/code-style.md
4. ai/docs/patterns/testing-patterns.md (jeśli istnieje)
```

Następnie czytaj **tylko zmienione pliki** z `git diff --name-only` — NIE skanuj całego src/.

**Plan zmiany** (sekcja 7 checklisty `regent:code-reviewer` — zgodność z planem):
- własna zmiana SDD → agent czyta `ai/changes/{nazwa}/` (design, delta, tasks);
- cudzy MR → `ai/` autora jest lokalny, więc przekaż agentowi w prompcie **opis MR** (cel,
  wymagania z AC, decyzje, odstępstwa) jako plan; brak opisu → review bez sekcji 7 i jedno
  zdanie o tym w raporcie.

---

## Krok 3: Review checklist

Checklista (architektura, jakość, security sanity-check, spec compliance, wydajność,
git hygiene) jest w definicji agenta `regent:code-reviewer` — **jedno źródło, nie duplikuj jej
tutaj**. Głęboki przegląd bezpieczeństwa to `/regent:verify` Etap 6 (`regent:security-auditor`),
a strategia testów — `/regent:testing` (`regent:qa-engineer`).

---

## Krok 4: Raport

```markdown
## Code Review: [branch/scope]

### 🔴 CRITICAL (musi być naprawione przed merge)
1. **[Issue]** — `file:line`
   Sugestia: [jak naprawić]

### 🟡 WARNING (powinno być naprawione)
1. **[Issue]** — `file:line`

### 🔵 SUGGESTION (opcjonalne ulepszenie)
1. **[Issue]** — `file:line`

### ✅ PRAISE (co jest dobrze zrobione)
1. [Co dobrze]

---

### Verdict: PASS ✅ / WARN 🟡 / BLOCK 🔴
```

---

## Tips

- **Be constructive** — sugeruj rozwiązania, nie tylko krytykuj
- **Pick battles** — nie komentuj każdego drobiazgu
- **Security first** — zawsze sprawdzaj security issues

Timeline: 15-30 minut
