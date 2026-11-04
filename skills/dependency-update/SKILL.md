---
description: Dependency updates and security patches (audit, categorization, code adaptation)
disable-model-invocation: true
argument-hint: [security-only|all|specific <pkg>]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:dependency-update — Dependency and patch updates

**Goal:** Update dependencies, security patches, version bumps.

```
/regent:dependency-update [scope]

Example:
/regent:dependency-update security-only
/regent:dependency-update all
/regent:dependency-update specific express
```

---

## Agents (delegation — REQUIRED)

- Delegate the vulnerability assessment (🔴 CRITICAL from `make deps-audit`: whether the exploit affects the way
  the project uses the package) to the `regent:security-auditor` subagent (model: opus, Task).
- **The main session does the 🟡/🟢 categorization** — major vs minor/patch is a mechanical reading of
  `make deps-outdated`, not a task for opus.
- Delegate code adaptation to breaking changes (step 5) to a dev agent by package:
  backend dependency → `regent:backend-dev`, frontend → `regent:frontend-dev` (sonnet, Task).

Scanning/installation (`make deps-*`) and commits are mechanical operations — no delegation.

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

Commit format per `/regent:commit` (`<type>: (<KEY>) <description>`; no ticket → no `(KEY)`):

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

Timeline: 1-4 hours
