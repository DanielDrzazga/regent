---
description: Update ai/docs/ when the approach changes (architecture, stack, conventions)
disable-model-invocation: true
argument-hint: <file-or-topic>
allowed-tools: Task, Read, Write, Edit, Grep, Glob, Bash
---

# /regent:revise — Update ai/docs/

**Goal:** Update the technical documentation when implementation reveals changes in the approach.

```
/regent:revise <file-or-topic>

Example:
/regent:revise architecture    (update ai/docs/patterns/architecture.md)
/regent:revise technology      (update ai/docs/stack/technology.md)
/regent:revise naming          (update ai/docs/conventions/naming.md)
/regent:revise glossary        (update ai/docs/domain/glossary.md)
```

---

## Agent (delegation — REQUIRED)

Delegate preparing the `ai/docs/` update to the `regent:architect` subagent (model: opus,
Task tool) — it generates and maintains the documentation (as in `/regent:init`), including
`logging-patterns.md`. **Don't delegate `regent:logging-engineer` here:** that agent treats
`logging-patterns.md` as an external source of truth and when it is missing it STOPS work —
i.e. exactly in the situation in which `/regent:revise` is supposed to create that file. When the
logger's realities are needed (import path, API), work them out yourself (Grep/Glob) and pass them to the architect
in the prompt.

**Contract:** `regent:architect` is read-only — it returns the proposed content (WAS/NOW diff)
in the report; the main session shows the diff to the user and after approval writes the files.
The main session runs the interview (Step 1).

---

## Step 1: Interview

```
1. What changed compared to the documentation?
   [Description of the original vs the new approach]

2. Why the change?
   [Reason — technical discovery, requirements change, better solution]

3. Which ai/docs/ files need updating?
   [List of files]
```

**Wait for the answers.**

---

## Step 2: Identify the files

```
Based on the interview, files to update:

□ ai/docs/stack/technology.md — stack change
□ ai/docs/patterns/architecture.md — pattern change
□ ai/docs/patterns/di-patterns.md — DI change
□ ai/docs/patterns/testing-patterns.md — testing change
□ ai/docs/patterns/exception-patterns.md — error handling change
□ ai/docs/patterns/logging-patterns.md — logging pattern change (logger path/API)
□ ai/docs/conventions/naming.md — convention change
□ ai/docs/domain/glossary.md — a new domain term, a change in meaning of an existing one
  or resolving an ambiguity (then an entry in the "Resolved ambiguities" section
  with a date — the record of the dispute is as valuable as the definition itself)
□ ai/docs/conventions/code-style.md — style change
□ ai/docs/conventions/git-workflow.md — git workflow change
```

---

## Step 3: Prepare and approve the changes

The subagent returns the proposed changes; the main session shows the diff:
```
## Changes in ai/docs/patterns/architecture.md:

WAS:
  Architecture Type: Modular Monolith

NOW:
  Architecture Type: Microservices (2 services: API + Worker)

Reason: Worker requires separate scaling
```

**Wait for approval.** After `yes` → the main session writes the files.

---

## Step 4: Confirm

```
## Revise Complete ✅

### Updated files:
- ai/docs/patterns/architecture.md
```

---

## IMPORTANT

- **Don't change ai/docs/ "silently"** — always /regent:revise
- **Other agents read ai/docs/** — an update affects the whole workflow

Timeline: 10-20 minutes
