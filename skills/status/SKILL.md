---
description: SDD project status overview — configuration, active changes, "where am I" after an interrupted session, archive, specifications
argument-hint: [--drift]
allowed-tools: Read, Grep, Glob, Bash(ls:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh:*)
---

# /regent:status — Project status overview

**Goal:** Show the current state of the project: configuration, active changes (with the cycle stage — "where am I"),
archive, specifications.

```
/regent:status            # overview
/regent:status --drift    # + audit: code changed outside the SDD cycle after archiving
```

---

## Agent (delegation)

No delegation — deliberately. This is a pure read: checking that `ai/docs/` files exist,
`ls` of active changes/archive/specs and heuristic suggestions. No reasoning that an
agent model could improve; it must be instant. Runs in the main session.

---

## Step 1: Configuration

```
## SDD configuration

### ai/docs/ (required):
✅ / ❌ ai/docs/stack/technology.md
✅ / ❌ ai/docs/patterns/architecture.md
✅ / ❌ ai/docs/conventions/naming.md
✅ / ❌ ai/docs/conventions/code-style.md
✅ / ❌ ai/docs/conventions/git-workflow.md

### ai/docs/ (optional):
✅ / ⬜ ai/docs/patterns/di-patterns.md
✅ / ⬜ ai/docs/patterns/testing-patterns.md
✅ / ⬜ ai/docs/patterns/exception-patterns.md
✅ / ⬜ ai/docs/patterns/logging-patterns.md
✅ / ⬜ ai/docs/patterns/frontend-patterns.md (only projects with a frontend)
✅ / ⬜ ai/docs/adr/ (optional — the architect's ADRs; not from /regent:init)
✅ / ⬜ ai/docs/observability/ (authored — Kibana dashboards/alerts; not from /regent:init)

### Status: CONFIGURED / PARTIALLY CONFIGURED / NOT CONFIGURED

If NOT CONFIGURED → "Run /regent:init"
```

---

## Step 2: Active changes

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh status      # one line per active change: Status, tasks x/y, verification verdict
```
Take the numbers in the table from the script output — do not count checkboxes yourself.

```
## Active changes

| Change | Type | Tasks | Status |
|--------|------|-------|--------|
| user-registration | feature | 4/5 done | 🟡 In Progress |

Details:
### user-registration (4/5 tasks)
- [x] T-01: Create user entity
- [x] T-02: Create user repository
- [ ] T-05: [BE] Registration E2E — REQ-001, REQ-002 — verification: E2E test green

→ /regent:apply user-registration --tasks 5
```

If there are no active changes:
```
No active changes.
→ /regent:propose — create a new change
```

---

## Step 3: Archive

```bash
ls ai/changes/archive/
```
(show the 5 newest — sort by the date prefix in the directory name)

```
## Archive (last 5)

| Date | Change | Type |
|------|--------|------|
| 2025-03-18 | setup-project-structure | feature |
| 2025-03-15 | initial-auth | feature |
```

---

## Step 3.7: Where am I? (detecting the change state)

For EACH active change determine the cycle stage **from the files on disk** — no separate state file.
This is the rescue after an interrupted session: the user does not have to remember where they left off.

| Signal on disk | Stage | Next step |
|---|---|---|
| no `proposal.md` | change incomplete | `/regent:propose {name}` from scratch (or delete the directory) |
| `Status: Draft` | proposal awaits acceptance | read the files → `approve` in `/regent:propose` |
| `Status: Rejected` | rejected at the proposal stage | `/regent:archive {name} --abandon` or `/regent:propose` with a new approach |
| `Status: Approved`, 0 tasks `[x]` | ready for implementation | `/regent:apply {name}` |
| some tasks `[x]` | implementation in progress | `/regent:apply {name} --tasks {first unchecked}` |
| all `[x]`, no `verification.md` | implemented, unverified | `/regent:verify {name}` |
| `verification.md` = FAIL | verification failed | see "FAIL path" in `/regent:verify` (giving up → `/regent:archive {name} --abandon`) |
| `verification.md` = PASS | ready to close | `/regent:archive {name}` |

**Code drift relative to verification (soft warning):** when `verification.md` has PASS,
run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh drift {name}`. WARN (a file from Affected Files changed since `Commit HEAD`) →
"⚠️ the change's code moved after verification — consider re-running `/regent:verify {name}`".

**Interrupted task (the most common case after an interrupted session):** a task is checked off only after
the commit (`/regent:apply` 4c), so for the first unchecked task check two states:
```
⚠️ {name}: T-04 — there is a commit after the last recorded (commit: …) that touches the task's files
   → the commit succeeded, the trace is missing: append ✅ (commit: … · tests: …) instead of repeating the task.
⚠️ {name}: T-04 — uncommitted changes in files from Affected Files (git status)
   → work in progress: finish the task (tests green) and commit, instead of starting over.
```

---

## Step 3.8: Spec/code divergence (only `/regent:status --drift`)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh stale      # commits touching files of archived changes, absent from every tasks.md
```
Each WARN is code changed outside your SDD cycle — a hotfix without follow-up, a manual fix
or a colleague's work outside the SDD cycle (a change made through SDD also shows up in `ai/changes/`). Your domain main spec
may have stopped describing the truth → update it (`/regent:propose` for a behavior change,
`/regent:bugfix` for a bug). The script recognizes a squash without a ticket key by file contents —
when the cycle's local hashes are gone (gc, another machine), the WARN may be false. Without the `--drift` flag
skip this step (it is an audit, not a read).

## Step 4: Specifications

```bash
ls ai/specs/ 2>/dev/null
```

```
## Specifications

| Domain | File | Last change |
|--------|------|-------------|
| Users | ai/specs/users.md | 2025-03-18 |
| Auth | ai/specs/auth.md | 2025-03-15 |
```

---

## Step 5: Suggestions

```
## Suggestions

Based on the project state:
1. [suggestion — e.g. "user-registration has 1 pending task → /regent:apply"]
2. [suggestion — e.g. "ai/docs/patterns/testing-patterns.md empty → fill it in"]
```

---

Timeline: 1-2 minutes
