---
description: 9-stage verification of a change (tests, spec compliance, review, DB, security, smoke) + writing verification.md
disable-model-invocation: true
argument-hint: <change-name>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:verify — Verify a change

**Goal:** 9-stage verification of a change (stages 5-8 conditional): automated tests, spec compliance, code review, test verification, DB, security, observability, smoke check, repo release readiness. The result is persisted in `verification.md`.

```
/regent:verify <change-name>

Example:
/regent:verify user-registration
```

---

## Agents (delegation — REQUIRED)

This command MUST run through subagents (launch them with the Task tool) to use their models:

| Stage | Subagent (`name`) | Model |
|-------|-------------------|-------|
| 2, 3 | `regent:code-reviewer` | opus |
| 4 | `regent:qa-engineer` | sonnet |
| 5 (if DB) | `regent:dba` | sonnet |
| 6 (if security) | `regent:security-auditor` | opus |

❗ Delegate each stage to the right subagent **by its exact `name`** — do not analyze "in place"
in the main session, because the models from `agents/*.md` will not be used then.

**Budget:** S: 1-2 runs, M: 2-4, L: 4-6 (table in `context/sdd.md`). Stages 2 and 3 are the same
agent (`regent:code-reviewer`) → **one run with both tasks**, not two separate ones.
Run conditional stages (5, 6, 8) only when their trigger is met — not "just in case".

Verifying subagents are **read-only** — they do not fix the problems they find.

---

## Step 0: Find the change

Read **directly with Read**:

```
ai/changes/{name}/proposal.md
ai/changes/{name}/specs/*.md
ai/changes/{name}/design.md   (for /regent:bugfix: simplified design.md — also required)
ai/changes/{name}/tasks.md

If missing → "Change not found. Use /regent:status to see active changes."
```

Compute the facts for Stages 2-4 with the script before you delegate:
```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {name}   # tasks x/y, AC without a task — ERROR → Stage 9 ❌
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh diff {name}     # removed/disabled tests, fewer assertions, files outside Affected Files
```
`diff` without a base (ERROR "no comparison base") → pass it explicitly: `diff {name} $(git merge-base HEAD <main branch>)`.
Pass the `diff` result in the prompt to `regent:code-reviewer` and `regent:qa-engineer` as **facts to assess**, not a
verdict: a test edit can be justified, and a file outside Affected Files is a candidate for `unrequested`.

**DO NOT scan src/** — read only the code files listed in design.md → "Affected Files".

---

## Stage 1: Automated tests (the MAIN SESSION runs them)

```
Run:
→ make lint
→ make type-check
→ make test
→ make test-coverage
```

**If ANYTHING fails → STOP.**
```
❌ STAGE 1 FAILED — fix the errors BEFORE continuing (see "FAIL path").
```

---

## Stage 2: Spec Compliance (delegate → `regent:code-reviewer`)

The AC → implementation → test mapping (plus the INVARIANTS table for refactors) and the rule
"AC without a test = at most ⚠️ PARTIAL" are in the `regent:code-reviewer` agent definition —
**one source, do not duplicate them here**. The agent returns both tables in its report.

---

## Stage 3: Code Review (delegate → `regent:code-reviewer`)

The checklist (architecture, quality, performance, git hygiene) is in the
`regent:code-reviewer` agent definition — **one source, do not duplicate it here**. In the prompt additionally pass
the project-dependent items:

```
□ Logs per the pattern — key operations/errors logged (logging-patterns.md), no PII
  (optional — only if the project has ai/docs/patterns/logging-patterns.md with status "deployed")
□ Observability sync — if the change adds/changes/removes an `action`, check maintenance.md
  (conditional — only if ai/docs/observability/ exists; see Stage 7)
```

---

## Stage 4: Test Verification (delegate → `regent:qa-engineer`)

The checklist (test pyramid, AC coverage, mocks-first, coverage vs target, UI tests, flaky)
is in the `regent:qa-engineer` agent definition — **one source, do not duplicate it here**.

---

## Stage 5: Database Review (delegate → `regent:dba` — if applicable)

```
Trigger: design.md contains a NON-EMPTY "Database Changes" section
(unused sections are removed in /regent:propose — no section or "no changes" → N/A)
```

The checklist (backward compatibility, indexes, foreign keys, rollback, query performance)
is in the `regent:dba` agent definition — **one source, do not duplicate it here**.

---

## Stage 6: Security Review (delegate → `regent:security-auditor` — if applicable)

```
Trigger: the change touches auth/permissions, processes NEW user input, adds a public
endpoint, touches sensitive data, OR (frontend) renders user content in the UI /
handles tokens in the UI / adds frontend dependencies, OR design.md has a non-empty
"Security Considerations" section. A purely internal change with no new inputs and pure
styling/layout → N/A (do not launch the security-auditor "just in case" — it is opus, it costs).
```

The checklist (OWASP Top 10 + conditional frontend section) is in the
`regent:security-auditor` agent definition — **one source, do not duplicate it here**.

---

## Stage 7: Observability Sync (conditional)

```
Trigger: ai/docs/observability/ exists AND the change adds/renames/removes
a logged `action` (or changes `type`/`module`).

Source: ai/docs/observability/maintenance.md (maintenance checklist)

□ Does the change add / rename / remove a logged `action`?
□ If so — do the dashboard (kibana-dashboard.md) and alerts need updating?
   (Filters panels have the `action` list hardcoded — they will not update themselves)
□ Does a new critical error `action` deserve an alert?
□ Does the `type`/`module` change not break the panels' base filters?

This is a reflection, not a work obligation — if no point applies, N/A.
No ai/docs/observability/ → N/A.
```

---

## Stage 8: Smoke Check — does it actually work? (conditional)

> **Why:** stages 1-7 check tests, spec, code, DB, security and logs — but nobody
> runs the application. A change can have a full set of green tests and not work for the user
> (bad DI wire-up, missing route registration, broken build, mock diverged from the real API).
> This is the last moment to catch it before release.

```
Trigger: the change touches the UI, an HTTP endpoint or a runnable entry point (CLI, worker, job).
A purely internal refactor with no change to inputs, a change to tests or documentation only → N/A.
```

**Scope: happy path, not regression.** This is NOT E2E — those are in Stage 4. Here it is about
one question: does the main path of the change live in the running application.

```
□ Build passes (make build — or the native equivalent)
□ The application starts without errors in the startup logs
□ The Smoke scenario from design.md → Testing Strategy executed MANUALLY and confirmed
  (no scenario → happy path of the first REQ from the delta):
   → API: request (curl/httpie) → expected status + response shape
   → UI:  the screen renders, the main interaction works
   → CLI/worker: the command/job finishes successfully
□ No new ERROR/WARN in the logs while walking the happy path
```

**Performed by the MAIN SESSION** — this is running and observing, not code analysis; delegation adds
nothing here, and it costs.

**What NOT to do:** do not build test infrastructure for this stage, do not spin up docker
"for a moment" if the project does not have it. When running is not feasible in reasonable
time → **N/A with a one-sentence reason** in `verification.md`. The stage is meant to catch obvious
crashes, not to block verification.

**Result:** ✅ (happy path works) / 🔴 (does not work — blocks PASS) / N/A (+ reason).

---

## Stage 9: Git & Release Readiness

```
□ Commits atomic?
□ Commit messages follow format?
□ tasks.md updated?
□ Env vars documented (if new)?
□ Dependencies locked?
```

**MR description (when the team works with MRs/PRs):** the reviewer can read `ai/changes/{name}/` in the MR,
but an MR description makes review easier in the MR/PR UI itself — always include it. On PASS attach to the report a ready-to-paste description: the goal from
`proposal.md` (1-2 sentences), the requirements
from the delta with the **AC text** (ADDED/MODIFIED/REMOVED — the reviewer does not have your files), coverage
in the form "AC text → test", key `DECISION` entries, "Deviations from principles" from design.md (MUST principles
are team-wide), the stage table from `verification.md`. REQ/AC numbers are your local numbering —
in the MR description give the text, the number at most as an aid.

---

## Verdict and writing the result

**Verdict criteria:**
- ✅ **PASS** — all stages ✅ or N/A; 🟡 warnings do NOT block (but go into the report and verification.md)
- ❌ **FAIL** — any stage with 🔴 CRITICAL, AC in ❌, `INV` in ❌ (refactors), Stage 1 failed
  or **a subagent verdict of `WARN`/`BLOCK`** (all verifiers use one vocabulary
  `PASS / WARN / BLOCK` — `WARN` on an AC/INV means FAIL, a purely quality `WARN` is 🟡)

**WRITE the result to `ai/changes/{name}/verification.md`** — without it `/regent:archive` refuses:

```markdown
# Verification: {name}

Verdict: PASS / FAIL
Date: YYYY-MM-DD
Commit HEAD: {hash}

| # | Stage | Status |
|---|-------|--------|
| 1 | Tests | ✅ |
| 2 | Spec Compliance | ✅ |
| 3 | Code Review | ⚠️ 2 warnings |
| 4 | Test Verification | ✅ |
| 5 | DB Review | ✅ / N/A |
| 6 | Security Review | ✅ / N/A |
| 7 | Observability Sync | ✅ / N/A |
| 8 | Smoke Check | ✅ / N/A |
| 9 | Git & Release | ✅ |

## AC coverage (from Stage 2)
| REQ/AC | Test | Status |
|--------|------|--------|
| REQ-001/AC-1 | tests/users.test.ts › rejects duplicate email | ✅ |

## Issues
- [Stage 3] 🟡 Missing error handling in file.ts:45
```

## Final report (CONCISE!)

Show the user the same table + issues + the next step:

```
→ PASS: /regent:archive {name}
→ FAIL: see "FAIL path"
```

**Do not elaborate.** Briefly, with files and lines.

---

## FAIL path

```
1. List the issues (severity, file:line).
2. Fix via /regent:apply {name} --tasks ... — append the fix tasks at the end of tasks.md
   in the group `## Fixes (round N)`, each with a reference and the gap type from the reviewer's report:
   `- [ ] T-09: [BE] {what} — REQ-001/AC-2 — gap: incomplete — verification: {test}`
   Or delegate pointwise to `regent:backend-dev`.
3. Re-run: Stage 1 (always) + ONLY the failed stages (2-9).
4. Update verification.md with the new verdict.

🔴 CRITICAL — blocks PASS. 🟡 WARNING — does not block, but stays in verification.md.
```

---

## IMPORTANT Rules

✅ **ALWAYS:**
- Stage 1 in the main session (make lint/type-check/test/test-coverage)
- PASS requires a test for every AC — an AC without a test is at most ⚠️ PARTIAL
- verification.md written (verdict + date + commit HEAD) — this is the condition for finishing the command
- Report: verdict + file:line, without quoting code

❌ **Guardrail:** verifying subagents work read-only (no Edit/Write) — they describe findings
in the report; they are fixed by `/regent:bugfix` or `/regent:apply`.
