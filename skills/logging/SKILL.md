---
description: Instrument existing code with logs per the project's logging-patterns.md
disable-model-invocation: true
argument-hint: <path-or-description> [--level debug|info|warn|error|fatal] [--type business|technical]
allowed-tools: Task, Read, Write, Edit, Grep, Glob, AskUserQuestion, SendMessage, Bash
---

# /regent:logging — Add logs to code

**Goal:** Instrument existing code with logs at the right levels (debug → fatal),
following the project's logging pattern. It does NOT build a logger — it uses the existing one.

```
/regent:logging <path-or-description> [options]

Options:
  --level debug|info|warn|error|fatal   Force/limit the level
  --type business|technical             Force the log type

Example:
/regent:logging src/modules/messenger/application/whatsapp-sender.service.ts
/regent:logging "WhatsApp webhook consumer"
/regent:logging src/modules/template-management --type business
```

---

## Agent (delegation — REQUIRED)

Delegate the instrumentation to the `regent:logging-engineer` subagent (model: sonnet, launch it with the
Task tool). Don't pick and insert logs "in place" in the main session — otherwise the model
from `agents/logging-engineer.md` will not be used.

---

## Step 0: Validation (portable — no hardcoded paths)

Check whether `ai/docs/patterns/logging-patterns.md` exists.

```
✅ It exists → it is the source of truth: logger path + API + rules. Go to Step 1.

❌ Missing → ASK the user (AskUserQuestion), don't guess:
   (a) Use the framework's native logger now (general rules of the standard)
   (b) Stop — first create ai/docs/patterns/logging-patterns.md / roll out the standard
   (c) Specify the logger path manually
```

❗ Do NOT assume any logger path (`src/core/...`, `src/logger/`, …) — read it from the pattern.

---

## Step 1: Load the pattern + locate the target

The `regent:logging-engineer` subagent reads **directly via Read**:

```
ALWAYS:
1. ai/docs/patterns/logging-patterns.md   ← logger path + API + rules
2. The specified target files (from the command argument)

Do NOT scan the whole src/. If the target is a description (not a path) → Grep/Glob ONLY to find the files.
```

`regent:logging-engineer` identifies logging points: operation entries/exits, domain events,
external integrations, `catch` blocks/errors, significant conditional branches.

---

## Step 2: Instrumentation plan (FOR APPROVAL)

Delegate to `regent:logging-engineer` in PLAN mode (it returns a table in the report — no code changes).
The main session shows the table to the user and waits for approval:

```markdown
## Logging plan: {target}

| File:line | level | type | action | Rationale |
|------------|-------|------|--------|--------------|
| sender.service.ts:42 | info | BUSINESS | MESSAGE_SENT | Message sent |
| sender.service.ts:55 | error | TECHNICAL | META_API_ERROR | Meta API error in catch |

Approve? (yes/no/revise)
```

**WAIT.** `yes` → implementation (continue THE SAME subagent — resume by agentId —
with the message "plan approved, implement"). `revise: ...` → continue the subagent
with the corrections and show the table again.

---

## Step 3: Implementation

```
→ Add logs via the API from the pattern (business()/technical() or native per the Step 0 decision)
→ Inject the logger via DI if the class doesn't have it (per the path from the pattern)
→ @LogDuration / @WithEventContext when they fit (don't duplicate the request log)
→ action: NOUN_VERB, UPPERCASE, EN
→ context: ONLY entity IDs — zero PII/secrets
→ One log per operation — not in a loop/hot-path
→ Do NOT change business logic
```

---

## Step 4: Tests not red

```
The subagent narrowly runs the tests of the changed modules:
→ make test-unit PATTERN={module}   (or make test when there is no narrow target)

Logger mock = no-op; no new assertions on logs.
Tests only need to not blow up with the added logs.
```

Atomic commit — MAIN SESSION, only the files listed in the subagent's report:

```bash
git add src/modules/messenger/application/whatsapp-sender.service.ts
git commit -m "chore: (KEY) add structured logging to WhatsAppSenderService"
```

---

## Step 4.5: Sync with observability (conditional)

```
If ai/docs/observability/ exists AND the change ADDS / RENAMES / REMOVES
a logged `action` (or changes `type`/`module`):

→ Read ai/docs/observability/maintenance.md and flag it for reflection:
   Kibana dashboards/alerts filter by a hardcoded list of `action` — a new/changed
   action will NOT show up by itself. This is a FLAG, not building dashboards.

No ai/docs/observability/ → skip this step (optional).
```

In the report (Step 5) list `⚠️ Observability` with the list of new/changed `action`s, if applicable.

---

## Step 5: Report (concise)

```markdown
## Logging: {target} — Done

Logs: N (info: x, warn: y, error: z, debug: w)
Types: BUSINESS: a, TECHNICAL: b
Files: [list]
⚠️ Observability: new/changed action → [list] (check maintenance.md) — if applicable
Commit: abc1234
```

---

## IMPORTANT Rules

✅ **ALWAYS:**
- Source of truth = `ai/docs/patterns/logging-patterns.md` (including the logger path); missing → ask
- This is instrumentation of an existing logger — `/regent:propose` builds the logger, not this command
- `action` EN UPPERCASE; `business()` for the domain, `technical()` for the rest/errors
- In `context` only entity IDs — personal data and secrets stay out of the log
- Log at module boundaries; `domain/` stays clean, hot-path and loops without logs
- The request is logged by the existing interceptor / axios logger — instrument what it doesn't cover
- Instrumentation plan → approval (main session) → code (continuing the subagent)
- Narrow tests after instrumentation (subagent); commit in the main session after green tests
- When `ai/docs/observability/` exists and you change an `action` → flag the sync (Step 4.5)

❌ **Guardrail:** `git add` only with a list of files.
