---
description: Implement the tasks of an active change (TDD Red → Green → Refactor)
disable-model-invocation: true
argument-hint: <change-name> [--tasks 1,3,5] [--group Setup]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:apply — Implement a change

**Goal:** Implement the tasks of an active change, applying TDD and the project conventions.

```
/regent:apply <change-name> [options]

Options:
  --tasks 1,3,5        Specific tasks (T-01, T-03, T-05)
  --group Setup         Task group

Example:
/regent:apply user-registration
/regent:apply user-registration --tasks 1,2,3
```

---

## Agents (delegation — REQUIRED)

This command MUST run through subagents (launch them with the Task tool) to use their models:

| Subagent (`name`) | Model | Role in the command |
|-------------------|-------|---------------------|
| `regent:backend-dev` | sonnet | `[BE]` / untagged tasks (TDD: Red → Green → Refactor) |
| `regent:frontend-dev` | sonnet | `[FE]` tasks (component TDD; requires `frontend-patterns.md`) |
| `regent:dba` | sonnet | `[DB]` tasks — migrations/schema |

**Task routing by tags from tasks.md:** `[FE]` → `regent:frontend-dev`, `[DB]` → `regent:dba`,
`[BE]` or no tag → `regent:backend-dev`. Full-stack change: the API↔UI contract is in design.md,
so BE and FE can proceed independently (FE mocks HTTP per the contract) — BE first by default,
respect the `(after T-XX)` dependencies.

❗ Do not implement "in place" in the main session — **delegate to the subagent by its exact `name`**.
Otherwise the models from `agents/*.md` will not be used.

**Budget:** S: 1 run, M: 1-3, L: 3-6. Tasks of the same layer that do not share files →
**one agent run with a list of tasks**; tasks changing the same files → separate runs,
one after another, because otherwise the commits cannot be separated.

**One run = a new subagent.** Every run goes to a new subagent. Do not send the next task or
round — including fixes after `/regent:verify` — via `SendMessage` to an agent that has already
reported: a continued agent carries its whole history, its context grows with every task
(measured: 17k → 494k over 13 tasks), and after a pause the cache is written from scratch. Continuation
(resume by agentId) only with answers to `OPEN QUESTIONS` or with a fix to the same tasks
before the commit.

**Split of roles:** the implementing agent ITSELF runs the tests in the TDD loop (narrowly — only the tests
of the module/component being changed). The MAIN SESSION commits after each task, based on the
subagent's report (files per task).
If the report contains `OPEN QUESTIONS` → ask the user and
continue the same subagent (resume by agentId) with the answers. Append the answer as a
`DECISION` in `proposal.md` → `## Decisions and assumptions`.

---

## Step 0: Validation

```
Check:
□ ai/changes/{name}/ exists
□ proposal.md has status: Approved
□ specs/*.md exist
□ design.md exists
□ tasks.md exists
□ bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {name} → no ERROR (task and delta format)

If missing → "Run /regent:propose {name} first"
```

An ERROR from `sdd-check change` is an artifact format error, not a missing proposal: show the result and fix
the artifact (minor error — yourself, conceptual — resume `regent:spec-writer`), without rerunning `/regent:propose`.

---

## Step 1: Read the context (ONLY the needed files!)

The implementing subagent reads **directly with the Read tool** — scope per agent:

```
ALWAYS (every implementing agent: backend-dev / frontend-dev / dba):
1. ai/changes/{name}/tasks.md
2. ai/changes/{name}/design.md
3. ai/changes/{name}/specs/*.md
4. ai/docs/stack/technology.md
5. ai/docs/conventions/code-style.md

backend-dev — CONTEXTUALLY (Read only when actually needed):
- ai/docs/patterns/architecture.md — only when you create a new module/layer
- ai/docs/conventions/naming.md — only when you create new files/classes
- ai/docs/patterns/di-patterns.md — only for new classes with DI
- ai/docs/patterns/testing-patterns.md — only when you write tests
- ai/docs/patterns/exception-patterns.md — only for error handling

frontend-dev — ALWAYS additionally:
- ai/docs/patterns/frontend-patterns.md   ← source of truth on the UI stack (missing → STOP, see agent)
CONTEXTUALLY:
- ai/docs/conventions/naming.md — new files/components
- ai/docs/patterns/testing-patterns.md (UI tests section) — when you write tests
```

---

## Step 2: Check the environment (MAIN SESSION)

```
Run: make check
If anything fails → fix it BEFORE implementation (the baseline must be green).
```

No `Makefile` / `check` target → the native equivalent from the stack (the `make` contract in `context/sdd.md`);
say explicitly what you used. The baseline must be green regardless of the tool.

---

## Step 3: Select tasks

```
If --tasks given:
  → Filter only the indicated tasks
If --group given:
  → Filter the tasks of the given group
Otherwise:
  → All tasks in order
```

Show the user concisely:
```
Tasks: T-01, T-02, T-03 (from tasks.md)
After each task I make an atomic commit. Start? (yes/no)
```

Consent here covers the per-task commits (an explicit exception to the `/regent:commit` gate).

---

## Step 4: Implementation (per task)

### 4a. TDD Workflow (subagent per the task tag: `regent:backend-dev` / `regent:frontend-dev`)

```
1. 🔴 RED — Write a failing test for the task's `verification` and RUN it (it must fail for the expected reason)
   → Task without AC (Setup, configuration): the verification is the task's command, no RED phase
   → BE: shared mocks/factories per testing-patterns.md
   → FE: component test (render + interaction + visible behavior), HTTP mock per
     frontend-patterns.md — contract from design.md
   → If a needed helper is missing — create it

2. 🟢 GREEN — Write the minimal code, run the test (it must pass)

3. 🔵 REFACTOR — Improve code quality (MANDATORY!), tests still green
   → Names, structure, duplication, readability
   → This is the moment for quality!

Run tests NARROWLY (module/file/component) — the full make check is in /regent:verify.
```

**One vertical slice per cycle: one seam, one test, minimal implementation.** Write the next test
only after the previous one is green — each is a tracer bullet that responds to what
the previous cycle taught. Tests written in bulk before implementation describe imagined
behavior (anti-patterns: `regent:qa-engineer`).

**REFACTOR belongs to this cycle, not to review** — after the green test, before the next one.

### 4b. Atomic commit (MAIN SESSION, after the subagent's report)

Condition: the implementing agent's report confirms GREEN (test run results).
For `[DB]` tasks the GREEN equivalent is the "Test results" section of the `regent:dba` report
(migration up/down/up + module tests) — see `agents/dba.md`.

```bash
# Add the SPECIFIC files listed in the subagent's report
git add src/modules/users/domain/user.entity.ts
git add tests/modules/users/domain/user.entity.test.ts

git commit -m "feat: (KEY) create user entity with validation"
```

Do the commit (format: `context/sdd.md` → Commit) and step 4c in a single Bash call (hash from `git rev-parse --short HEAD`).

### 4c. Update tasks.md (MAIN SESSION, after the task commit)

`ai/` is tracked in the repo. Append the task trace after the commit: the hash and the test that
checks its AC (from the dev report):

```markdown
- [x] T-01: [BE] Create user entity — REQ-001/AC-1, AC-2 — … ✅ (commit: abc1234 · tests: AC-1 → tests/users/user.entity.test.ts › rejects empty email; AC-2 → … › trims name)
- [ ] T-02: [BE] Create user repository — REQ-001/AC-2 — …
```

After editing `tasks.md` add a second, short commit: `git add ai/changes/{name}/tasks.md &&
git commit -m "docs: check off T-01 in tasks.md"`. Two commits per task (code and tests, then the
trace) — the hash must exist before the trace quotes it.

By the hash (and the `ai/changes/` paths) `sdd-check diff/stale` tells cycle commits from changes
outside SDD; by the `tests:` mapping the reviewer in `/regent:verify` finds the test of every AC.

---

## Step 4.5: Change of course — when implementation undermines the plan

Signal: `OPEN QUESTIONS` with the `SCOPE:` prefix in the dev report, or your own discovery that
the approved plan does not fit the code. Classify the discovery before you change anything:

| Discovery | Action |
|---|---|
| Concerns only the code (different structure, same effect) | continue — artifacts unchanged |
| Changes the tasks (order, split, new technical task) | edit tasks.md + a `DECISION` entry |
| Changes behavior (AC/REQ) or a decision from design.md | **AMEND** (below) |
| Changes the goal of the change | stop: `/regent:archive {name} --abandon` + a new `/regent:propose`, or narrow the change to what is done and split the rest into a new one |

**AMEND:**
1. Show the user (`AskUserQuestion`): what in the plan does not hold up, the proposed AC/design change
   with a recommendation, an alternative variant. The decision belongs to the user.
2. After consent: minor fix → you edit the delta / design.md directly; conceptual → resume
   `regent:spec-writer` / `regent:architect`.
3. An `AMEND` entry in `proposal.md` → `## Decisions and assumptions` (what, why). The status stays
   `Approved` — the consent from point 1 is the acceptance of the fix.
4. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {name}` and `preflight {name}` — the fixed
   delta must still be mergeable.

The spec at the end of `/regent:apply` tells the truth about the code — it is what goes through `/regent:archive` into the source of truth.

---

## Step 5: Status report (concise!)

```markdown
## Apply: {name} — Done

Tasks: 3/3 ✅
Commits: abc1234, def5678, ghi9012

→ /regent:verify {name}
```

**Do not repeat the artifact content.** The developer has it in the files.

---

## IMPORTANT Rules

❌ **Guardrail:** `git add` only with a list of files — `git add .` and `git add -A` pull other people's
changes into the change's commit.

❌ **Guardrail:** no next task or round via `SendMessage` to an agent that has already reported — a new
run goes to a new subagent (Agents → "One run = a new subagent").
