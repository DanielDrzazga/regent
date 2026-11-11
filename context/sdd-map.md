# Regent — map of SDD skills and agents

> SDD rules: `context/sdd.md`.

## All commands

Skills other than `/regent:status` are run only by the user (`disable-model-invocation`). When
the flow leads to another skill (e.g. diagnosis → `/regent:bugfix`), give the ready command
to type instead of reproducing its steps.

| Command | Role |
|---------|------|
| `/regent:init` | Initialization of `ai/docs/` (stack, patterns, conventions) + Makefile |
| `/regent:propose` | Spec before code (proposal, specs, design, tasks) |
| `/regent:apply` | TDD implementation (Red → Green → Refactor) |
| `/regent:verify` | 9-stage verification |
| `/regent:archive` | Merge delta specs → main, retrospective, move to archive (`--abandon` — abandonment) |
| `/regent:bugfix` | Bug fix in dev/staging (with a regression test) |
| `/regent:hotfix` | Critical fix in production (max 30 min, 3 files) |
| `/regent:refactor` | Refactoring without behavior change (INVARIANTS) |
| `/regent:revise` | Update of `ai/docs/` when the approach changes |
| `/regent:logging` | Code instrumentation with logs per `logging-patterns.md` |
| `/regent:testing` | Writing and verifying tests |
| `/regent:code-review` | Peer review of changes |
| `/regent:commit` | Atomic commits per git-workflow |
| `/regent:debugging` | Systematic diagnosis (fix via `/regent:bugfix`) |
| `/regent:dependency-update` | Dependency updates and security patches |
| `/regent:status` | Overview of the project state |
| `/regent:dashboard` | HTML kanban board of the SDD cycle (`--watch` — live) |
| `/regent:explore` | Read-only analysis without commits |
| `/regent:wiki` | Business wiki in Obsidian (`ai/wiki/`) — outside the SDD cycle |

## Agents (delegated by commands)

`regent:architect`, `regent:spec-writer`, `regent:backend-dev`, `regent:frontend-dev`,
`regent:code-reviewer`, `regent:qa-engineer`, `regent:dba`, `regent:security-auditor`, `regent:logging-engineer`
— the model per agent is defined in the plugin's `agents/*.md`
(Opus for design/security/review, Sonnet for implementation).

**Delegation rule (key!):** the agent's model works ONLY when the command actually
runs it as a subagent (the Task tool). When a command names an agent —
**delegate to the subagent by the full name `regent:<agent>`**, do not do its work "in place"
in the main session (then it runs on the session's model, not on the agent's model).

**Subagent contract** (question loop, artifacts for approval): `context/subagent.md`.

| Command | Subagent(s) — full name |
|---------|-------------------------------|
| `/regent:init` | `regent:architect` |
| `/regent:propose` | `regent:spec-writer` (+ `regent:architect` for design.md) |
| `/regent:apply` | `regent:backend-dev` (`[BE]`/untagged tasks) + `regent:frontend-dev` (`[FE]` tasks) + `regent:dba` (`[DB]` tasks) |
| `/regent:verify` | `regent:code-reviewer`, `regent:qa-engineer`, `regent:dba`, `regent:security-auditor` |
| `/regent:code-review` | `regent:code-reviewer` |
| `/regent:logging` | `regent:logging-engineer` |
| `/regent:testing` | `regent:qa-engineer` |
| `/regent:bugfix` | `regent:backend-dev` / `regent:frontend-dev` — by the bug's area |
| `/regent:hotfix` | `regent:backend-dev` / `regent:frontend-dev` — by the bug's area |
| `/regent:refactor` | `regent:backend-dev` / `regent:frontend-dev` by area (impl); `/regent:propose` and `/regent:verify` delegate themselves |
| `/regent:revise` | `regent:architect` (also `logging-patterns.md` — `regent:logging-engineer` stops when the pattern is missing) |
| `/regent:dependency-update` | `regent:security-auditor` (audit) + `regent:backend-dev` / `regent:frontend-dev` by package (code adaptation) |
| `/regent:debugging` | — (diagnosis in the main session; fix via handoff to `/regent:bugfix`) |
| `/regent:archive` | `regent:spec-writer` (only the delta → main specs merge step) |
| `/regent:explore` | `regent:architect` (read-only — analysis, no files/commits) |
| `/regent:wiki` | `regent:architect` (domain analysis; writes the pages in `init`, a diff description in `ingest`) |

No delegation (mechanical, they run in the main session): `/regent:commit`, `/regent:status`, `/regent:dashboard`.
