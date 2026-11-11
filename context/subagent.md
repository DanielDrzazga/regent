# Regent — subagent contract

> Injected into the main session and every subagent in projects with `ai/docs/`. The map of skills
> and agents (`context/sdd-map.md`) goes only to the main session — a subagent does not need it.

**Subagent contract:** a subagent MUST NOT block mid-work and wait
for the user's answer — it runs to the end of its turn and returns a report. Approval gates
(questions, approvals) are run by the main session. The question loop looks like this:

1. The subagent ends its turn with a report — open points in the `OPEN QUESTIONS` section.
2. The main session asks the user the questions.
3. The main session **continues THE SAME subagent** (SendMessage / resume by
   `agentId`), passing the answers — the agent keeps its context, no
   re-delegation from scratch. When continuation is unavailable → re-delegation with the answers
   in the prompt.

**Artifacts are written once, by the subagent.** A subagent that creates artifacts writes them
itself — only the files the delegating prompt names, always under `ai/` — and the approval gate runs
on the written files: the main session shows the paths and the user reads the files. Until approval
they are drafts: `/regent:propose` marks them `Status: Draft`; in `/regent:init` and `/regent:wiki`
a rejection is undone by the main session (it removes the files the report lists as created).
The report lists every written path with one sentence each and **never repeats file content** —
repeating it makes the main session pay for the same text twice. A prompt that names no paths means
read-only: write nothing.

