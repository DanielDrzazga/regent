---
description: Formal change proposal — proposal, delta specs, design, tasks (spec before code)
disable-model-invocation: true
argument-hint: <change-name> [--type feature|refactor|bugfix]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:propose — Propose a change

**Goal:** Create a formal change proposal with a full specification (proposal, delta specs, design, tasks).

```
/regent:propose <change-name> [--type feature|refactor|bugfix]

Example:
/regent:propose user-registration
/regent:propose extract-auth-service --type refactor
```

---

## Agents (delegation — REQUIRED)

This command MUST run through subagents (launch them with the Task tool) to use their models:

| Subagent (`name`) | Model | Role in the command |
|-------------------|-------|---------------------|
| `regent:spec-writer` | sonnet | proposal, delta specs, tasks |
| `regent:architect` | opus | design.md — approach, layers, risks |

❗ Do not carry out the steps "in place" in the main session — **delegate to the subagent by its exact `name`**.
Otherwise the models from `agents/*.md` will not be used.

**Budget:** S: 1-2 subagent runs, M: 2-3, L: 3-5 (table in `context/sdd.md`).
Exceeding it → one sentence of justification for the user.

**Split of roles main session ↔ subagent:** the user interview and the acceptance gates are run by
the MAIN SESSION (a subagent cannot talk to the user). Subagents get the answers
in the prompt and **write the artifacts themselves as a Draft**, reporting only the paths — the
acceptance gate runs on the written files.

---

## Step 0: Configuration validation

```
REQUIRED files (not empty):
□ ai/docs/stack/technology.md
□ ai/docs/patterns/architecture.md
□ ai/docs/conventions/naming.md
□ ai/docs/conventions/code-style.md
□ ai/docs/conventions/git-workflow.md

If missing → "Run /regent:init before /regent:propose"
```

**Conflict with another active change (hard checkpoint, not a general warning)** — your working tree shows
only changes merged into your branch; colleagues' changes on other branches show up after their MR
is merged. For every change in your `ai/changes/` (excluding `archive/`) compare it with the scope of this proposal:
```
□ same domain in specs/{domain}.md?   (both deltas will go into the same main spec)
□ shared files in design.md → "Affected Files"?
```
Overlap → list the conflicting change and ask (`AskUserQuestion`): continue in parallel /
wait for it to close / widen the scope of that change. **Record the decision in `proposal.md`**
(section `## Dependencies`) — `/regent:archive` merging the second delta into the same main spec must
know that the first one already changed it.

---

## Step 1: Understand the change (interview in 1 round, Challenge in rounds)

### 1a. Type detection

```
Based on the name / description (PL and EN):
- "add", "create", "implement", "dodaj", "utworz" → feature
- "extract", "refactor", "reorganize", "wydziel", "uporzadkuj" → refactor
- "fix", "repair", "correct", "napraw", "popraw" → bugfix

If unclear → ask the user
```

### 1b. Interview (MAIN SESSION — one round, save tokens!)

The main session asks the user everything in a single question:

```
Describe the change:
1. Problem and goal — what and why?
2. Behavior — happy path + error scenarios?
3. Scope — what is IN scope, what is OUT of scope?
4. Constraints — technical, time?
```

Input from `/regent:explore` (the "Input to /regent:propose" block) replaces the questions it already
answers — the resolutions from exploration are ready `DECISION` entries, and "Open" is the first
Challenge frontier.

**Wait for the answers.** If the answers are sufficient → Step 1b′. If not → ask
SPECIFICALLY about the missing elements (do not repeat the whole interview).

### 1b′. Challenge — decision tree in rounds (QUALITY GATE)

> **Why:** `context/role.md` puts you in the role of a **co-responsible partner**, not an executor.
> Without this step that role depends on whether something happens to occur to you. Here it is enforced.
> This is the only place in the cycle where a bad idea still costs zero lines of code — and the only one
> where all questions to the user are asked BEFORE the first subagent starts.

A change is a **decision tree**: every resolution reveals further decisions that depended on it.
You cannot sensibly ask about the shape of an API before you know whether a new module is being built at all.
That is why you work in **rounds**, not with one list of questions and not question by question.

**Frontier** = all decisions whose premises are already resolved — i.e. the questions
you can ask NOW without guessing answers you have not heard yet.

#### Division of labor (non-negotiable)

```
FACTS you find YOURSELF — you never ask the user about them.
  Does this helper already exist? What pattern is in the code? What does the ADR say?
  → Grep/Glob/Read, and for a broad scope ONE Explore subagent.

DECISIONS you hand to the USER — you never resolve them for them.
  Do we build this? Which variant? What is OUT of scope?
  → AskUserQuestion, with your recommendation as the first option.
```

Asking about a fact you could have checked yourself is a mistake — it wastes the user's turn.
A decision made for the user breaks the partner role.

#### Round 0: gather facts and open the tree

Survey the code **read-only** (Grep/Glob/Read; ONE `Explore` when the scope is unclear) and check
the roots of the tree — they are always the first frontier, because nothing depends on them in the other direction:

```
□ PROBLEM — is the problem real and named?
  Red flag: the justification is "because it will be better" / "it will come in handy" / "others have it",
  without a concrete user pain or a cost that goes away.

□ PROPORTION — is the solution proportional to the problem?
  Red flag: a new abstraction layer / new dependency / new module for a problem
  that can be solved in the existing code.

□ SCOPE — is the scope not overgrown relative to the problem?
  Red flag: AC describing cases nobody reported; "since we're at it anyway…".

□ SIMPLICITY — is there a clearly cheaper solution with the same effect?
  Red flag: you have not considered a single alternative.

□ LANGUAGE — (when `ai/docs/domain/glossary.md` exists) does the change description use terms
  from the glossary in their established meaning?
  Red flag: a term used in a meaning different from the glossary, or a synonym from `_Avoid_`.
  A discrepancy is a frontier question ("does X mean A or B here?"), and once resolved —
  an entry in the "Resolved ambiguities" section of the glossary.

□ PRINCIPLES — (when architecture.md has "Non-negotiable principles") does the direction fit within the MUST?
  Red flag: the solution requires a deviation — that is a frontier question, and after the decision
  an entry in design.md → "Deviations from principles".

□ GAPS — does the behavior description answer what a tester will ask anyway?
  Go through the categories: error / empty / loading states · measurable NFRs (time, limits, volume) ·
  permissions (who can, who cannot) · concurrency and idempotency (twice, at once) · data
  lifecycle (edit, delete, archive) · external integration failure.
  Red flag: a category applies to the change, the description is silent, and the answer would change an AC or a test.
  A low-impact gap is not a question — the spec-writer will adopt a reasonable value as an ASSUMPTION.
```

**Zero red flags and zero technical forks** → say `ACCEPT` in one sentence
and go to Step 2. Do not hunt for problems by force — most changes should simply pass here,
and a round of questions without questions is a wasted turn.

#### Rounds 1..N: ask the whole frontier at once

Each round is **one `AskUserQuestion` turn** (up to 4 questions), asked by the MAIN SESSION.
Question format: title, body, **your recommendation as the first option** with the suffix
`(Recommended)`.

The frontier of this round includes both the objections from Round 0 (whether to build) and
the technical forks that would change the artifact content if the subagent guessed wrong:
- **Approach:** extend an existing component vs create a new one; pattern X vs Y.
- **Scope:** what exactly is IN/OUT, when the description is broad or ambiguous.
- **Contract/API shape:** signatures, types, data format — when there is more than one
  reasonable option.
- **Divergence from the source document:** the ticket/standard assumes a different stack than the project.

❗ **A question whose answer depends on another question open in THIS round belongs to a
LATER round.** That is the whole mechanism — break it and you are back to guessing.

After the answers: resolved decisions push the frontier outward and unlock the
questions that depended on them. Recompute the frontier and ask the next round.

**When the frontier needs a fact from the environment** — launch the survey, but **do not block
the whole round on it**: only that branch waits, the rest of the frontier you ask now.

#### End: frontier empty

The session ends when **no branch is left with a silent assumption**. Then the verdict:

- **`ACCEPT`** — the tree passed without objections (or the objections were dispelled
  in the rounds). One sentence and Step 2.
- **`OBJECTIONS`** — the user upheld the direction despite the red flags.
  List them **concisely** (1-3 points, each: objection + a concrete alternative).

**Every resolution from the rounds goes into `proposal.md`** — section `## Decisions and assumptions`,
a `DECISION` entry (issue → answer, one line). Collect them after every round and pass the
complete list to `regent:spec-writer` in Step 2. After context compaction, an interrupted session or
half a year later, it is the only trace of why the plan looks the way it does.

**Objections always go into `proposal.md`** — section `## Objections` with the user's
verdict (`addressed` / `knowingly rejected`). Reason: the decision must be documented
even when you reject it — half a year later nobody remembers the topic was raised.

❗ **If the user upholds the decision after your objections — it is their decision.
Record it and build the full scope without returning to the topic.** You raise it once, you do not nag.

#### Round budget (a ceiling, not a target)

| Size | `AskUserQuestion` rounds | Note |
|---|---|---|
| **S** | 0-1 | usually `ACCEPT` after Round 0 |
| **M** | 1-2 | |
| **L** | 2-3 | 4th round → say why the tree is that deep |

The read-only survey counts toward the subagent budget (`Explore`), question rounds do not.

❗ **Do not delegate until the frontier is empty.** Every re-delegation after the fact (because a
decision about the logger, scope or API shape "came up") is a full context re-run. A measurement of a real
`/regent:propose` showed 6 subagents instead of 2, because 3 decisions came SEQUENTIALLY after the reports.
Better one extra round here than one re-delegation later.

---

## Step 2: Generate artifacts (subagents write the Draft files, report paths)

Delegate (Task) with the interview answers in the prompt — in this order, each step takes
the result of the previous one:

1. `regent:spec-writer` → writes **proposal.md** (`Status: Draft`) and **specs/{domain}.md**
2. `regent:architect` → writes **design.md** (it reads proposal.md and specs/ from `ai/changes/{name}/`)
3. **resume the same `regent:spec-writer`** (SendMessage by agentId): design.md is written →
   it writes **tasks.md**. Tasks follow from "Affected Files" and the architect's decisions, not from the
   spec alone. A resume is not a new run (budget), and the spec-writer already has the spec context.

In the prompt to `regent:spec-writer` pass the `DECISION` list from Step 1b′ and the objections (if any),
plus two facts computed by the script (main session, before delegation):
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh next-req` → the next free REQ number (run
  `git fetch -q` first: the script also counts numbers from deltas on remote branches),
- `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh index` → index of requirements from `ai/specs/` — the spec-writer reads in full only the main specs
  of the domains the change touches.

In every prompt name the exact paths to write (`ai/changes/{name}/proposal.md`, `specs/{domain}.md`,
`design.md`, `tasks.md`) and state: **"Write these files yourself; report only the paths with one
sentence each — do not repeat the content"**. The content then crosses the context once, as the
subagent's Write, instead of three times (report → main session → Write).

In the prompt to `regent:architect` remind it: **take patterns from `ai/docs/patterns/` + the
Reference Implementations section in `architecture.md`; scan `src/` only to LOCATE files
for "Affected Files", not to learn a pattern from scratch.** If a needed pattern has no Reference
Implementation → it should report that in its report (a candidate to add via `/regent:revise`).

**Narrow the context passed to subagents (save tokens):**
> Which `ai/docs/` files to read is already known from the `regent:spec-writer`/`regent:architect` definitions — DO NOT repeat
> it in the prompt. Below is only the orchestration logic the agents do not have:
- Large source documents (specifications, standards, `.docx.md`): let ONE
  subagent read them ONCE and return the conclusions in its report. In later prompts/iterations pass
  **the summary from the report**, do not have the document read again.
- Pass the subagent only those code survey results (from Step 1b′) it needs —
  not the whole exploration dump.

### 2a. proposal.md
Template: `${CLAUDE_PLUGIN_ROOT}/templates/proposal-template.md`
- Metadata, problem, solution, expected outcome, scope, impact, Decisions and assumptions
  (AC live in the delta — the proposal refers to them)

### 2b. specs/{domain}.md
Template: `${CLAUDE_PLUGIN_ROOT}/templates/spec-template.md`
- ADDED / MODIFIED / REMOVED / INVARIANTS
- One file per domain

### 2c. design.md
Template: `${CLAUDE_PLUGIN_ROOT}/templates/design-template.md`
- Approach, Affected Files, API, DB changes, risks
- REMOVE unused sections (e.g. Database Changes when there are no DB changes) — their presence
  triggers stages in /regent:verify

### 2d. tasks.md

Layer tags (`[BE]`/`[FE]`/`[DB]`, no tag = `[BE]`) are assigned by `regent:spec-writer` per its
definition. Your orchestration role: **for a BE+FE change make sure `design.md` contains
the API↔UI contract** (contract-first — FE mocks HTTP per the contract, BE first by default).

The task format (REQ/AC, files, verification) is defined by `regent:spec-writer` — example:

```markdown
# Tasks: [name]

## Setup
- [ ] T-01: [task] — files: [...] — verification: [command / observable effect]

## Implementation
- [ ] T-02: [DB] Migration: users table — REQ-001 — files: [...] — verification: migration up/down/up
- [ ] T-03: [BE] Create user endpoint — REQ-001/AC-1, AC-2 — files: [...] — verification: tests REQ-001/AC-1, AC-2 green (after T-02)
- [ ] T-04: [FE] Registration form component — REQ-001/AC-3 — files: [...] — verification: component test REQ-001/AC-3 (after T-03)

## Integration / E2E
- [ ] T-05: [BE] Registration E2E — REQ-001, REQ-002 — files: [...] — verification: E2E test green

---
Total: X tasks | Size: [S/M/L]
```

The tests of a single task are written in that task (TDD cycle). The `## Integration / E2E` group is only
for cross-cutting tests — ones that check several tasks at once.

If the subagent's report contains `OPEN QUESTIONS` → ask them to the user (in one
`AskUserQuestion` turn) and **continue THE SAME subagent** (SendMessage / resume by agentId)
with the answers. **Resume is the DEFAULT path** — the subagent keeps its context, you do not pay
again for its system prompt or for the documents it loaded. Re-delegation from scratch (new Task) ONLY
when resume is unavailable.

---

## Step 2.5: Consistency check of the artifacts (MAIN SESSION)

Before you show the Draft, read the four written files (one Read each) and compare them — without a new subagent.
A divergence between artifacts today surfaces only in the code; here it costs one text fix.
AC↔task coverage and reference correctness are computed by the script in 3a — here you check what the script
cannot judge:

| Check | Divergence → action |
|---|---|
| Files from the tasks fit within "Affected Files" from design.md | fix tasks or design (resume) |
| Technical decisions and the API contract from design.md consistent with the AC | contradiction → question to the user |
| Every `DECISION` from Challenge reflected in the artifacts | complete the artifact |
| Terms consistent with `glossary.md` (when it exists) | synonym from `_Avoid_` → fix |

You fix a minor divergence yourself in the content before writing; a conceptual one → resume the right
subagent. You show the result (number of divergences and what was done with them) in 3b in one line.

---

## Step 3: Save as Draft + presentation for review

> **Philosophy:** the user judges the FULL files, not a shortened picture in the chat — fixes (wrong AC,
> bad scope, off-target design) often become visible only after reading the artifacts. That is why
> we save them FIRST as `Draft`, and set `Approved` only after acceptance.

### 3a. Saving the Draft (MAIN SESSION)

The subagents have written the files to `ai/changes/{name}/` — check that all of them exist:
```
ai/changes/{name}/
├── proposal.md      ← Status: Draft
├── specs/{domain}.md
├── design.md
└── tasks.md
```
- `proposal.md` has **`Status: Draft`** (set it if the spec-writer left another value).

After writing, check the artifacts with the script (the script computes facts, not the model):
```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh change {name}      # delta format, tasks, AC coverage by tasks
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh preflight {name}   # delta vs ai/specs/: number collisions, MODIFIED without REQ, AC loss
```
ERROR → fix before the presentation (minor — yourself, conceptual — resume the subagent). Coverage WARN
(AC without a task, task without an AC) → fix or justify with an entry in Decisions.

### 3b. Presentation (paths + concise summary)

```markdown
## Proposal: [name] ([type]) — saved as Draft

Files to review (in this order — from "is this the right problem" to "how"):
- ai/changes/[name]/proposal.md
- ai/changes/[name]/specs/[domain].md
- ai/changes/[name]/tasks.md
- ai/changes/[name]/design.md

AC: X | Tasks: Y | Size: S/M/L | Modules: [list] | Specs: [X ADDED, Y MODIFIED]
Assumptions to confirm: N (proposal.md → Decisions and assumptions, ASSUMPTION entries)
Consistency (Step 2.5): [N divergences — fixed / for decision: …] | sdd-check: [RESULT]
Key risks / OPEN QUESTIONS: [1-2 sentences, if any]

Reviewer checklist (2 minutes):
□ The problem and scope are what I asked for — nothing beyond that crept in
□ Every AC can be checked by a test; the case I care about most has its own AC
□ The assumptions (ASSUMPTION) are acceptable
□ Every task points to its AC and verification — none is a riddle
□ I would be at ease if the AI built exactly this and nothing more

Read the files, then: `approve` / `revise: [description]` / `reject`
```

**WAIT FOR THE DECISION.**

### 3c. Handling the response:

**`approve` / `yes`** → Step 4 (status flip).

**`reject` / `no`** → set `Status: Rejected` in proposal.md (leave the files as a trace of the decision;
the user can delete the directory manually). Do not continue.

**`revise: [description]`** → apply the fixes, the files stay `Draft`; rerun `sdd-check change`
and `preflight` (3a), then show section 3b with the current result.
Choice of path **depending on the scale of the fix**:
- **Minor / mechanical** (typos, formatting, single AC, `action` name, correction of a
  path/type) → **the main session edits the Draft files directly** (Edit). DO NOT wake the subagent — this is
  the cheapest and fastest for iterating on text. Say briefly what you changed.
- **Conceptual** (change of technical approach, scope, many AC/tasks at once, redesign of the
  design) → **continue THE SAME subagent** (SendMessage / resume by agentId), it updates
  the files itself and reports what changed. Protects proposal↔specs↔design↔tasks consistency. Re-delegation from scratch
  ONLY when resume is unavailable. Collect related fixes into one turn.

If you are unsure which category a fix belongs to → treat it as conceptual (subagent).

**Iterate until `approve`.** The files are on disk as Draft throughout the iteration.

---

## Step 4: Approval (MAIN SESSION)

After `approve` — the files already exist (saved in Step 3). Do ONLY:
1. Change in `proposal.md` **`Status: Draft` → `Status: Approved`** (without it `/regent:apply` refuses to start).
2. (optional) Export the tasks to a tracker — only when the session has a tracker connected (e.g. MCP
   Jira/GitLab); without one, skip this point without asking. This is an action outside the repo, so:
   - you ask for consent (`AskUserQuestion`: export / skip) and show the list of tasks to create,
     as subtasks of the ticket from the `Ticket` field in proposal.md;
   - a task that already has `(issue: KEY-123)` in tasks.md you skip (deduplication by `T-NN`);
   - you append the key of the created issue next to the task: `(issue: KEY-123)`.
3. Point to the next step:
```
ai/changes/{name}/proposal.md → Status: Approved

→ /regent:apply {name}
```

---

## IMPORTANT Rules

✅ **ALWAYS:**
- 1 interview round (main session), ask only about gaps
- Challenge (Step 1b′) before architectural decisions — verdict `ACCEPT` /
  `OBJECTIONS` stated explicitly
- Most changes pass with `ACCEPT` — you raise an objection when you have a concrete
  alternative; raised once, then you build the full scope per the user's decision
- Objections (if any) recorded in `proposal.md` → section `## Objections` with the user's decision
- Frontier empty (Step 1b′) BEFORE the first delegation — no branch unresolved,
  because every re-delegation is a full context re-run
- Consistency check before review: semantic in Step 2.5, AC↔task coverage by the script in 3a
- The subagent writes the artifact files itself (Draft) and reports only paths — never the content
- Files saved as `Draft` BEFORE review; `Approved` only after `approve`
  (`/regent:apply` blocks Draft)
- Fixes by scale: minor → the session edits the Draft files directly; conceptual → resume
  the subagent (resume instead of re-delegation — context paid once)
- Context for subagents narrowed (summary of large documents instead of rereading)
- AC in Given-When-Then; delta specs (not full)
- INVARIANTS in the delta spec for refactors
- Concise presentation (paths + summary), encouragement to read the Draft files
