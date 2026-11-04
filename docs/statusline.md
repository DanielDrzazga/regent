# Statusline — context counter

A bar at the bottom of the terminal showing live how much context the session takes up. Long sessions
use the most tokens (especially subagent ones), and without an indicator you cannot see when
the context has grown enough that it is worth running `/clear`. The statusline makes it visible.

Script: [`scripts/statusline.sh`](../scripts/statusline.sh).

## What it looks like

```
Opus  ctx 9% (90k/1000k)  $0.30                     ← green, calm
Opus  ctx 18% (180k/1000k)  ⚠ watch  $1.10          ← yellow
Opus  ctx 27% (270k/1000k)  ⛔ time to /clear  $2.20 ← red
```

It shows: the model, the window percentage, tokens (used / max), the threshold label and the session cost.

## Installation

Requires `jq` and the `regent` plugin enabled. The plugin's `SessionStart` hook
([`scripts/hooks/sync-bin.sh`](../scripts/hooks/sync-bin.sh)) copies the script to a fixed path
in the plugin data that survives updates — the plugin directory in the cache changes with every version,
so `statusLine` cannot point at it directly:

```
~/.claude/plugins/data/regent-regent/bin/statusline.sh
```

Add the entry to `~/.claude/settings.json` once per machine (a plugin cannot set the main
session's `statusLine`):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/plugins/data/regent-regent/bin/statusline.sh\""
  }
}
```

The same directory holds `session-tokens.sh` — the session's token usage per prompt:
`bash ~/.claude/plugins/data/regent-regent/bin/session-tokens.sh`.

The statusline refreshes after every assistant response.

## Thresholds

The thresholds are counted from the **absolute number of tokens**, not from the window percentage:

| Range | Color | Label |
|--------|-------|----------|
| < 150k | green | (none) |
| 150k–250k | yellow | `⚠ watch` |
| > 250k | red | `⛔ time to /clear` |

**Why absolute and not a percentage:** with a 1M window (`opus[1m]`) a percentage warns
far too late — 80% of a million is 800k tokens, i.e. the context is already very expensive.
Absolute thresholds warn when it actually gets costly, regardless of
the window size. If you work with a regular 200k window, you can raise the thresholds — edit
the `150000` / `250000` values in the script.

## Where it gets the data

Claude Code passes the script a JSON on stdin with a ready `context_window` section
(incl. `total_input_tokens`, `context_window_size`, `used_percentage`) and `cost`.
There is no need to parse the session transcript.

## Limitation

It is an indicator, not an automaton — it does not stop work or run `/clear` for you.
You make the decision to clear the context yourself. It is, however, the only place
in Claude Code that knows the actual number of context tokens (hooks do not
receive it), so it is entirely sufficient for deliberately keeping an eye on cost.
