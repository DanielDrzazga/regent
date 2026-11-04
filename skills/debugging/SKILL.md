---
description: Systematic problem diagnosis — reproduction, analysis, root cause; fix via /regent:bugfix
disable-model-invocation: true
argument-hint: <problem-description>
allowed-tools: Read, Grep, Glob, Bash
---

# /regent:debugging — Systematic problem diagnosis

**Goal:** A systematic approach to debugging — a tight pass/fail loop, hypotheses, root cause.
**Boundary:** this command DIAGNOSES. The fix goes through `/regent:bugfix` (dev/staging) or
`/regent:hotfix` (production) — that's where the artifacts, the regression test and closing via `/regent:archive` live.

```
/regent:debugging <problem-description>

Example:
/regent:debugging "API returns 500 on user creation"
/regent:debugging "tests pass locally but fail in CI"
/regent:debugging "memory usage grows over time"
```

---

## Agent (delegation)

No dedicated "debugger" subagent — reproduction, information gathering and hypothesis testing
(steps 1-4) run in the main session. The command's scope ends at a
confirmed root cause — then handoff to `/regent:bugfix` (Step 5).

---

## Step 1: Build a tight loop (GATE — this is the core of this command)

> **Why:** with a pass/fail signal that lights up red on **this** bug, you will find the cause
> — bisection, hypotheses and instrumentation only consume it. Without it, reading code
> won't replace measurement. This is where you put in disproportionate effort; the rest of the command is mechanical.

**The loop is one command** that you have already run and whose output you show. Look for four
properties in this order:

```
□ RED           — lights up on THIS bug (not "tests pass, but something doesn't work")
□ DETERMINISTIC — the same result over and over
□ FAST          — seconds, not minutes
□ AGENT-RUNNABLE — runnable without clicking in the UI
```

**Ladder — reach for the next rungs until the loop exists:**

```
1.  Failing test (narrow: single file/pattern)        ← start here
2.  curl / HTTP request with saved output
3.  CLI + fixture + snapshot diff
4.  Headless browser (E2E on one scenario)
5.  Replay of a saved trace / request from the logs
6.  One-off harness (script calling the module directly)
7.  Property/fuzz loop — 1000 random inputs, you look for the first red
8.  Harness for `git bisect run`
9.  Differential loop: working vs broken version, same input
10. Bash script with steps for a human                ← last resort
```

**Nondeterministic bug:** the goal is a **higher reproduction rate**, not a clean
reproduction. A 50% bug is debuggable, a 1% one is not — raise it with the loop (repetitions,
parallelization, artificial delays) before moving on.

**Secrets:** build the loop on environment variables — the credential stays in the environment,
outside what you show in the report.

### Exit gate of Step 1

```
□ I can name ONE command
□ I have run it at least once
□ I show the invocation and its output (redacted)
□ It is red on this bug
```

❗ **Until this command exists, you stay in Step 1.** Catching yourself reading code
in search of a theory before building the loop is a signal to come back here —
jumping to a hypothesis is exactly the mistake this command prevents.

---

## Step 1.5: Minimize the loop

Cut one element at a time: step, payload field, dependency, config file.

**Done when every remaining element is load-bearing** — removing any of them turns off the red
light. A minimal loop shrinks the hypothesis space in Step 3 and becomes a clean regression
test in `/regent:bugfix`.

---

## Step 2: Reproduction and context

The loop from Step 1 is already an executable record of the reproduction — here you add what it doesn't carry.

```
### Expected: [what should happen]
### Actual:   [what happens]
### Error:    [exact message / stack trace]

### Reproducibility: [always | X% of attempts | only when: ...]

### Environment (when it matters for the bug)
- Runtime / versions of dependencies relevant to the path
- Difference local vs CI vs production

### Recent changes
git log --oneline -10   → is the loop green on the commit before the change?
```

---

## Step 3: Hypotheses

### 3a. Generate 3-5 hypotheses AT ONCE

> **Why at once:** a single hypothesis anchors on the first plausible idea
> and the rest of the diagnosis only looks for its confirmation.

Each hypothesis **falsifiable**, in a format with a prediction:

```
H1: [cause]
    If H1, then [change X] will turn off the loop's red light.
    Ranking: [high | medium | low]   Rationale: [1 sentence]
```

A hypothesis without a statable prediction is a hunch — sharpen it or drop it.

### 3b. Checkpoint with the user (non-blocking)

Show the ranked list **before** you start testing. The user often knows the domain well enough
to reorder it in one sentence. No answer → you test by your own ranking.

### 3c. Test one by one — with the loop, not by reading code

```
H1 → [test change] → loop: red/green → CONFIRMED | REJECTED
```

**Tag debug logs with a unique prefix**, e.g. `[DEBUG-a4f2]`. Cleanup at the end is
one `grep`: tagged ones disappear, untagged ones stay in the code forever.

---

## Step 4: Root Cause

```
## Root Cause Analysis

### Direct Cause
[What directly causes the problem]

### Contributing Factors
[What contributes to the problem — e.g. missing validation, race condition]

### Why Not Caught Earlier
[Why it wasn't detected earlier — missing test, edge case]
```

---

## Step 5: Handoff to the fix

```
Root cause confirmed → pass the diagnosis on:

→ /regent:bugfix "{description}" — standard path (artifacts, regression test, /regent:archive)
→ /regent:hotfix "{description}" — when the problem is IN PRODUCTION and critical

Pass to the fix command — the diagnosis is already done, `/regent:bugfix` starts from what's ready:
- **the loop command** (Step 1, after minimization) → becomes the regression test there
- **root cause** (Step 4) and the list of involved files

The fix belongs to `/regent:bugfix` / `/regent:hotfix` — that's where the artifacts, the regression test
and closing via `/regent:archive` happen.
```

---

## When the diagnosis gets stuck

- **Loop too slow or flaky** → go back to Step 1 and tighten it. A 30-second flaky
  loop is barely better than none; a 2-second deterministic one is a completely different job.
- **All hypotheses rejected** → the search space is too narrow. Extend it one layer
  down (runtime, dependency, environment configuration), generate a new 3-5.
- **Bug disappears when observed** → race condition or time dependency; differential loop
  (rung 9) and artificial delays instead of logs.

Timeline: 30-120 minutes
