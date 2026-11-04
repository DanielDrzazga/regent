---
description: Peer code review of changes (architecture, quality, tests, performance) by the code-reviewer agent
disable-model-invocation: true
argument-hint: [--branch <branch>] [--scope <path>] [--files <list>]
allowed-tools: Task, Read, Grep, Glob, Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(git symbolic-ref:*), Bash(git branch:*)
---

# /regent:code-review — Code change review

**Goal:** Run a peer code review checking architecture, quality, tests, performance.

```
/regent:code-review [options]

Options:
  --branch <branch>     Review a specific branch
  --scope <path>        Review a specific directory/file
  --files <list>        Review specific files

Example:
/regent:code-review
/regent:code-review --branch feat/PROJ-123-user-registration
/regent:code-review --scope src/modules/users/
```

---

## Agent (delegation — REQUIRED)

Delegate the whole review to the `regent:code-reviewer` subagent (model: opus, launch it with the Task tool).
Do not do the review "in place" in the main session — otherwise the model from `agents/code-reviewer.md`
will not be used.

---

## Step 1: Determine the scope

```bash
# Comparison base: default branch from ai/docs/conventions/git-workflow.md;
# fallback: git symbolic-ref refs/remotes/origin/HEAD (main OR master — don't assume)

# If --branch
git diff {default-branch}..{branch} --stat

# If --scope
git diff --stat -- {scope}

# If no options
git diff --stat                    # unstaged
git diff --cached --stat           # staged
```

---

## Step 2: Read the context

The `regent:code-reviewer` subagent reads **directly via Read**:
```
1. ai/docs/patterns/architecture.md
2. ai/docs/conventions/naming.md
3. ai/docs/conventions/code-style.md
4. ai/docs/patterns/testing-patterns.md (if it exists)
```

Then read **only the changed files** from `git diff --name-only` — do NOT scan the whole src/.

**Change plan** (section 7 of the `regent:code-reviewer` checklist — compliance with the plan):
- own SDD change → the agent reads `ai/changes/{name}/` (design, delta, tasks);
- someone else's MR → the plan is `ai/changes/{name}/` from the MR branch; an MR without it →
  pass the **MR description** (goal, requirements with AC, decisions, deviations) in the prompt as
  the plan; no description either → review without section 7 and one sentence about it in the report.

---

## Step 3: Review checklist

The checklist (architecture, quality, security sanity-check, spec compliance, performance,
git hygiene) lives in the `regent:code-reviewer` agent definition — **one source, do not duplicate it
here**. A deep security review is `/regent:verify` Stage 6 (`regent:security-auditor`),
and the test strategy — `/regent:testing` (`regent:qa-engineer`).

---

## Step 4: Report

```markdown
## Code Review: [branch/scope]

### 🔴 CRITICAL (must be fixed before merge)
1. **[Issue]** — `file:line`
   Suggestion: [how to fix]

### 🟡 WARNING (should be fixed)
1. **[Issue]** — `file:line`

### 🔵 SUGGESTION (optional improvement)
1. **[Issue]** — `file:line`

### ✅ PRAISE (what is done well)
1. [What is good]

---

### Verdict: PASS ✅ / WARN 🟡 / BLOCK 🔴
```

---

## Tips

- **Be constructive** — suggest solutions, don't just criticize
- **Pick battles** — don't comment on every trifle
- **Security first** — always check security issues

Timeline: 15-30 minutes
