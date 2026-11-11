---
description: Open the HTML kanban board of the SDD cycle — every change by stage (propose → apply → verify → archive) with what waits on you, tasks, verification, usage and files; the plugin's hooks keep it fresh
disable-model-invocation: true
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh:*)
---

# /regent:dashboard — Kanban board of the SDD cycle

**Goal:** Open the project's HTML board in the browser: one card per change in `ai/changes/`, a column per
cycle stage, what waits on the user on top, details of every change in a side panel.

```
/regent:dashboard        # build the board now and open it in the browser
```

The board needs no command to stay current: in a project with `ai/`, the plugin's hooks rebuild it in the
background when a session starts, after every turn and subagent, and at most every 20 s while tools write
(`scripts/hooks/dashboard-refresh.sh`). It lives at one path per project, so a browser tab left open follows
the work of every session of the project; when they all end, the board keeps its last state.

---

## Agent (delegation)

No delegation — the script does the whole job. It runs in the main session.

---

## Step 1: Build and open the board

Requires `ai/` in the project root — without it → `/regent:init` first.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/dashboard.sh --open
```

## Step 2: Report

```
Board: {path from the "Board:" line}
It refreshes by itself while you work in Claude Code in this project; keep the tab open.
```

What the **Board** tab shows — the columns follow "Where am I?" of `/regent:status` (Step 3.7):

| Column | Changes |
|--------|---------|
| Propose | no `proposal.md`, `Status: Draft` (awaits your approval), `Rejected` |
| Approved | `Approved`, no task checked off |
| Apply | some tasks `[x]` |
| Verify | all tasks `[x]`, no `verification.md` or verdict FAIL |
| Close | verdict PASS (a flag when code moved after verification) |

Above the columns, **Your move** lists the changes that wait on the user, with the reason and the command.
A card: type, size, ticket, Claude Code usage (API-equivalent cost, active time — `scripts/usage.sh` from the
transcripts), task progress per layer (`[BE]`/`[FE]`/`[DB]`), verification stages, the next command to copy.
The **Archive** tab: `ai/changes/archive/` as a table (newest first, filter by type, 100 rows at a time).
The side panel of a change: the cycle, a timeline (proposal, decisions, command runs, task commits,
verification, archive), the task list, a Usage tab (runs, model × effort × agent) and every file rendered.

---

## IMPORTANT Rules

- ✅ ALWAYS hand the user the `Board:` path — the page is a local file, opened from disk
- ❌ The board is read-only for the project: the script writes only to its board directory
  (`~/.cache/regent/boards/<project>-<checksum>/`) — no file of the project changes
