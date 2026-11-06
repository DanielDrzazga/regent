# Changelog

Regent releases. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions:
[SemVer](https://semver.org/) — MAJOR: a change that needs action in projects (renamed skill, `ai/` layout,
Makefile contract), MINOR: new skill/agent/step, PATCH: fixes and prompt tuning.
Release procedure: [CONTRIBUTING.md → Releases](CONTRIBUTING.md#releases).

## [1.1.1] - 2026-11-06

### Changed

- Published on GitHub: the marketplace source, `make install` and the project template use
  `https://github.com/DanielDrzazga/regent.git`.

## [1.1.0] - 2026-11-05

### Changed

- Release model: `master` is the release branch and every merge is tagged `v<version>` — the `stable`
  branch and the `#stable` source are gone. Install source, `make install` and the project template use the
  plain GitHub URL again. Registered with `#stable`: run `make plugin-reinstall`.
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

- The GitHub marketplace source is pinned to `#stable` (`make install`, README, project template):
  plugin updates arrive per release, not per commit on `master`.
