---
description: Read-only analysis — investigate a topic, compare options, no files and no commits
disable-model-invocation: true
argument-hint: <topic> | --discovery <initiative>
allowed-tools: Task, Read, Grep, Glob, AskUserQuestion, SendMessage, Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(ls:*)
---

# /regent:explore — Investigate a topic without committing

**Goal:** Investigate, analyze, compare options — without creating files or commits. A purely exploratory command.

```
/regent:explore <topic>
/regent:explore --discovery <initiative>

Example:
/regent:explore how authentication is implemented
/regent:explore impact of adding websockets
/regent:explore compare Redis vs Memcached for caching
/regent:explore --discovery "field job coordination for land surveying companies"
```

---

## Agent (delegation — REQUIRED)

Delegate the analysis to the `regent:architect` subagent (model: opus, launch it with the Task tool) —
it is the strongest reasoner and the owner of repo analysis (as in `/regent:init`). The quality of exploration
depends on the model, so don't run it "in place" in the main session.

❗ **Read-only** mode: the subagent does NOT create files or commits — it only analyzes and reports.
The delegating prompt **names no paths to write** (`regent:architect` writes only the paths a prompt
names), and this command's `allowed-tools` enforces read-only in the main session too.

---

## Rules

1. **Read-only** — don't create files, don't modify code
2. **Analytical** — gather facts, compare options, assess trade-offs
3. **Conversational** — output in the conversation, not in files

---

## Exploration types

### Code analysis
```
How does [module/feature] work?
→ Read the code, understand the flow, describe the architecture
```

### Option comparison
```
Option A vs Option B?
→ Compare: pros/cons, effort, risk, fit with the architecture
```

### Impact analysis
```
What changes if [change]?
→ Identify affected files, modules, tests
→ Estimate risk and effort
```

### Research
```
How to implement [feature]?
→ Investigate options, check docs, propose an approach
```

### Discovery (`--discovery`)
```
A new product or a large initiative — what are we building and in which changes?
→ Interview, synthesis, SDD change candidates, verdict — section "`--discovery` mode"
```

---

## Output format

```markdown
## Explore: [topic]

### Findings
[What was discovered]

### Options (if comparing)
| Aspect | Option A | Option B |
|--------|---------|---------|
| ... | ... | ... |

### Recommendation
[What I recommend and why]

### Verdict
BUILD / CLARIFY ([what is missing for a decision]) / DON'T BUILD ([why])

### Input to /regent:propose (when BUILD)
- Problem: [1-2 sentences]
- Scope IN / OUT: [...]
- Resolved during exploration: [issue → decision] — go into the log as DECISION
- Open: [issues] — the first Challenge frontier

### Next steps
→ /regent:propose ... (BUILD — paste the "Input to /regent:propose" block)
→ /regent:explore ... (CLARIFY)
```

---

## `--discovery` mode — a new product or a large initiative

**When:** a new product from scratch or an initiative with an unclear scope that spans several SDD
changes. A single, well-understood change → go straight to `/regent:propose`.

### D1. Interview (MAIN SESSION — max 2 rounds)

**Round 1 — problem and people**
```
1. What pain are we solving and how do you know it exists?
2. Who has it and who does it hurt the most? (personas — who they are, at which moment it hurts)
3. How do they cope today? (workarounds, competition)
4. Why now?
```

**Round 2 — scope and measures**
```
1. What must be in the first version to test the value?
2. What are we deliberately not doing at the start?
3. Constraints: technical, time, dependencies on other teams and systems?
4. How will we know it works? (success measure)
```

After each round, wait for the answers. Skip a question the command argument already answers;
ask about gaps specifically in round 2.

### D2. Synthesis (delegate → `regent:architect`)

Pass in the prompt the full set of answers, the context (`ai/docs/`, `ai/specs/`, code — if they exist;
project from scratch → the interview alone), the D3 format and the checklist:

```
□ Problem before solution — every candidate has a persona and an effect measurable in terms of their
  pain from the interview; a candidate without that → cut or in OPEN QUESTIONS
□ Candidate 1 = walking skeleton: the thinnest end-to-end slice that tests the MVP hypothesis
  on the persona with the greatest pain
□ The foundation (auth, tenant, roles, schema) goes in at the smallest scope needed by the
  first candidate that uses it; extending it is a candidate with its own effect for a persona
□ Minimal MVP — the rest goes to "Out of scope" with a reason
□ One candidate = one SDD change (propose → archive), across all layers — layers
  split tasks ([BE]/[FE]/[DB]), not candidates; size S/M/L per the budget table
  in `context/sdd.md` — you split a candidate bigger than L
□ Weak points of the idea named explicitly — assumptions without evidence from the interview are risks
□ Assessment scope: product and technical feasibility — pricing, CAC, LTV stay on the user's side
```

`OPEN QUESTIONS` from the report → ask the user and continue the same subagent
(`SendMessage`) with the answers.

### D3. Result (report in the conversation)

```markdown
## Discovery: [initiative] — Verdict: BUILD / CLARIFY ([what is missing]) / DON'T BUILD ([why])

**Problem:** [1-2 sentences] | **Personas:** [who] | **Value proposition:** [1-2 sentences]

### SDD change candidates
| # | Change (kebab-case) | For whom | Effect (measurable) | Size | Depends on |
|---|---------------------|----------|-------------------|---------|-----------|
| 1 | ... | ... | ... | S/M/L | — |

Order: [why this one — max 3 points]

### Out of scope
- [what] — [why]

### Risks and weak points
- [risk] — [what reduces it]

### Input to /regent:propose (candidate 1, when BUILD)
[fields as in "Output format"]

### OPEN QUESTIONS
- [user decisions — or "none"]
```

### D4. Handoff by verdict

- **BUILD** → `/regent:propose {candidate-1}` with the "Input to /regent:propose" block; a project without
  `ai/docs/` first goes through `/regent:init` (in an empty repo — an interview about the stack).
  Candidates 2..N → tracker, when the session has one connected — rules as in `/regent:propose` Step 4
  (consent via `AskUserQuestion`, list before creation); parent: the initiative ticket, if
  the user provides it. You list the keys of the created issues in the report. Without a tracker the list stays
  in the report.
- **CLARIFY** → gaps the user can resolve right away, you close via `OPEN QUESTIONS`
  (continuing the subagent, D2); gaps requiring outside data (conversations with users,
  measurements) → rerun `/regent:explore --discovery` once the data is available.
- **DON'T BUILD** → end; the rationale stays in the conversation.

---

## IMPORTANT

- **Read-only mode** — the analysis ends with a report in the conversation; files and commits are created
  only in `/regent:propose` (this is a guardrail: `allowed-tools` does not include Write/Edit)
- The only action outside the conversation — exporting candidates to the tracker in `--discovery` — happens
  outside the repo and with the user's consent
- Exploration is safe and reversible

Timeline: 5-30 minutes
