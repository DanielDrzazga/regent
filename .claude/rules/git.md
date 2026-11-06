# Git

- Never add AI authorship to commits or MR descriptions (`Co-Authored-By`, "Generated with…", a
  session link). `attribution` in `.claude/settings.json` enforces it.
- Commit: one line, no body, Conventional Commits in the imperative mood, e.g.
  `feat: add plugin manifest`.
- Every change on a `<type>/<change-name>` branch; it reaches `master` only after a green gate and
  smoke, because everyone installs the plugin from `master`.
- `git add` only with an explicit list of files.
