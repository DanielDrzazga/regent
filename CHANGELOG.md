# Changelog

Regent releases. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions:
[SemVer](https://semver.org/) — MAJOR: a change that needs action in projects (renamed skill, `ai/` layout,
Makefile contract), MINOR: new skill/agent/step, PATCH: fixes and prompt tuning.
Release procedure: [CONTRIBUTING.md → Releases](CONTRIBUTING.md#releases).

## [1.4.1] - 2026-11-12

### Fixed

- Eval `apply-train-fe-two`: the `count-plural-forms` judge asked for "an element", while the spec asks
  `renderResultCount` to return the HTML string `<p role="status">…</p>` — correct code failed in about
  17 of 19 runs. The criterion now names the string.

## [1.4.0] - 2026-11-11

### Added

- Public release on GitHub under the Apache License 2.0 (`LICENSE`, `NOTICE` with the author attribution,
  `license`/`homepage`/`repository` in the manifest).
- README: badges, an Author and a License section; `CITATION.cff` for GitHub's "Cite this repository".

### Changed

- The marketplace source is `https://github.com/DanielDrzazga/regent.git` (`make install`, README,
  getting-started, the project settings template).
- `main` is the release branch: `make release` runs on `main` and compares with `<remote>/main`; the repo
  rules, CONTRIBUTING, README and evals docs say `main` and PR instead of `master` and MR.

### Removed

- The internal token optimization plan (`docs/plans/`).

## [1.3.10] - 2026-11-10

### Fixed

- Evals on macOS: every case tells the model to use `/opt/homebrew/bin/git` when `/usr/bin/git` fails. The
  eval's Bash sandbox blocks the Xcode shim, so 1–2 of 5 `/regent:apply` runs could not commit (tasks left
  open) and the rest spent turns finding a working git. The "apply does not close tasks" failures in the eval
  results came from this, not from the skill. Baseline caches are invalidated (new eval version).

## [1.3.9] - 2026-11-09

### Changed

- README and getting-started say that plugin updates are not automatic (auto-update is off by default for
  this marketplace) and how to turn it on or update by hand. `make plugin-status` also shows the latest
  release tag on the marketplace remote.

## [1.3.8] - 2026-11-08

### Fixed

- `/regent:wiki init` names things with the glossary term where the code uses another word (a class named
  after a bid for what the glossary calls a Proposal), and keeps `_Avoid:_` words to the "Don't say"
  section. On a real service module the index on Sonnet took the code's word in 1 of 3 runs (Opus: 0 of 4).

## [1.3.7] - 2026-11-08

### Fixed

- "Write in one turn" is `regent:architect`'s rule only (its definition and the `/regent:wiki init`
  prompt), no longer part of the subagent contract every agent gets. In the contract it disturbed the
  multi-step `/regent:propose` flow: since v1.3.6 `tasks.md` was missing or unsized in 2 of 7 runs
  (0 of 6 on v1.3.4), at no saving (propose cost +2–7%). `wiki init` keeps the gain.

## [1.3.6] - 2026-11-08

### Fixed

- Subagents that write files (`regent:architect`, `regent:spec-writer`) write them all in one turn, after
  all reading. Writing one file per turn resent the whole context each time: on a real service module
  `/regent:wiki init` cost +41% (Opus) against v1.1.0, with 3× the tokens.
## [1.3.5] - 2026-11-08

### Added

- `eval-ab.sh --private-evals DIR` — eval sets on private code, kept outside the repo and copied only into
  the temporary worktrees for one run ([docs/evals.md](docs/evals.md)). Nothing changes in projects.

## [1.3.4] - 2026-11-06

### Changed

- Every agent sets `effort` explicitly — `high` for `regent:architect`, `regent:code-reviewer` and
  `regent:security-auditor`, `medium` for the others. Without it a subagent on another model than the
  session ran at that model's default, and on the session's model at the user's `/effort`, so the same
  agent reasoned differently for every teammate. The lint requires the field.
## [1.3.3] - 2026-11-08

### Fixed

- Evals: `red-before-green` in the apply set missed every RED phase printed by the node:test spec
  reporter (`ℹ fail N`) and RED runs that fail on a module that does not exist yet — it failed 9 of 15
  runs although the traces show the failing test before the code. Nothing changes in projects.

## [1.3.0] - 2026-11-06

### Changed

- `/regent:init` and `/regent:wiki init` run `regent:architect` on Sonnet by default (the call's model
  overrides the agent's Opus) — both run once per repo across many repos. `--model opus` keeps Opus
  for a repo the team marks as critical. The other `regent:architect` calls are unchanged.
## [1.2.0] - 2026-11-06

### Changed

- Artifacts are written once: `regent:spec-writer` and `regent:architect` write their files themselves
  (only the paths the prompt names, under `ai/`) and report the paths — no more full content in the
  report for the main session to write again. `/regent:propose` keeps the `Status: Draft` gate on the
  written files; in `/regent:init` and `/regent:wiki init` a rejection removes the written drafts.
  `regent:architect` gets `Write, Edit`; `/regent:explore` stays read-only because its prompt names no
  paths (a lint rule keeps it so). `/regent:revise` and `/regent:wiki ingest` keep their diff reports.
## [1.1.1] - 2026-11-06

### Added

- Skill evals in `evals/` (propose, apply, verify, wiki) on the `notes-app` test project and
  `scripts/eval-score.sh` — one result line per run (quality, cost, tokens, tokens per model, time,
  noise) and a keep/discard decision; `scripts/eval-ab.sh` runs the whole A/B of two refs in one
  command, stops on a usage limit and caches clean baselines ([docs/evals.md](docs/evals.md)).
  Not used by the plugin at runtime; nothing changes in projects.

## [1.1.0] - 2026-11-05

### Changed

- Release model: `master` is the release branch and every merge is tagged `v<version>` — the `stable`
  branch and the `#stable` source are gone. Install source, `make install` and the project template use the
  plain GitLab URL again. Registered with `#stable`: run `make plugin-reinstall`.
- `make release` only tags and pushes the tag.

### Added

- Lint: the plugin version must have a `CHANGELOG.md` entry and must not be already released (tagged on
  another commit) — every MR bumps the version.

## [1.0.0] - 2026-11-05

First versioned release.

### Added

- Versioning: `version` in `.claude-plugin/plugin.json`, `v<version>` tags and the `stable` release
  channel; `make bump` and `make release`.
- `/regent:init` Step 3.6 — Regent declared in the project's committed `.claude/settings.json`
  (`templates/project-settings.json.template`), so the whole team gets the harness with the repo.

### Changed

- The GitLab marketplace source is pinned to `#stable` (`make install`, README, project template):
  plugin updates arrive per release, not per commit on `master`.
