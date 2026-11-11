# Skill evals and A/B comparison

Every prompt change that may affect quality or cost is compared with a baseline on a fixed eval set
before merge. The eval sets live in `evals/<skill>/`, run with `claude plugin eval` on the synthetic
`notes-app` project, and `scripts/eval-score.sh` turns a run into one result line and a keep/discard
decision. The script counts, not the model.

## Eval sets

| Set | Cases | Covers |
|-----|-------|--------|
| `evals/propose/` | 1 train, 1 holdout | an S change and an M change across BE and FE: delegation, artifacts, AC coverage, API contract |
| `evals/apply/` | 6 train, 5 holdout | routing to `regent:backend-dev` / `regent:frontend-dev` / `regent:dba`, TDD, a commit and a trace per task, `--tasks`, `/regent:bugfix` |
| `evals/verify/` | 1 diagnostic | stage delegation on a UI change with user data |
| `evals/wiki/` | 3 train, 4 holdout | `init`, `ingest`, `confirm`, `query`, `lint`, `lint --fix`, `sync` |

Tags: `<skill>-train` (tune against these), `<skill>-holdout` (check only, never tune against
them), `<skill>-diag` (measurement, no tuning). A case is `evals/<skill>/<case>/case.yaml` plus a
`scaffold.sh` that calls the set's shared scaffold. The test project's own documents are in Polish on
purpose: the artifacts Regent writes must still be in English (`context/role.md` → Language).

## Requirements

- Claude Code with `claude plugin eval`, and `jq`.
- On Linux `bubblewrap` and `socat` — the eval runs Bash only in a sandbox (macOS has it built in).
  Without a sandbox use `--no-bash`, and compare only with a baseline also made with `--no-bash`.
- Evals spend your plan's usage: one case run is a full skill run. Plan them around the 5-hour window.
- The eval refuses to run Bash when `~/.docker` holds a symlink — and Docker Desktop recreates its
  CLI plugin links there on every start. Run the evals with an empty `HOME` instead, logged in with a
  long-lived token from `claude setup-token` (it uses your plan, not the API). Keep the token in the
  macOS keychain, not in a file:

  ```bash
  claude setup-token                                                    # once; copy the token
  security add-generic-password -a "$USER" -s regent-eval -w '<token>'  # once
  export CLAUDE_CODE_OAUTH_TOKEN=$(security find-generic-password -s regent-eval -w)
  export EVAL_CLEAN_HOME=1                                              # then eval-ab.sh / eval-score.sh as usual
  ```
- On macOS the eval's Bash sandbox blocks `/usr/bin/git` (the Xcode shim cannot write its `xcrun_db`
  cache), and neither `PATH` nor `ZDOTDIR`/`BASH_ENV` from outside reach the Bash tool. Every case therefore
  tells the model in `append_system_prompt` to use `/opt/homebrew/bin/git` when `/usr/bin/git` fails — a
  fact about the machine, the same on both sides of an A/B. Without it 1–2 of 5 `apply` runs gave up on the
  commits (tasks left open) and the rest spent turns finding a working git. This affects only evals, not
  projects that use Regent. Without Homebrew git: `brew install git`. Private cases need the same sentence.

## A/B of a prompt change

One command compares two refs — it creates both worktrees (so the plugin your sessions use does not
change), copies `evals/` into a ref that has none, runs both sides, takes the noise threshold from the
baseline and appends the result to `evals/results/ab.tsv`:

```bash
bash scripts/eval-ab.sh main perf/<change> apply-train            # 3 runs per case on each side
bash scripts/eval-ab.sh main perf/<change> apply-holdout --runs 1 # holdout: read quality and cases
```

On a holdout tag only quality and the per-case scores count; a `discard` for cost alone is not a
quality failure.

**Usage limits.** A run that reports a usage or rate limit stops the A/B at once (exit 4), so the rest of
the window is not spent on runs that would fail. A clean baseline is cached in
`evals/results/base-cache.tsv` (per base commit, tag, runs and eval version): rerun the same command
after the reset and only the candidate runs; another candidate on the same tag reuses it too
(`--fresh-base` forces a new one). `--budget USD` caps each side's cost. The manual steps behind it:

```bash
git worktree add ../regent-ab -b perf/<change> main
cd ../regent-ab

# 1. Baseline — at least 3 runs per case, so spread= gives the noise threshold
bash scripts/eval-score.sh run . apply-train evals/results/base.json --runs 3 --files skills/apply/SKILL.md

# 2. Make the change, then the candidate run
bash scripts/eval-score.sh run . apply-train evals/results/cand.json --runs 3 --files skills/apply/SKILL.md

# 3. Decide — noise = max(0.05, baseline spread), tnoise = max(0.05, baseline tspread)
bash scripts/eval-score.sh decide "<baseline line>" "<candidate line>" --noise 0.12 --tnoise 0.15

# 4. Before merge — holdout once, it must not drop
bash scripts/eval-score.sh run . apply-holdout evals/results/cand-holdout.json --files skills/apply/SKILL.md
```

Results go to `evals/results/` (ignored by git). `EVAL_KEEP_TRACES=1` keeps each run's sandbox
(the trace and the test project as the skill left it) for a failed grader you want to look into. Record the baseline and candidate lines in the PR.

## Private eval sets

Cases on private code (e.g. a closed-source service) never go into this repo: `evals/` ships with the plugin, and
the repo is public. Keep them in a directory outside the repo with the same layout
(`<dir>/<set>/<case>/case.yaml` + `scaffold.sh`) and pass it for one run:

```bash
bash scripts/eval-ab.sh v1.1.0 main neg-wiki --runs 1 --private-evals ~/regent-private-evals
```

The sets are copied only into the temporary worktrees, which are removed at the end. A private scaffold
takes the code straight from a local clone at a pinned commit (`git archive <sha> | tar -x`), so only
tracked files of that commit reach the eval — no untracked local config or secrets — and it excludes
encrypted paths (git-crypt) explicitly. With `EVAL_CLEAN_HOME=1` `$HOME` is a temporary directory, so a
scaffold uses absolute paths. The code reaches Anthropic exactly as in a normal Claude Code session on
that repo.

## The result line

```text
quality=0.95 cost=1.21 tokens=1840522 models=opus:402113,sonnet:1438409 seconds=268 prompt=14106 spread=0.18 tspread=0.21 cases=two-tasks:1,… failed=- errors=0
```

The fields and the decide rule are described in the header of `scripts/eval-score.sh`. In short:
quality must not drop and no case may fall from 1.00; then a candidate is kept when it is cheaper
beyond the noise, faster beyond the time noise at no extra cost, or equal with a shorter prompt.
`models=` shows where the tokens went — use it to check that a model change (for example Opus → Sonnet
for a subagent) moved tokens as intended.

## Adding a case

1. Copy the closest case directory and rename it; `name` must be unique and start with the set name.
2. Prefer deterministic graders (`tool_used`, `regex`, `file_exists`); use `llm` only for what a
   pattern cannot check, with a criterion that states PASS and FAIL.
3. Run the scaffold by hand in an empty directory and check the starting state before the first run.
4. A change of the `notes-app` fixture changes the `wiki` sync hash: `evals/wiki/scaffold.sh` in sync
   mode reports the new one — update it there and in `evals/wiki/holdout-sync/case.yaml`.
