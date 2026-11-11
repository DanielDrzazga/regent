# Dashboard — the SDD cycle as a kanban board

`/regent:dashboard` (or `scripts/dashboard.sh` directly) shows every change of a project in HTML: the
**Board** tab has a column per cycle stage and a card per active change, the **Archive** tab a table of
closed changes, and both open the details of a change in a side panel. It is the visual counterpart of
`/regent:status`: the same files on disk, the same "Where am I?" stages.

## Running it

Nothing to run while you work in Claude Code. In a project with `ai/`, the plugin's hooks rebuild the board
in the background (`scripts/hooks/dashboard-refresh.sh`, registered in `hooks/hooks.json`):

| Hook | When | Build |
|------|------|-------|
| `SessionStart` | a session starts | full (also checks every archived file) |
| `Stop`, `SubagentStop` | a turn or a subagent ends | quick |
| `PostToolUse` (Write, Edit, Bash…) | tools work during a long turn | quick, at most every 20 s |

The hook returns at once (about 0.1 s) and leaves the build to a background process, so Claude does not wait.
Hooks run outside the model: no tokens, no plan limit. The board has one path per project,
`~/.cache/regent/boards/<project>-<checksum>/index.html` (`REGENT_BOARDS` changes the root), so a browser tab
left open follows every session of the project. Two sessions in one project share the board: one build runs at
a time, and a request during a build makes it run once more. When the last session ends nothing is left running;
the board keeps its last state.

`/regent:dashboard` builds the board at once and opens it in the browser. Outside Claude Code, in the project root:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh --open             # build, open the browser
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh --watch            # rebuild every 3 s until Ctrl-C
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh --watch 10 --out .board
```

The script prints `Board: <path>`; nothing lands in the project.

## How it works

```
ai/changes/*/**.md ────────► dashboard.sh ──► data.js ◄── every 2 s ── index.html (copy of templates/dashboard.html)
ai/changes/archive/*/**.md ─┘      └────────► archive/<dir>.js ◄── when a change is opened ──┘
```

- `data.js` holds the files of every active change, its last commit date, the date and subject of every
  `commit: <hash>` recorded in its `tasks.md`, the drift of verified changes (`sdd-check.sh drift`), the
  requirements index (`sdd-check.sh index`) and **one summary per archived change** (type, status, ticket,
  dates, tasks done/total, size, verdict, the summary line). It is a single `window.regentBoard({...})`
  call, rewritten only when the data changed.
- `archive/<dir>.js` holds the files and commits of one archived change. The page loads it only when that
  change is opened, so the size of `data.js` grows by one short line per archived change, not by its files.
- The archive part is rebuilt only when the archive changed: the first build of a run compares every file
  under `ai/changes/archive/` with the last build; a `--watch` tick checks only the mtime of
  `ai/changes/archive/`, which changes when `/regent:archive` moves a change in (on Windows a stat per file
  costs seconds with a long history). An edit inside an already archived change shows on the next run.
- `index.html` is a static page without dependencies. It loads its data through `<script>` tags (that
  works from `file://`, where `fetch` is blocked), polls `data.js` every 2 s and re-renders only on a change,
  so an open side panel and its scroll survive the refresh.
- For active changes the page derives the fields itself: `Status`, `Type`, `Ticket` from `proposal.md`,
  tasks and `Size` from `tasks.md`, `Verdict`, `Date`, the stage table from `verification.md`, the
  "Decisions and assumptions" log for the timeline.
- File content is HTML-escaped before the markdown is rendered — an artifact cannot inject markup or scripts.

## Columns

They follow "Where am I?" in `/regent:status` (Step 3.7); a change of that table changes `stageOf()` in
`templates/dashboard.html` too.

| Column | Changes | Flag on the card |
|--------|---------|------------------|
| Propose | no `proposal.md` · `Draft` · `Rejected` | incomplete · awaits your approval · rejected |
| Approved | `Approved`, no task `[x]` | — |
| Apply | some tasks `[x]` | — |
| Verify | all tasks `[x]` · verdict FAIL | unverified · verification FAIL |
| Close | verdict PASS | verified · code moved after verification |

Above the stages, **Your move** lists the changes that wait on you (a proposal to approve, verification to run
or fix, a rejected change, code moved after verification) with the reason and the command to copy; the header
sums it up in one sentence. An empty stage keeps its place in the sequence but gives its width to the others.

The theme button in the header cycles Auto (follows the system), Light and Dark; the browser remembers the choice.

## Archive tab

`ai/changes/archive/` as a table, newest first, grouped by month: archive date, name and summary line, type,
ticket, tasks, verdict (or "abandoned"), days from `Created` to the archive. Filters by type and abandoned,
the search box of the header, 100 rows at a time ("show more") — the page stays fast with thousands of
closed changes.

## Usage metrics

Every change shows what its work cost in Claude Code: the card a chip (`≈ $1.19 · 17m`), the side panel a
**Usage** tab (totals, the runs, a breakdown by model, effort and agent) and each run on the timeline, the
Archive tab a cost, active time and Regent version per change — to compare changes and framework releases.

`scripts/usage.sh` measures it from Claude Code's session transcripts
(`~/.claude/projects/<project>/<session>.jsonl` and `<session>/subagents/`):

- **Run** — a `/regent:<command>` whose arguments name a change, plus the session's prompts after it until
  the next `/regent:` command (answers, approvals). When the arguments name no change (`/regent:bugfix
  <description>`), the run belongs to the change directory its Write/Edit/Bash calls touched most; with none,
  it is left out. Subagents count towards the prompt that launched them.
- **Regent version** — from the plugin path of the skill the command loaded (`…/regent/<version>/skills/…`).
- **Model, effort, agent** — per API call (`model`, `effort` of the call, `agentType` of the subagent).
- **Active time** — per prompt, from the prompt to its last call; the time you spent reading in between is not counted.
- **Tokens** — `usage` of every call, deduplicated by `message.id`: input, cache write (5 min / 1 h), cache read, output.
- **Cost** — tokens × [`scripts/pricing.tsv`](../scripts/pricing.tsv): an API-equivalent estimate. Claude Code
  does not write the billed amount to the transcript (only the statusline gets a session total, live), and on a
  subscription plan there is no per-token bill at all — the number compares changes and releases, it is not an invoice.

The measurement is kept continuously: every board build (the hooks run one after every turn) parses the
sessions whose transcript changed into the board's cache, `~/.cache/regent/boards/<project>-<checksum>/usage-cache/`.
A parsed session stays there after Claude Code deletes its transcript (after ~30 days, `cleanupPeriodDays`).
The cache is per machine and outside the repo, so `/regent:archive` also writes the measurement to `usage.md`
in the change, which is archived and versioned with it. A change moved to `ai/changes/archive/` by hand has no
`usage.md`: the board then shows its usage from the cache, and `usage.sh <change> > …/usage.md` writes the file
later, from the same cache.

Everything runs in bash and awk on local files: it costs no tokens and no plan limit. The only model work is
one short command in `/regent:archive`.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/usage.sh <change>   # the usage.md of a change, to stdout
bash ${CLAUDE_PLUGIN_ROOT}/scripts/usage.sh --tsv      # every run, for scripts and spreadsheets
```

New model or new prices → a line in `scripts/pricing.tsv` (and its `as-of` date); a model missing there shows
its cost as `?`.

## Limits

- No live view without `--watch`: the board shows the state from the last run.
- Without git the board has no dates of commits and no "updated" date — the rest works.
- On Windows (Git Bash) a `--watch` tick takes 1–2 s, independent of the archive size.
- Usage covers only this machine's transcripts; work done elsewhere or in sessions already deleted is missing.
  A prompt unrelated to the change, typed after a `/regent:` command in the same session, counts towards it.
- Run times are in UTC (the Usage tab and `usage.md` alike).
- A changed session is parsed from its start on every build; a very long transcript makes a `--watch` tick slower.
