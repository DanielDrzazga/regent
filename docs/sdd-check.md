# sdd-check — deterministic artifact validation

`scripts/sdd-check.sh` checks the SDD artifacts in a project **with a script, not the model**. Counting
checkboxes, comparing REQ numbers and AC sets is work in which the model makes mistakes and pays
for it in tokens — the script does it repeatably in a fraction of a second.

The script is **read-only**: it writes nothing, it only reports — except for the `renumber` mode, which
renumbers a requirement in the files of one change. The framework's commands call it
at gates; you can also run it yourself, in the project's root directory:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sdd-check.sh <mode> [arguments]
```

## Modes

| Mode | What it checks | Who calls it |
|------|-------------|----------|
| `change <name>` | Status in proposal.md; delta: only ADDED/MODIFIED/REMOVED/INVARIANTS/Notes sections, every REQ has AC, REMOVED has a Reason, no placeholders, a refactor has INV; tasks: checkboxes, IDs, REQ/AC references, `verification:`, coverage of every AC by a task | `/regent:propose` 3a, `/regent:apply` Step 0 and 4.5, `/regent:verify` Step 0, `/regent:archive` Step 1 |
| `preflight <name>` | delta against `ai/specs/`: the ADDED number is free (also against other active changes and the default branch's main specs; the same ADDED in another branch's delta → WARN), MODIFIED/REMOVED points to an existing REQ, MODIFIED does not lose AC from the main spec, no duplicate REQs in main specs | `/regent:propose` 3a, `/regent:archive` Step 0 |
| `postmerge <name>` | main specs after merge: no delta headings and no Was/Removed AC lines, no duplicate REQs, the AC set of every REQ = the set from the delta | `/regent:archive` after Step 2 |
| `drift <name>` | whether the files from "Affected Files" changed since the `Commit HEAD` from verification.md | `/regent:archive` Step 0, `/regent:status` |
| `diff <name> [base]` | facts for review: removed tests, added `.skip/.only/xit`, tests with fewer assertions, files outside "Affected Files" | `/regent:verify` before Stages 2-4 |
| `next-req` | the next free REQ number (max from `ai/specs/`, active changes, the archive, deltas and main specs on all local and remote branches + 1) | `/regent:propose` Step 2 |
| `renumber <name> <REQ> [REQ-new]` | **the only mode that writes**: renumbers an ADDED requirement in all files of the change (delta, tasks, verification, proposal); without the third argument it takes `next-req` | `/regent:archive` Step 0 on a number collision |
| `status` | one line per active change: Status, tasks x/y, verification verdict | `/regent:status` |
| `index` | requirements index: `domain: REQ-NNN title (AC: n)` — a map of `ai/specs/` without reading whole files | `regent:spec-writer` (via the prompt from `/regent:propose`) |
| `stale` | files from "Affected Files" of archived changes, later changed outside the SDD cycle (a cycle commit = a hash in tasks.md, the ticket key from the proposal in the subject — survives a squash — or it touches `ai/changes/`) | `/regent:status --drift` |

## Output

```
ERROR ai/changes/x/specs/auth.md:14 REQ-001/AC-2 is in the main spec but not in the MODIFIED block …
WARN  ai/changes/x/tasks.md:9 T-04 without verification:
INFO  tasks.md: 2/5 done
RESULT: ERROR (errors=1 warnings=1)
```

Exit code: `0` — no ERROR, `1` — there are ERRORs, `2` — invalid usage. **ERROR** breaks the artifact
contract (the merge would lose data, the format is unreadable for the next commands). **WARN** is a
signal for a decision — the command that calls the script says what to do with it. **INFO** is a fact.

## Formats the script relies on

- Requirement: `### REQ-NNN: Name`; AC under it: `- [ ] AC-n: …` (format: `templates/spec-template.md`).
- Removing AC in MODIFIED: `**Removed AC:** AC-3 — reason`; AC copied without changes: the suffix `(unchanged)`
  at the end of the line (skipped in AC coverage by tasks, forbidden in the main spec).
- Task: `- [ ] T-NN: [TAG] description — REQ-NNN/AC-n — files: … — verification: …` (format: `agents/spec-writer.md`);
  a list `REQ-001/AC-1, AC-3`, a range `REQ-001/AC-1..3`, a whole requirement `REQ-001`, a refactor `INV-1`.
- `**Removed AC:**` on one line (`AC-3 — reason`) or with a bullet list below it.
- `####` headings under a REQ (e.g. scenarios) do not end the REQ block; `#`–`###` do.
- Status: a row `| Status | Approved |` or a line `Status: Approved`.
- Verification: the lines `Verdict: PASS` and `Commit HEAD: <hash>` in verification.md.
- Task trace after the commit: `✅ (commit: <hash> · tests: AC-1 → file › test; …)` (`/regent:apply` 4c) —
  this is the main link between commits and the cycle. The `diff` base is determined in order:
  the oldest commit touching the change directory → the oldest hash from tasks.md → merge-base with the main
  branch. `stale` treats a commit as a cycle commit by its hash, the ticket key in the subject (whole word),
  touching `ai/changes/`, or by file contents equal to the recorded commit (squash).

Code blocks and HTML comments are skipped — instructions from templates are not content.

## Tests

```bash
bash scripts/tests/sdd-check.test.sh     # fixtures in a temporary directory; framework-lint.sh runs them too
```

The script targets bash 3.2 (the default on macOS) and POSIX awk — no associative arrays in bash
and no gawk extensions.
