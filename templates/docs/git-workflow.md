# Git Workflow

> Fill in based on the git history and configuration detected by `/regent:init`.

## Branching

| Element | Value |
|---------|-------|
| Model | [trunk-based / gitflow] |
| Main branch | [main / master] |
| Branch format | `<type>/<KEY>-<short-description>` |

Examples: `feat/PROJ-123-user-registration`, `fix/PROJ-124-duplicate-email`, `hotfix/2025-03-20-payment-500`.

## Commits (Conventional Commits)

**Format:** `<type>: (<KEY>) <description, imperative>`

**Limits:** the whole line **max 100 characters**, **one line — no body**. A long description = commit too big → split it.

| Type | Usage |
|------|-------|
| feat | New functionality |
| fix | Bug fix |
| refactor | Refactoring (no behavior change) |
| test | Tests |
| chore | Dependencies, configuration, CI |
| docs | Documentation |
| perf | Performance |

Example: `feat: (PROJ-123) add global error handling middleware`

## Rules

- Atomic commits — 1 commit = 1 logical change.
- Commit message: **one line, max 100 characters, no body**.
- **NEVER** `git add .` / `git add -A` — always specific files.
- **NEVER** commit without passing tests; **NEVER** `--no-verify`.
- `git push` only on explicit request.
- Task key (Jira/other) in every commit; if none → `NONE`.

## Pull Requests / Merge

- [Strategy — e.g. squash / merge commit]
- [Required review / CI green before merge]
- `ai/` is tracked in the repo — `ai/changes/{name}/` is part of the MR, and the MR description
  from `/regent:verify` Stage 9 makes review easier in the MR UI. The reviewer reads the plan first
  (is it good), then the code (does it implement the plan).
- `/regent:archive` after the MR merge — your `ai/specs/` grows only by code that got in.
- The squash commit subject contains the ticket key (`feat: (KEY) …`) — by it `sdd-check stale`
  recognizes work from the SDD cycle.
