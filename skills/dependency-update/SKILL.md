---
description: Aktualizacja zależności i security patches (audyt, kategoryzacja, adaptacja kodu)
disable-model-invocation: true
argument-hint: [security-only|all|specific <pkg>]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:dependency-update — Aktualizacja zależności i łatek

**Cel:** Aktualizuj zależności, security patches, version bumps.

```
/regent:dependency-update [scope]

Przykład:
/regent:dependency-update security-only
/regent:dependency-update all
/regent:dependency-update specific express
```

---

## Agenci (delegacja — WYMAGANE)

- Ocenę podatności (🔴 CRITICAL z `make deps-audit`: czy exploit dotyczy sposobu, w jaki
  projekt używa pakietu) deleguj do subagenta `regent:security-auditor` (model: opus, Task).
- **Kategoryzację 🟡/🟢 robi sesja główna** — major vs minor/patch to mechaniczny odczyt
  `make deps-outdated`, nie zadanie dla opusa.
- Adaptację kodu do breaking changes (krok 5) deleguj do dev-agenta wg pakietu:
  zależność backendowa → `regent:backend-dev`, frontendowa → `regent:frontend-dev` (sonnet, Task).

Skanowanie/instalacja (`make deps-*`) i commity to operacje mechaniczne — bez delegacji.

---

## Workflow

### 1. Scan

```bash
make deps-outdated
make deps-audit
```

### 2. Categorize

```
🔴 CRITICAL (Security vulnerabilities)
- Package X: [vulnerability] → Update ASAP

🟡 IMPORTANT (Major version updates)
- Package Y: v1.x → v2.x → Breaking changes: [list]

🟢 OPTIONAL (Minor/patch updates)
- Package Z: v1.2.0 → v1.2.5 → Safe to update
```

### 3. Update

```bash
git checkout -b chore/update-deps

# Security fixes
make deps-audit-fix

# Specific package
make deps-update PKG=package-name
# or major version
make deps-upgrade PKG=package-name
```

### 4. Test

```bash
make install
make check
make build
```

### 5. Check breaking changes

```
| Change | Old → New | Impact | Fix |
|--------|-----------|--------|-----|
| [API change] | [old] → [new] | [files] | [what to update] |
```

### 6. Commit

Format commitów wg `/regent:commit` (`<type>: (<KEY>) <opis>`; bez ticketu → bez `(KEY)`):

```bash
git add package.json package-lock.json
git commit -m "chore: (KEY) update dependencies with security patches"

# If code changes needed
git add src/...
git commit -m "refactor: (KEY) update code for express v5 API changes"
```

### 7. Verify

```
□ All tests pass
□ Build succeeds
□ No security warnings
□ Monitor after deploy
```

---

## Security update priority

```
1. Identify → make deps-audit
2. Update → make deps-update PKG=...
3. Test → make test
4. Deploy → ASAP
5. Monitor → watch logs
```

---

## Tips

- **Security first** — critical vulnerabilities are urgent
- **Test after update** — breaking changes happen
- **Lock versions** — use package-lock.json
- **Update regularly** — don't wait for emergencies
- **Review changelogs** — understand what changed

Timeline: 1-4 godziny
