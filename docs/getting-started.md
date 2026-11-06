# Getting Started

First run of the framework in a project — step by step.

## 0. Prerequisite

Plugin `regent` installed from the GitHub marketplace or a local clone (see [README → Usage](../README.md#usage)).
Check that Claude Code sees it: type `/regent:` and Tab — the list should show `/regent:init`,
`/regent:propose`, `/regent:apply` and the other skills.

`ai/` (SDD artifacts) is tracked in the product repo as a whole — `/regent:init` makes sure no
ignore rule hides it.

### New machine — checklist

1. `claude plugin marketplace add https://github.com/DanielDrzazga/regent.git` and
   `claude plugin install regent@regent --scope user` (or `make install-local` in a clone).
2. In `~/.claude/settings.json` no AI attribution: `"attribution": { "commit": "", "pr": "" }`.
3. Statusline from the plugin (optional) — see [statusline.md](statusline.md).
4. New session: `/regent:` + Tab shows the skills; in a project with `ai/docs/` `/regent:status` works.
5. After a release (new entry in `CHANGELOG.md`): `claude plugin marketplace update regent && claude plugin update regent@regent`
   (local install: `git pull && make plugin-update` in the clone) and a new session.

## 1. `/regent:init` — configure the project

In the project directory:

```text
/regent:init            # auto-detection (--detect); alternatively /regent:init --manual
```

`/regent:init`:

- scans the repo (package.json, tsconfig, eslint, docker, structure, git log),
- generates `ai/docs/` from templates (`templates/docs/`) filled in with the project's realities,
- generates a `Makefile` (targets `test`, `lint`, `type-check`, `check`, ...),
- presents the result **for approval** — writes nothing without `yes`.

Generated (required): `stack/technology.md`, `patterns/architecture.md`,
`conventions/{naming,code-style,git-workflow}.md`. Optional (if detected):
`patterns/{di,testing,exception,logging}-patterns.md`, `patterns/frontend-patterns.md`
(when the project has a frontend).

> `ai/docs/observability/` is **not** generated (too environment-specific) — you create it manually
> if you maintain dashboards/alerts.

## 2. `/regent:status` — check the state

```text
/regent:status
```

Shows which `ai/docs/` files are filled in, active changes, the archive and suggestions.

## 3. First change: `/regent:propose`

```text
/regent:propose user-registration
```

1. **Interview** — one round: problem, behavior, scope, constraints.
2. **Challenge** — the agent establishes the facts in the code itself and asks you only about decisions, in rounds
   (up to 4 questions at once, with a recommendation). Most small changes pass right away (`ACCEPT`).
3. **Artifacts** in `ai/changes/user-registration/`: `proposal.md` (with the Decisions and assumptions log),
   `specs/*.md` (delta with AC), `design.md`, `tasks.md` (every task points to its AC).
4. **Consistency check** and saving as `Draft` — you read the full files with the reviewer checklist.
5. `approve` → `Approved` (only then will `/regent:apply` start) or `revise: ...`.

> **Existing project without specifications:** `ai/specs/` grows change by change — `/regent:init`
> deliberately does not generate it and you do not describe old code in advance. The first change that touches
> undescribed behavior adds it to the delta as ADDED ("first specification of existing
> behavior").

## 4. Implementation: `/regent:apply`

```text
/regent:apply user-registration
```

TDD per task: 🔴 test → 🟢 code → 🔵 refactor. Implemented by `regent:backend-dev` or `regent:frontend-dev`
per the task tag (`[BE]`/`[FE]`); the agent runs the tests itself (narrowly, per module/component);
the main session makes an atomic commit per task after a confirmed GREEN.

## 5. Verification: `/regent:verify`

```text
/regent:verify user-registration
```

9 stages (5-8 conditional). The result lands in `ai/changes/{name}/verification.md`.
PASS → you can archive; FAIL → fix via `/regent:apply`, re-run of the failed stages.

## 6. Closing: `/regent:archive`

```text
/regent:archive user-registration
```

Merges the delta specs into `ai/specs/` and moves the change to `ai/changes/archive/`.

## Next

- Regent for the whole team in a project initialized before Step 3.6: merge
  `templates/project-settings.json.template` into the project's `.claude/settings.json` and commit it
  ([README → Team setup](../README.md#team-setup-per-project)).
- Change state counted by the script: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh status`
  (all modes: [`sdd-check.md`](sdd-check.md)).
- Log instrumentation: `/regent:logging <path>` (requires `ai/docs/patterns/logging-patterns.md`).
- Analysis without changes: `/regent:explore <topic>`.
- Cycle details: [`workflow.md`](workflow.md).
