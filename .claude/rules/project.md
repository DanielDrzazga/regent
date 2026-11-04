# Regent — project context

- Regent is a developer tool: an SDD (Spec-Driven Development) framework shipped as a Claude Code
  plugin. No components that need a build — the plugin works right after installation.
- This repo does not run the SDD cycle (no `ai/`). A change goes on its own branch and reaches
  `main` through an MR after the gate: `make check` (framework lint + `claude plugin validate .`)
  (the only allowed warning: missing `version`) and a smoke run in a test project.
- This repo is the source of truth for the framework. Deliberate decisions and postponed ideas:
  `docs/roadmap.md`.
- Language: the „Język" rule in `context/role.md`.
