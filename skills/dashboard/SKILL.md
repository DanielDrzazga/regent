---
description: HTML kanban board of the SDD cycle — every change by stage (propose → apply → verify → archive) with tasks, verification and files; --watch follows the work live
argument-hint: '[--watch [SEC]] [--out <dir>]'
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh:*)
---

# /regent:dashboard — Kanban board of the SDD cycle

**Goal:** Show the whole SDD work of the project as an HTML kanban board in the browser: one card per
change in `ai/changes/`, a column per cycle stage, details of every change in a side panel.

```
/regent:dashboard                 # write the board and open it in the browser
/regent:dashboard --watch         # the board follows the work live (rebuild every 3 s)
/regent:dashboard --out .board    # another output directory
```

---

## Agent (delegation)

No delegation — the script does the whole job. It runs in the main session.

---

## Step 1: Write and open the board

Requires `ai/` in the project root — without it → `/regent:init` first.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh --open [--out <dir>]
```

When the user passed `--watch [SEC]`, run the command with it in the background (Bash `run_in_background`):
the board then follows `/regent:apply` and the other commands of this session — the page re-reads its
data every 2 s, without a reload.

## Step 2: Report

```
Board: {path from the "Board:" line}
Live: yes (rebuild every N s, stops with the session) / no — rerun /regent:dashboard to refresh
```

What the **Board** tab shows — the columns follow "Where am I?" of `/regent:status` (Step 3.7):

| Column | Changes |
|--------|---------|
| Propose | no `proposal.md`, `Status: Draft` (awaits your approval), `Rejected` |
| Approved | `Approved`, no task checked off |
| Apply | some tasks `[x]` |
| Verify | all tasks `[x]`, no `verification.md` or verdict FAIL |
| Close | verdict PASS (a flag when code moved after verification) |

A card: type, size, ticket, Claude Code usage (API-equivalent cost, active time — `scripts/usage.sh` from the
transcripts), task progress per layer (`[BE]`/`[FE]`/`[DB]`), verification stages, the next command to copy. The **Archive** tab: `ai/changes/archive/` as a table (newest first, filter by type,
100 rows at a time). The side panel of a change: the cycle, a timeline (proposal, decisions, command runs,
task commits, verification, archive), the task list, a Usage tab (runs, model × effort × agent) and every
file of the change rendered.

---

## IMPORTANT Rules

- ✅ ALWAYS hand the user the `Board:` path — the page is a local file, opened from disk
- ❌ The board is read-only for the project: the script writes only to the output directory
  (default: the system temp directory) — no file of the project changes
