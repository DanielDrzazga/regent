---
description: Emergency fix in production — minimal change (max 3 files), fast deploy, monitoring, rollback plan
disable-model-invocation: true
argument-hint: <problem-description>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:hotfix — Urgent production fix

**Goal:** Emergency fix — minimal change, fast deploy, monitoring after the fix.

```
/regent:hotfix <problem-description>

Example:
/regent:hotfix "payment endpoint returns 500 for all users"
/regent:hotfix "authentication bypass on admin panel"
```

---

## Agent (delegation — REQUIRED)

Despite emergency mode, a production fix requires quality — delegate the implementation (reproducing test
+ minimal change) to a dev agent **by bug area**: backend code → `regent:backend-dev`,
frontend code → `regent:frontend-dev` (model: sonnet, Task tool). Bug at the boundary → root cause
on ONE side. Don't do it "in place" in the main session.

---

## ⚠️ SCOPE GUARD

```
A hotfix MUST be:
□ Max 3 files changed
□ Max 2 modules touched
□ Implementation time: < 30 minutes

If it exceeds that → "This is not a hotfix. Use /regent:bugfix."
```

---

## Step 1: Read the conventions

```
Read:
- ai/docs/conventions/git-workflow.md
- ai/docs/patterns/architecture.md

No ai/docs/ (project without SDD)? → do NOT block the incident: infer the conventions
from git log -10 and the repo structure, carry on.
```

---

## Step 2: Create a branch

```bash
git checkout -b hotfix/{KEY}-{short-description}
# or if there is no ticket:
git checkout -b hotfix/{YYYY-MM-DD}-{short-description}
```

---

## Step 3: Quick Root Cause

```
## Root Cause (quick analysis)

### Symptom
[What happens — error message, behavior]

### Cause
[Why — quick analysis]

### Fix
[What we change — minimal change]

### Risk
[Risk of the fix — what can go wrong]
```

---

## Step 4: Implementation

Delegate → dev agent by root cause area (`regent:backend-dev` / `regent:frontend-dev` — see the
"Agent (delegation)" section); it runs the tests itself, the main session makes the commit:

```
1. Write a test reproducing the problem
2. Fix the bug (MINIMAL change!)
3. Verify: the test passes
4. Verify: other tests pass
```

```bash
make test   # no Makefile → native test runner from the stack (the `make` contract in `context/sdd.md`).
            # A production incident is NOT a reason to skip the test — it is a reason to narrow it.

# Single atomic commit (hotfix type — see the types table in /regent:commit)
git add [specific files]
git commit -m "hotfix: (KEY) fix payment endpoint 500 error"
```

---

## Step 5: Deploy

```
⚠️ WAIT FOR USER CONFIRMATION

Deploy ready:
□ Test passes
□ Lint passes
□ Single commit
□ Max 3 files

Push? (yes/no)
```

```bash
# After approval
git push origin hotfix/{branch-name}
```

Deployment: per the organization's established deploy process (outside the SDD scope).

---

## Step 6: Post-fix

```
After deploy:
□ Monitor logs (15 minutes)
□ Verify the fix in production
□ Root cause analysis (thorough — follow-up via /regent:bugfix, see IMPORTANT)
□ Regression test added permanently
```

---

## Step 7: Rollback (when the fix doesn't work)

```
Rollback criteria (any of them):
□ The symptom still occurs after deploy
□ NEW errors in the logs after deploy
□ Metrics degradation (error rate, latency)

Procedure:
1. git revert {hotfix-commit} → push → redeploy per the established deploy process
   (the user confirms the redeploy decision)
2. Inform: rollback done, production in the state before the fix
3. Back to analysis → another /regent:hotfix iteration or escalation to /regent:bugfix
   (if the problem requires > 3 files / a deeper change — it's not a hotfix)
```

---

## IMPORTANT

- **Speed > perfection** — fix, deploy, then a proper fix
- **Minimal** — don't refactor, don't improve
- **Monitor** — watch after deploy; rollback prepared (Step 7)
- **Follow up** — always: root cause + regression + artifacts via `/regent:bugfix`
  (and when a proper fix needs a bigger change — a full `/regent:propose`)
- **Commit after a green test** — here too; a hotfix shortens the artifacts, not the tests

Timeline: 15-30 minutes MAX
