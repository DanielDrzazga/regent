---
description: SDD project initialization — fill ai/docs/ (stack, patterns, conventions) + Makefile
disable-model-invocation: true
argument-hint: [--detect | --manual]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:init — SDD project initialization

**Goal:** Set up the project to work with the SDD Framework — fill `ai/docs/` based on the existing code or an interview.

> Not to be confused with the built-in Claude Code `/init` (generates `CLAUDE.md`) — this command fills `ai/docs/`.

```
/regent:init [--detect | --manual]

Example:
/regent:init --detect        (auto-scan the repo)
/regent:init --manual        (interactive interview)
/regent:init                 (default: --detect)
```

---

## Agent (delegation — REQUIRED)

Delegate scanning the repo and preparing the `ai/docs/` content to the `regent:architect` subagent
(model: opus, launch with the Task tool). Do not do it "in place" in the main session —
otherwise the model from `agents/architect.md` will not be used.

**Contract:** `regent:architect` is read-only — **it returns the content of the `ai/docs/` files in its report**;
the main session presents the results (Step 4) and writes the files after approval. The interview
in `--manual` mode is run by the main session, which passes the answers in the prompt.

---

## Step 0: Check whether ai/docs/ already exists

```
If ai/docs/stack/technology.md exists and is not empty:
  → "Project already initialized. Use /regent:revise to update ai/docs/."
  → STOP (unless the user confirms reinitialization)
```

---

## Step 0.5: `ai/` tracked in the repo

`ai/` holds the SDD artifacts (`docs/`, `specs/`, `changes/` active and archived) and is tracked
in the product repo as a whole, so the team sees every decision and the plan travels with the MR.

Check: `git check-ignore -q --no-index ai/` (`--no-index`: the result depends on ignore rules,
not on whether anything in `ai/` is already tracked).

- not ignored (exit 1) → continue. Note in the Step 4 result that the first real commit of `ai/`
  happens in `/regent:apply` or `/regent:bugfix` together with the first task — this step only
  writes files and commits nothing;
- ignored (exit 0, usually by a global rule) → add `!/ai/` to the **project** `.gitignore` (a
  pattern closer to the repo overrides `core.excludesfile` — standard git negation) and check again.

---

## Step 1: Detect existing files (--detect)

Delegate to the `regent:architect` subagent — it scans the repo and in its report also proposes 3 small (S)
candidates for the first change: TODO/FIXME/HACK, modules without tests, swallowed exceptions:

```bash
# Package manager & dependencies
cat package.json 2>/dev/null || cat requirements.txt 2>/dev/null || cat go.mod 2>/dev/null || cat Cargo.toml 2>/dev/null

# TypeScript config
cat tsconfig.json 2>/dev/null

# Linter / Formatter
cat .eslintrc* 2>/dev/null || cat .prettierrc* 2>/dev/null

# Docker
cat Dockerfile 2>/dev/null || cat docker-compose.yml 2>/dev/null

# Existing structure
find src/ -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" \) 2>/dev/null | head -50

# Frontend? (UI deps in package.json, bundler config, component files, monorepo workspaces)
grep -E '"(react|vue|svelte|@angular/core|solid-js)"' package.json 2>/dev/null
ls index.html vite.config.* next.config.* nuxt.config.* astro.config.* 2>/dev/null
find src apps packages -maxdepth 4 \( -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" \) 2>/dev/null | head -10

# CI/CD / deployment? (pipeline, containerization)
ls .github/workflows/ .gitlab-ci.yml Jenkinsfile .circleci/ 2>/dev/null

# Git history (last 20 commits for context)
git log --oneline -20 2>/dev/null

# Existing tests
find . \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | head -20

# Candidates for the first change (onboarding)
grep -rnE "TODO|FIXME|HACK" src/ 2>/dev/null | head -20
```

### Detected elements:

| Element | Source | Target |
|---------|--------|--------|
| Runtime & language | package.json, tsconfig | `stack/technology.md` |
| Framework | dependencies | `stack/technology.md` |
| Architecture | folder structure, imports | `patterns/architecture.md` |
| Reference implementations | instances of key patterns in the code (consumer, event+handler, repo) | `patterns/architecture.md` (Reference Implementations section) |
| Naming | existing files, code | `conventions/naming.md` |
| Code style | eslint, prettier config | `conventions/code-style.md` |
| Git workflow | git log, branches | `conventions/git-workflow.md` |
| Testing | test files, jest config | `patterns/testing-patterns.md` |
| DI patterns | imports, constructors | `patterns/di-patterns.md` |
| Logging | logger imports (pino/winston/CustomLoggerService), LoggerModule | `patterns/logging-patterns.md` |
| Frontend | UI deps, bundler config, `*.tsx/*.vue/*.svelte` files, workspaces, UI test tool | `stack/technology.md` (Frontend section) + `patterns/frontend-patterns.md` |

---

## Step 1-alt: Interview (--manual)

If `--manual` or the repo is empty:

### Round 1: Stack
```
1. Which runtime and language? (Node.js + TypeScript, Python, Go, ...)
2. Which backend framework? (NestJS, Express, FastAPI, ...)
3. Which database? (PostgreSQL, MySQL, MongoDB, ...)
4. Package manager? (npm, pnpm, yarn)
5. Does the project have a frontend? Which framework and bundler? (React+Vite, Next, Vue, ... / none)
```

If frontend = yes — a short follow-up round:
```
1. State management? (server-state + global client)
2. Styling and component library?
3. Component tests / browser E2E? (tools)
```

### Round 2: Architecture
```
1. Architecture type? (Modular Monolith, Microservices, Monolith)
2. Layer structure? (Domain/Application/Infrastructure/Interface)
3. DI container? (NestJS built-in, InversifyJS, manual)
4. Error handling pattern? (custom exceptions, HTTP errors)
```

### Round 3: Conventions
```
1. File naming? (kebab-case, camelCase, PascalCase)
2. Naming in code? (camelCase vars, PascalCase classes)
3. Formatter/Linter? (Prettier, ESLint, ...)
4. Git branching? (trunk-based, gitflow, ...)
5. Commit format? (conventional commits, custom)
```

**The interview is run by the MAIN SESSION — wait for the user's answers after each round,
then pass the full set of answers to the `regent:architect` subagent.**

---

## Step 2: Generate ai/docs/

Based on detection or the interview, fill in:

### REQUIRED (always generated):
1. `ai/docs/stack/technology.md` — technology stack
2. `ai/docs/patterns/architecture.md` — architectural patterns
   (including the **Reference Implementations** section: for each pattern from the Key Patterns table
   the architect points to 1-2 real, exemplary implementations in the code — full paths from `src/`
   + 1 sentence. This lets later commands read the indicated file instead of scanning `src/`.
   The **Non-negotiable principles** section: only rules already enforced — linter rules, CI gates,
   ADRs; nothing like that detected → remove the section.)
3. `ai/docs/conventions/naming.md` — naming conventions
4. `ai/docs/conventions/code-style.md` — code style
5. `ai/docs/conventions/git-workflow.md` — git workflow

### OPTIONAL (generated if detected):
6. `ai/docs/patterns/di-patterns.md` — DI patterns
7. `ai/docs/patterns/testing-patterns.md` — testing patterns
8. `ai/docs/patterns/exception-patterns.md` — exception handling
9. `ai/docs/patterns/logging-patterns.md` — logging pattern (source of truth for `/regent:logging`)
10. `ai/docs/patterns/frontend-patterns.md` — frontend patterns (source of truth for `regent:frontend-dev`;
    generated ONLY when a frontend was detected; then also fill the Frontend section in technology.md —
    in backend-only projects remove that section)
11. `ai/docs/domain/glossary.md` — glossary of the domain language (terms, relations, resolved
    ambiguities). Generate it when **real domain vocabulary** emerges from module/entity names in `src/`
    (min. 3 terms whose meaning cannot be guessed from the name alone),
    or when the user provided it in the interview. In a purely technical project (library, CLI,
    tool) skip it — **an empty glossary does more harm than none**: it costs context
    on every read and invites dumping implementation decisions there.

**Fill from the templates** in `${CLAUDE_PLUGIN_ROOT}/templates/docs/` (one template = one `ai/docs/` file) — replace placeholders with detected values, do not copy placeholders.

> ❗ `logging-patterns.md`: do NOT scaffold logger code (that is the scope of `/regent:logging`, not `/regent:init`).
> Logger detected → describe its path and API in the template. NOT detected → generate the file
> with the status "to be implemented", so `/regent:logging` knows there is no standard.

### NOT generated by /regent:init (optional, authored):
- `ai/docs/observability/` (Kibana dashboards/alerts, `maintenance.md`) — too environment-specific
  (index patterns, Slack webhooks). Created manually when needed. If it exists,
  `logging-patterns.md` should link to it ("Synchronization with observability" section).

---

## Step 3: Generate the Makefile

Based on the detected stack, copy and fill the matching template:

| Stack | Template |
|---|---|
| Node.js / TypeScript | `${CLAUDE_PLUGIN_ROOT}/templates/Makefile.node.template` |
| Other stack (Python, Go, Rust, …) | no template → generate the Makefile manually with the same set of targets: `install`, `lint`, `type-check`, `format`, `test`, `test-unit`, `test-integration`, `test-coverage`, `check`, `build`, `deps-outdated`, `deps-audit` — using the detected stack's tools (e.g. `pytest`, `ruff`, `go test`, `cargo test`) |

The Makefile targets are the **framework contract** — the commands (`/regent:apply`, `/regent:verify`, `/regent:commit`,
`/regent:dependency-update`) call `make …`, not the raw stack tools.

Replace in the template:
- `PKG_MANAGER` — the detected package manager (`npm` / `pnpm` / `yarn`)
- Database section — uncomment the block matching the detected ORM (Prisma / TypeORM / other)
- Frontend section — uncomment the `test-component` target when a frontend was detected

Save as `Makefile` in the project root directory.

If a `Makefile` already exists → do NOT overwrite: propose the missing targets as a diff to append.

---

## Step 3.5: Git guardrails in the project

The rules "`git add` only with a list of files" and "no `--no-verify`" live in the prompts, and they are enforced
deterministically by the `scripts/hooks/git-guard.sh` hook, **registered by the plugin** (`hooks/hooks.json`):
it blocks `git add .` / `-A` / `--all` / `-u`, `git commit -a`, `--no-verify` and `-c core.hooksPath`
as well as AI attribution in commit and PR text (`Co-Authored-By` with Claude, "Generated with Claude…"),
and tells the agent what to do instead. It works in every project with `ai/docs/`, so from the moment files are written in Step 4 it protects
this project too — with no entry in its `.claude/settings*.json` and without asking for consent.

## Step 4: Presentation and approval

```markdown
## SDD initialization — Results

### Filled files:
✅ ai/docs/stack/technology.md
✅ ai/docs/patterns/architecture.md
✅ ai/docs/conventions/naming.md
✅ ai/docs/conventions/code-style.md
✅ ai/docs/conventions/git-workflow.md
⬜ ai/docs/patterns/di-patterns.md (optional — not detected)
✅ ai/docs/patterns/testing-patterns.md
⬜ ai/docs/patterns/exception-patterns.md (optional — not detected)
⬜ ai/docs/domain/glossary.md (optional — no domain vocabulary)
✅ ai/docs/patterns/logging-patterns.md (detected: nestjs-pino)
⬜ ai/docs/patterns/frontend-patterns.md (optional — no frontend detected)
✅ Makefile (Node.js, pnpm, Prisma)
✅ git-guard — plugin hook active (project has ai/docs/); old entry in .claude/settings*.json: none / removed
✅ ai/: tracked in the repo — first commit in apply/bugfix

### Summary:
- Runtime: Node.js 20 + TypeScript 5.3
- Framework: NestJS 10
- Database: PostgreSQL 16
- Architecture: Modular Monolith, 4 layers

### Candidates for the first change (to practice the cycle):
| # | Candidate | Source | Size | Command |
|---|-----------|--------|------|---------|
| 1 | [e.g. email validation in registration] | [TODO in src/…:42] | S | `/regent:propose …` |
| 2 | [e.g. module without tests] | [no tests in src/…] | S | `/regent:testing …` |
| 3 | [e.g. swallowed exception] | [empty catch in src/…:88] | S | `/regent:bugfix …` |

Do you approve? (yes/no/revise [file])
```

**Wait for approval.** After `yes` → the main session writes the `ai/docs/` files + `Makefile`
from the content returned by `regent:architect`. `revise [file]` → continue the same subagent
with the corrections.

---

## IMPORTANT Rules

✅ **ALWAYS:**
- Scan the repo BEFORE generating
- Present the results FOR approval
- Fill templates with concrete values (not placeholders)
- Mark what was detected automatically and what needs verification
- Uncertain values → ask the user
- Existing, filled file → confirmation before overwriting

---

## Next steps after /regent:init

```
→ /regent:propose "first change"
→ /regent:status (status overview)
```

Timeline: 10-20 minutes
