---
description: Close a change — merge delta specs into main specs, retrospective, move to the archive
disable-model-invocation: true
argument-hint: <change-name> [--force | --abandon]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, SendMessage, Bash
---

# /regent:archive — Archive a completed change

**Goal:** Close the change: merge the delta specs into the main specifications, draw conclusions, move it to the archive.

```
/regent:archive <change-name> [--force | --abandon]

--force    Archive despite missing verification.md with PASS (requires an explicit user decision;
           the History entry gets the UNVERIFIED mark)
--abandon  Close an ABANDONED change — we are giving it up, it was not completed.
           Skips the task gate and PASS. Does not merge the delta into main specs.

Example:
/regent:archive user-registration
/regent:archive sso-integration --abandon
```

`--force` and `--abandon` are mutually exclusive: `--force` closes a **done** change without verification,
`--abandon` closes an **undone** change. Given together → ask which situation applies.

---

## Agent (delegation — REQUIRED for merge)

Step 2 (merging delta specs → main specs, **only 2a and 2b**) delegate to the `regent:spec-writer` subagent
(model: sonnet, launch with the Task tool) — it owns the specifications and the
ADDED/MODIFIED/REMOVED/INVARIANTS format. A bad merge corrupts the source of truth.

The remaining steps (validation, History table in Step 3.7, `mv` to the archive, summary) are
mechanical — the main session does them. **Budget: 1 run** (`--abandon` or a delta without REQ → 0, no merge).

---

## Step 0: Validation

```
Check:
□ ai/changes/{name}/ exists
□ ai/changes/{name}/verification.md exists and has "Verdict: PASS"
□ (soft) bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh drift {name} — files from Affected Files changed since `Commit HEAD`?
  WARN → warn: "the change's code moved after verification, consider re-running /regent:verify"
  (compares files, not the hash — merges and squashes of other people's changes give no false alarm)
□ `git fetch -q` — preflight compares numbers with the main specs of the default branch and with
  the deltas of other branches
□ bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh preflight {name} — ERROR (REQ number collision, MODIFIED without REQ, AC loss) →
  STOP and show the user; a merge from such a delta would damage the main spec.
  Exception — ADDED number collision (another change or branch took it first): the number from propose is
  provisional, so `sdd-check.sh renumber {name} REQ-NNN` (new = next-req), tell the user
  about the number change and repeat preflight. WARN "is also added by change … on branch …" → you archive
  first, the number stays; the second one renumbers on its side

If verification.md is missing or Verdict: FAIL:
  → "⚠️ The change has not been verified (PASS). Run /regent:verify {name} first."
  → STOP

--force: continue despite missing PASS, but the History table entry gets "(UNVERIFIED)"
and mention it in the summary.

--abandon: skip this gate and Step 1 (an abandoned change by definition has neither PASS nor
all tasks). Instead CONFIRM the decision with the user:
  "Abandoning {name}: {N/M} tasks done, the delta spec will NOT be merged
   into ai/specs/. Code from completed tasks stays in git history. Reason for abandoning?"
  → wait for the reason (goes into History) and explicit confirmation. None → STOP.
```

---

## Step 1: Check completeness

```
Artifacts:
□ proposal.md — status: Approved ✅
□ specs/*.md — delta specs exist ✅
□ design.md — exists ✅
□ tasks.md — ALL tasks [x] ✅ (counter: bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {name} → "x/y done")

If not all tasks are done:
  → "⚠️ Tasks incomplete: T-03, T-05 still pending"
  → STOP (unless --abandon — then the unfinished tasks are exactly the reason for closing)
```

---

## Step 2: Merge delta specs → main specs (delegate → `regent:spec-writer` — ONLY 2a and 2b)

`--abandon` → **SKIP the whole Step 2** (no delegation, zero subagent runs): a change that
never came to be must not be merged into the source of truth. Go straight to Step 3.

**For each file in `ai/changes/{name}/specs/`:**

### 2a. Check whether the main spec exists

```
Look for: ai/specs/{domain}.md

Delta without REQ (refactor with INVARIANTS only) → skip merging this file; no main spec
  is created (INVARIANTS stay in the archive). The whole change is like that → Step 2 without delegation.
If it does NOT exist → create a new main spec from ${CLAUDE_PLUGIN_ROOT}/templates/main-spec-template.md
  (full state: REQ with AC — the ADDED/MODIFIED/REMOVED headings stay in the delta)
If it exists → merge delta into main
```

**Before you merge — check for a parallel change:** does another active change in `ai/changes/`
have a delta on the same domain (or does this change's `proposal.md` have a `## Dependencies` section)?
If so, pass that to `regent:spec-writer` in the prompt: a `REQ` from MODIFIED may have been rewritten
by that change, so the "old behavior" from the delta may no longer exist in the main spec.
Do not make it guess — an unmatched `REQ` is `OPEN QUESTIONS`, not a silent append.

### 2b. Apply deltas

```
ADDED sections:
  → The REQ number is free in all main specs — taken → OPEN QUESTIONS (number collision;
    the main session renumbers the change with the `renumber` script, not you)
  → Add the REQ block to the main spec, Given-When-Then format and AC unchanged

MODIFIED sections (the block in the delta = full, new state of the requirement):
  → Find REQ-YYY in the main spec and replace the WHOLE block with the block from the delta
  → Every AC from the main spec is present in the delta block or in "Removed AC" —
    missing AC → OPEN QUESTIONS (incomplete delta; the user decides about the AC)
  → From the block in the main spec remove the "Removed AC", "Was", "Reason" lines and the "(unchanged)" markers —
    the current behavior remains
  → REQ-YYY absent from the main spec → OPEN QUESTIONS (behavior without a specification is described
    in the delta as ADDED — see spec-writer, brownfield)

REMOVED sections:
  → Remove REQ-ZZZ from the main spec (absent → OPEN QUESTIONS)

INVARIANTS:
  → Stay in the delta (they concern only the change) — the main spec does not contain them
```

### 2c. Merge check (MAIN SESSION, before Step 3)

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh postmerge {name}
```
ERROR (delta heading in the main spec, a REQ from the delta did not reach main, AC set differs from the delta) →
**resume `regent:spec-writer`** with the script output and fix the merge before you move the change to the archive.
Show the user the diff of the source of truth: `git diff -- ai/specs` (changes not committed yet).

---

## Step 3: Move to the archive

`--abandon` → **before** the move set `Status: Abandoned` in `proposal.md`. An abandoned change
in `archive/` looks the same as a finished one; this field is the only thing that tells them apart.

**Usage record** (also with `--abandon`): the change's Claude Code usage per command run — Regent version, model,
effort, agent, active time, tokens, API-equivalent cost — measured by the script from this machine's session
transcripts, which Claude Code deletes after ~30 days; in `usage.md` it stays with the archive:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/usage.sh {name} > ai/changes/{name}/usage.md && git add ai/changes/{name}/usage.md || rm -f ai/changes/{name}/usage.md
git mv ai/changes/{name} ai/changes/archive/{YYYY-MM-DD}-{name} && git commit -m "chore: archive {name}"
```

Exit code 3 (no run of the change in the transcripts — work on another machine, or transcripts already
deleted) → no `usage.md`; say so in the summary.

Structure after archiving:
```
ai/changes/archive/2025-03-20-user-registration/
├── proposal.md
├── specs/
│   └── users.md (delta)
├── design.md
├── tasks.md
├── verification.md
└── usage.md (when the transcripts had runs of the change)
```

---

## Step 3.5: Retrospective (one question, not a ceremony)

> **Why:** without it the framework does not learn from its own mistakes. If `/regent:verify` fails
> three times for the same reason, or `regent:architect` reports a missing Reference
> Implementation for the third time — nobody notices, because each change is closed separately.

**Collect signals from the artifacts of the change being closed (not from memory):**

```
□ verification.md — were there FAILs? How many rounds? Which stage failed?
□ verification.md → Issues — do warnings repeat from previous changes?
□ proposal.md → Objections section — were the objections confirmed?
□ proposal.md → Decisions and assumptions — was there an AMEND? Which ASSUMPTION turned out wrong?
□ tasks.md — were fix-up tasks added outside the original plan?
□ Did any subagent report a missing pattern / Reference Implementation?
```

**Verdict — one of two, stated concisely:**

- **`NO FINDINGS`** — the change went smoothly. One line and move on. This is the normal,
  most common result — **do not force findings**.

- **`FINDING: [1-2 sentences]`** — something repeated or hurt. Put it into one
  of three drawers and **propose a concrete action**:

| Kind of finding | Action |
|---|---|
| Missing/unclear pattern in `ai/docs/` | → `/regent:revise {file}` — with a concrete content proposal |
| Missing Reference Implementation | → `/regent:revise architecture` — point to the pattern file from this change |
| Recurring process error (not code) | → report to the user; a framework fix, not a project fix |

Append the finding **in one sentence** to the History table entry (Step 3.7), `Description` column —
it stays with the specification, not in a separate file.

**Do not create `retrospective.md`.** A retro without action is cost without value: it either ends with
a concrete `/regent:revise` or with the `NO FINDINGS` verdict.

`--abandon` → the retrospective is **most valuable** here: the reason for abandoning (from Step 0) is
a ready finding. Put it into a drawer and propose an action.

---

## Step 3.7: Update the History table (MAIN SESSION — mechanical work)

In one write, after the retrospective (so the finding lands in the row right away — do not edit
the table twice). In the main spec `ai/specs/{domain}.md`:

```markdown
## History

| Date | Change | Type | Description |
|------|--------|------|-------------|
| YYYY-MM-DD | {change-name} | feature | [short description from proposal.md] + [retro finding, if any] |
```

`--abandon` → mark the row **ABANDONED** with the reason, in the main spec of the domain the change
concerned (`| … | ABANDONED: {reason} |`).

Domain without a main spec (a new domain that never came to be; refactor with INVARIANTS only) →
skip the table; the trace stays in the archive and in git.

---

## Step 4: Summary

```markdown
## Archive: {change-name} ✅

### Merged specs:
- ai/specs/users.md — 3 ADDED, 1 MODIFIED

### Archived to:
- ai/changes/archive/{YYYY-MM-DD}-{name}/

### Usage:   (Cost USD, Active seconds and Runs from the usage.md table — or "no usage.md: no runs in the transcripts")
≈ $4.12 · active 1h 12m · 5 runs

### Commits included:   (hashes `(commit: …)` from tasks.md)
- abc1234 feat: (KEY) create user entity
- def5678 feat: (KEY) create user repository

### Retrospective:
NO FINDINGS
(or: FINDING: [1-2 sentences] → /regent:revise {file})

### Next steps:
→ /regent:status — project overview
→ /regent:propose — new change
```

With `--abandon`, instead of "Merged specs" write `Delta NOT merged (change abandoned)`
and give the reason and the task state (`{N/M} done`).

---

## IMPORTANT Rules

✅ **ALWAYS:**
- verification.md with PASS before archiving
  (exceptions: `--force` → mark UNVERIFIED; `--abandon` → change abandoned)
- Merge delta → main specs: ADDED appended, MODIFIED replaced as a whole block, REMOVED deleted;
  every AC from the main spec ends up in the block or in "Removed AC" (main specs describe code that exists)
- With `--abandon`: the directory goes to `archive/` with the decision recorded (`Status: Abandoned`
  in `proposal.md`), the delta stays unmerged —
  the trace of abandonment is as valuable as the trace of delivery
- Retrospective (Step 3.5) — verdict `NO FINDINGS` or a finding with a concrete action;
  `NO FINDINGS` is a valid and the most common result
- Retrospective finding → History table (one place)
- History table updated, folder moved to `archive/`

Timeline: 5-10 minutes (retrospective: +1 minute — it is one question, not a meeting)
