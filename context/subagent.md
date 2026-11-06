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

A subagent that creates artifacts requiring approval **returns their content in its final
report** — the main session writes the files after approval (or the continued subagent after
receiving "approved — write it").

