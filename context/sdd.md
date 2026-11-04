# Regent — SDD rules

> Map of skills and agents: `context/sdd-map.md`.

> **Scope:** SDD rules (command flow, prohibitions, delegation) apply **only in projects with an `ai/docs/` directory** or when the user explicitly initializes SDD with `/regent:init`. In all other projects only "Your role" (`context/role.md`) applies.

## How to work with the specification

A spec is a contract, not a suggestion. But a bad spec is a bad contract.

Before implementing, assess whether the spec makes sense:
- Are the AC complete? Do they cover edge cases and errors?
- Is the scope realistic?
- Does the design introduce unnecessary complexity?

If something is unclear or wrong — **stop and ask**, do not guess.

## What never to do

- Do not implement something you know is wrong — raise objections first
- Do not skip SDD steps because "it's a small change" — every change has its flow
- Do not extend the scope beyond what is in the specification (scope creep)
- Do not commit without tests — not even in a hotfix

## Workflow

Project documentation: `ai/docs/` — the commands define what to read and when.
If `ai/docs/` does not exist → `/regent:init` first.

Structure of SDD artifacts in the project (`ai/` is tracked in the product repo):
- `ai/docs/` — project knowledge (stack, patterns, conventions)
- `ai/specs/` — main specs per domain (source of truth after archiving)
- `ai/changes/{name}/` — active changes (proposal, specs delta, design, tasks, verification)
- `ai/changes/archive/` — closed changes

Every functional change:
1. `/regent:propose` — spec before code
2. `/regent:apply` — TDD: Red → Green → Refactor
3. `/regent:verify` — 9-stage verification (stages 5-8 conditional)
4. `/regent:archive` — formal closing (abandoning the change: `--abandon` — no delta merge)

Shortcuts (simplified path) allowed only for:
- `/regent:bugfix` — a bug in dev/staging (simplified artifacts, but it ends with `/regent:archive`)
- `/regent:hotfix` — a critical bug in production (max 30 min, max 3 files / 2 modules)

`/regent:refactor` is NOT a shortcut — the full propose → apply → verify → archive cycle, always with an INVARIANTS section in the delta spec.

## Subagent budget (cost ceiling)

The saving rules (Step 1b′ in `/regent:propose`, resume instead of re-delegation, contextual reading
of `ai/docs/`) say HOW to save, but not HOW MUCH may be spent. Below is the ceiling — approximate,
counted **per command**, in subagent runs (resuming the same agent ≠ a new
run, which is why resume is always cheaper).

| Change size | `/regent:propose` | `/regent:apply` | `/regent:verify` | `/regent:archive` | **whole cycle** |
|---|---|---|---|---|---|
| **S** (1-3 tasks, 1 module) | 1-2 | 1 | 1-2 | 1 | **≤ 6** |
| **M** (4-8 tasks, 1-2 modules) | 2-3 | 1-3 | 2-4 | 1 | **≤ 11** |
| **L** (9+ tasks, 3+ modules) | 3-5 | 3-6 | 4-6 | 1 | **≤ 18** |

Take the size from `tasks.md` (`Size: S/M/L`); before it exists — estimate.
The "whole cycle" column is the ceiling for ONE change from proposal to closing — exceeding it
is what hurts the user, not a single command.

**Commands outside the cycle** (`/regent:init`, `/regent:dependency-update`,
`/regent:logging`, `/regent:testing`, `/regent:code-review`, `/regent:refactor`, `/regent:bugfix`,
`/regent:hotfix`, `/regent:revise`, `/regent:explore`): **1 run per delegating step**, fixes
via resume.

**Exceeding the ceiling is allowed, but requires one sentence of justification** for
the user, e.g. *"4th subagent: security-auditor — the change touches authorization"*. The ceiling is
meant to force cost awareness, not to block work.

**The most common causes of exceeding it — check them before launching another agent:**
- decisions settled sequentially after reports instead of in rounds before delegation (`/regent:propose` Step 1b′)
- re-delegation from scratch where resume was enough
- delegating mechanical work (writing a file, `mv`, a table) — the main session does that
- launching a conditional agent "just in case" (e.g. `regent:security-auditor` for a change
  without new inputs — it is opus, it costs)

## Commit

The commit message is one line per `ai/docs/conventions/git-workflow.md` — no body and no footers
(`Co-Authored-By` and similar). git-guard rejects AI attribution, and a rejected commit is a wasted turn.

## The `make` contract (single source — do not repeat it in commands)

SDD commands call `make` targets (`check`, `test`, `lint`, `type-check`, `test-coverage`,
`deps-*`) as a **facade over the stack**, not as a hard dependency.

When the `Makefile` does not exist or a given target is missing:
1. **Do not stop working** — find the native equivalent from the stack (`ai/docs/stack/technology.md`,
   and when it is missing — from the manifest: `package.json`, `pyproject.toml`, `go.mod`, `composer.json`).
2. Run the native command and **say explicitly what you used instead of `make X`**.
3. After finishing the task, propose completing the `Makefile`
   (`${CLAUDE_PLUGIN_ROOT}/templates/Makefile.node.template`) — via `/regent:init` or `/regent:revise`.

Exception: when the target cannot be reproduced natively → **STOP and ask the user**. Do not guess the procedure.

## Naming convention: the `regent:` namespace

The framework's commands are skills of the `regent` plugin, invoked as `/regent:<name>` — `/regent:propose`,
`/regent:apply`, `/regent:init`, `/regent:code-review` etc.

Reason: names such as `init`, `status` or `code-review` collide with built-in commands
and skills of Claude Code — the short form `/<name>` works only when nothing else takes it.
The plugin prefix resolves the collision and has a side benefit: `/regent:` + Tab shows the whole
framework in one place.

**In the content of skills, agents and documentation always use the full form `/regent:<name>`**, also when the short one
does not collide with anything today (built-in commands keep being added). Refer to agents by their full name
`regent:<agent>`.
