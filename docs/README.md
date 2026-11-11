# Documentation

Index of the framework documentation. Details in the files below.

## Guides

| Document | About |
|----------|--------|
| [getting-started.md](getting-started.md) | First run of the framework in a project — step by step |
| [workflow.md](workflow.md) | SDD workflow: commands, change cycle, delegation to agents |
| [writing-docs.md](writing-docs.md) | How to write documentation in this repo (style, structure) |
| [roadmap.md](roadmap.md) | Deliberate decisions (what is left out and why), postponed and implemented ideas |
| [evals.md](evals.md) | Skill evals and A/B comparison of a prompt change: quality, cost, tokens per model |

## Scripts

Helper scripts live in [`scripts/`](../scripts/). Each one has its description here. In terminal
commands `${CLAUDE_PLUGIN_ROOT}` means the plugin directory — when working on the plugin, it is the repo clone:

| Script | Documentation | About |
|--------|--------------|--------|
| [`scripts/statusline.sh`](../scripts/statusline.sh) | [statusline.md](statusline.md) | Statusline with a context counter and a warning threshold |
| [`scripts/sdd-check.sh`](../scripts/sdd-check.sh) | [sdd-check.md](sdd-check.md) | Deterministic validation of artifacts in a project: delta, tasks, AC coverage, merge, drift |
| [`scripts/dashboard.sh`](../scripts/dashboard.sh) | [dashboard.md](dashboard.md) | HTML kanban board of the SDD cycle (`/regent:dashboard`): `data.js` next to `templates/dashboard.html`, `--watch` follows the work live |
| [`scripts/usage.sh`](../scripts/usage.sh) | [dashboard.md](dashboard.md#usage-metrics) | Claude Code usage per change from the session transcripts: runs, Regent version, model, effort, agent, time, tokens, API-equivalent cost (`scripts/pricing.tsv`); `usage.md` in `/regent:archive` |
| [`scripts/hooks/git-guard.sh`](../scripts/hooks/git-guard.sh) | [`/regent:init` Step 3.5](../skills/init/SKILL.md) | The plugin's PreToolUse hook: in projects with `ai/docs/` blocks `git add .`/`-A`, `git commit -a`, `--no-verify`, `-c core.hooksPath`, AI attribution in commits and PRs; `GIT_GUARD_FORCE=1` forces |
| [`scripts/hooks/session-context.sh`](../scripts/hooks/session-context.sh) | script header | SessionStart/SubagentStart hook: injects `context/role.md` always, with `ai/docs/` `sdd.md` and `subagent.md` (session and subagent) and `sdd-map.md` (session only) |
| [`scripts/hooks/dashboard-refresh.sh`](../scripts/hooks/dashboard-refresh.sh) | [dashboard.md](dashboard.md#running-it) | SessionStart/Stop/SubagentStop/PostToolUse hook: in projects with `ai/` rebuilds the HTML board in the background (`dashboard.sh --hook`), one build at a time, tools at most every 20 s |
| [`scripts/hooks/sync-bin.sh`](../scripts/hooks/sync-bin.sh) | [statusline.md](statusline.md) | SessionStart hook: copies `statusline.sh` and `session-tokens.sh` to `${CLAUDE_PLUGIN_DATA}/bin/` |
| [`scripts/framework-lint.sh`](../scripts/framework-lint.sh) | [CONTRIBUTING.md](../CONTRIBUTING.md#local-validation) | Framework consistency: frontmatter, references, skill tables, agent prefix, prompt regressions |
| [`scripts/session-tokens.sh`](../scripts/session-tokens.sh) | script header | Token usage in a Claude Code session per prompt (with subagents), from the `~/.claude/projects/` transcript |
| [`scripts/eval-ab.sh`](../scripts/eval-ab.sh) | [evals.md](evals.md) | A/B of two refs on one eval tag: two worktrees, both runs, the noise threshold from the baseline, keep/discard, a row in `evals/results/ab.tsv` |
| [`scripts/eval-score.sh`](../scripts/eval-score.sh) | [evals.md](evals.md) | Runs a skill's eval set, computes one result line (quality, cost, tokens per model, time, noise) and decides keep/discard |

When a new script is added to `scripts/` — add a row to the table above and (if it
needs explanation) a separate `docs/<name>.md` file.
