---
description: Atomic commits following the git workflow (format, pre-commit checks, approval)
disable-model-invocation: true
argument-hint: '[description]'
allowed-tools: Read, Grep, Glob, Bash
---

# /regent:commit — Prepare and make commits

**Goal:** Prepare and make atomic commit(s) following the git workflow.

```
/regent:commit [description]

Example:
/regent:commit
/regent:commit "add user registration"
```

---

## Agent (delegation)

No delegation — deliberately. This is a git operation (lint/format, `git add`, commit format and
execution) and none of the subagents improves it. Code hygiene is covered by `/regent:code-review`
and Stage 3 in `/regent:verify`. The whole command runs in the main session, with user approval.

---

## Step 1: Get the Jira key from the branch

```bash
git branch --show-current
```

Branch format: `<type>/<JIRA-KEY>-<name>`
Example: `feat/PROJ-123-http-error-handling`

**If the branch does not contain a key:**
→ Take the `Ticket` field from `proposal.md` of the change the commit belongs to (`ai/changes/{name}/`).
→ Not there either → ask: "What Jira key for this commit? (or NONE if there is none)"

---

## Step 2: Pre-commit checks

### 2a. Linting
```bash
make lint
```

If it fails → fix, then retry.

### 2b. Code quality
```bash
make type-check
make format
make test        # ← hard gate: `context/sdd.md` "Don't commit without tests — not even in a hotfix"
```

No `Makefile` / target → native equivalent from the stack (the `make` contract in `context/sdd.md`);
say explicitly what you used. `make test` fails → **STOP**, don't commit.

### 2c. Manual review checklist
```
□ No console.log left (debug code)?
□ No commented code?
□ No hardcoded secrets?
□ No .env files staged?
□ No generated files staged?
□ Every staged production code file has a test in THIS commit?
   → it doesn't: tell the user and justify the exception (config, docs, pure
     formatting change) or add a test. Don't stay silent about the gap.
```

---

## Step 3: Show status

```bash
git status
git diff --stat
```

---

## Step 4: Propose atomic commits

**One commit = one logical change:**

```
Instead of:
  git commit -m "feat: add user management"
  (50 changed files)

Split into:
  1. feat: (PROJ-123) add user entity and repository
  2. feat: (PROJ-123) add registration use case
  3. test: (PROJ-123) add user registration tests
  4. docs: (PROJ-123) update API documentation
```

Show the commit plan to the user. **Wait for approval.**

---

## Step 5: Commit format

Read `ai/docs/conventions/git-workflow.md` if it exists.

**Format:**
```
<type>: (<JIRA-KEY>) <description, imperative>
```

**Hard limits:**
- **Whole commit line: max 100 characters** (including `type`, key and description).
- **One line — NO body.** Do not add a description/details block below the subject.
- If the change needs a long description → that's a signal the commit is too big → split into atomic commits.

**Types:**
| Type | Usage |
|------|-------|
| feat | New functionality |
| fix | Bug fix |
| hotfix | Emergency fix in production (only from /regent:hotfix) |
| refactor | Refactoring (no behavior change) |
| test | Adding/fixing tests |
| chore | Dependencies, configuration, CI |
| docs | Documentation |
| perf | Performance optimization |

When there is no ticket (Step 1 → NONE): omit `(KEY)` — format `<type>: <description>`.

**Examples:**
```
feat: (PROJ-123) add global error handling middleware
fix: (PROJ-124) prevent duplicate user registration
refactor: (PROJ-125) extract auth service to separate module
```

---

## Step 6: Make the commits

**After user approval:**

```bash
# Add SPECIFIC files — listed by name
git add src/modules/users/domain/user.entity.ts tests/users/user.entity.test.ts

# Check what you added
git diff --cached --stat

# Commit
git commit -m "feat: (PROJ-123) add user entity with validation"

# Repeat for each atomic commit
```

---

## Step 7: Verify

```bash
git log --oneline -10
```

---

## Step 8: Push (ONLY if the user asks)

```bash
# ONLY after explicit user request
git push origin {branch-name}
```

---

## IMPORTANT Rules

✅ **ALWAYS:**
- Atomic commits (1 commit = 1 logical change)
- **One line, max 100 characters**: `type: (KEY) description` — descriptive, in the format
- Green `make test` before committing — also in a hotfix (`context/sdd.md`)
- User consent before `git commit`
  (exception: per-task commits in `/regent:apply` — consent given once, in Step 3 of /regent:apply)
- `git push` after an explicit user request

❌ **Guardrails** (no positive counterpart):
- `git add .` / `git add -A` — add the specified files
- `git commit --no-verify` — pre-commit hooks stay enabled

Timeline: 5-15 minutes
