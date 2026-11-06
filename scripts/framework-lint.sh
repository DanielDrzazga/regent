#!/usr/bin/env bash
# framework-lint.sh — consistency of the Regent plugin: frontmatter, references, tables, regressions.
#
# The plugin is prompts, so the "test" is consistency: every reference to a skill, agent,
# template or script leads to an existing file, the tables in context/sdd-map.md and README.md
# match skills/ and agents/, and fixed prompt bugs do not come back.
# Finally it checks script syntax and runs the script tests in /bin/bash (3.2) and in bash from PATH.
#
# Usage (in the regent repo):  bash scripts/framework-lint.sh
# Exit code: 0 = no ERROR, 1 = ERRORs found.

set -u
cd "$(dirname "$0")/.." || exit 2

errors=0
warnings=0
err()  { echo "ERROR $*"; errors=$((errors + 1)); }
warn() { echo "WARN  $*"; warnings=$((warnings + 1)); }

# Outside the lint: rules for working on this repo (.claude/).
FILES=$(git ls-files --cached --others --exclude-standard -- '*.md' 2>/dev/null \
  | grep -vE '^\.claude/')
[ -n "$FILES" ] || { echo "ERROR no .md files — run in the regent repo"; exit 2; }
# Decision records deliberately name retired commands and removed files — sections 3, 4 and 6
# skip them. Add only decision-register files here, not regular documentation.
DECISION_DOCS='^docs/roadmap\.md$'
REFS=$(echo "$FILES" | grep -vE "$DECISION_DOCS")

frontmatter() { awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"; }

# --- 1. Agents: frontmatter recognized by Claude Code ------------------------------------
for f in agents/*.md; do
  n=$(basename "$f" .md)
  fm=$(frontmatter "$f")
  echo "$fm" | grep -qx "name: $n"                                 || err "$f: field name ≠ file name ($n)"
  echo "$fm" | grep -qE '^model: (opus|sonnet|haiku|inherit)$'     || err "$f: missing valid model field"
  echo "$fm" | grep -qE '^tools: .+'                               || err "$f: missing tools field"
  echo "$fm" | grep -qE '^description:'                            || err "$f: missing description field"
done

# --- 2. Skills: frontmatter, name without suffix, heading, permissions -------------------
MODEL_INVOCABLE='status'
for f in skills/*/SKILL.md; do
  n=$(basename "$(dirname "$f")")
  fm=$(frontmatter "$f")
  case "$n" in *-sdd) err "$f: skill with -sdd suffix (the regent: namespace replaces the suffix)" ;; esac
  echo "$fm" | grep -qE '^description: .+' || err "$f: missing description in frontmatter"
  grep -qE "^# /regent:$n( |$)" "$f"        || err "$f: missing heading '# /regent:$n'"
  # The user runs skills; the model may invoke on its own only those in MODEL_INVOCABLE (read-only).
  case " $MODEL_INVOCABLE " in
    *" $n "*) ! echo "$fm" | grep -qx 'disable-model-invocation: true' || err "$f: a MODEL_INVOCABLE skill must not have disable-model-invocation" ;;
    *)        echo "$fm" | grep -qx 'disable-model-invocation: true' || err "$f: missing disable-model-invocation: true (the user runs this skill)" ;;
  esac
  tools=$(echo "$fm" | sed -n 's/^allowed-tools: //p')
  if [ -n "$tools" ]; then
    if grep -qE 'Task tool|\(Task\)' "$f" && ! echo "$tools" | grep -qE '(^|, *)Task(,|$)'; then
      err "$f: delegates through Task, but allowed-tools lacks Task"
    fi
    for t in AskUserQuestion SendMessage; do
      if grep -q "$t" "$f" && ! echo "$tools" | grep -qE "(^|, *)$t(,|$)"; then
        err "$f: uses $t, but allowed-tools does not list it"
      fi
    done
    if grep -q 'sdd-check.sh' "$f" && ! echo "$tools" | grep -qE '(^|, *)Bash(,|$)|sdd-check\.sh'; then
      err "$f: calls sdd-check.sh, but allowed-tools does not allow it"
    fi
  fi
done

# Plugin agents are named regent:<agent> — delegation by the bare name does not reach the subagent.
for a in agents/*.md; do
  n=$(basename "$a" .md)
  hits=$(grep -n "\`$n\`" skills/*/SKILL.md context/*.md 2>/dev/null)
  [ -z "$hits" ] || err "reference to agent $n without the regent: prefix — $hits"
done

# --- 3. References to skills and agents lead to existing files ---------------------------
refs=$(echo "$REFS" | xargs grep -ohE '/regent:[a-z]+(-[a-z]+)*' 2>/dev/null | sort -u)
for r in $refs; do
  [ -f "skills/${r#/regent:}/SKILL.md" ] || err "reference to missing skill $r: $(echo "$REFS" | xargs grep -l -- "$r" | tr '\n' ' ')"
done
arefs=$(echo "$REFS" | xargs grep -ohE '(^|[^/a-z])regent:[a-z]+(-[a-z]+)*' 2>/dev/null \
  | sed -E 's/^[^r]*//' | sort -u)
for r in $arefs; do
  n=${r#regent:}
  [ -f "agents/$n.md" ] || [ -f "skills/$n/SKILL.md" ] || err "reference to missing agent $r: $(echo "$REFS" | xargs grep -l -- "$r" | tr '\n' ' ')"
done

# --- 4. References to framework files lead to existing files -----------------------------
# The path must start with a framework directory — `ai/docs/...` are project files, not framework files.
paths=$(echo "$REFS" | xargs grep -ohE '(^|[^A-Za-z0-9_./~-])(\$\{CLAUDE_PLUGIN_ROOT\}/)?(agents|skills|templates|scripts|docs|context)/[A-Za-z0-9_./-]+\.(md|sh|template)' 2>/dev/null \
  | sed -E 's#^[^A-Za-z$]##; s#^\$\{CLAUDE_PLUGIN_ROOT\}/##' | sort -u)
for p in $paths; do
  [ -e "$p" ] || err "reference to missing file $p: $(echo "$REFS" | xargs grep -l -- "$p" | tr '\n' ' ')"
done

# --- 5. Skill and agent tables match the directories --------------------------------------
for f in skills/*/SKILL.md; do
  n="/regent:$(basename "$(dirname "$f")")"
  for doc in context/sdd-map.md README.md; do
    grep -qE "^\| \`$n\` \|" "$doc" || err "$doc: $n missing from the skills table"
  done
done
for f in agents/*.md; do
  n=$(basename "$f" .md)
  for doc in context/sdd-map.md README.md; do
    grep -q "\`regent:$n\`" "$doc" || err "$doc: agent regent:$n missing"
  done
done
nc=$(ls skills/*/SKILL.md | wc -l | tr -d ' ')
na=$(ls agents/*.md | wc -l | tr -d ' ')
grep -qE "# $nc skills" README.md    || err "README.md: the repo tree gives a skill count other than $nc"
grep -qE "# $na subagents" README.md || err "README.md: the repo tree gives an agent count other than $na"
for s in scripts/*.sh; do
  grep -q "$s" docs/README.md || err "docs/README.md: script $s missing from the Scripts table"
done

# --- 5b. Plugin hooks and context ----------------------------------------------------------
# Every script in hooks/hooks.json and every context/ file injected by session-context.sh exists.
if [ -f hooks/hooks.json ]; then
  for p in $(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' hooks/hooks.json | sed 's#^\${CLAUDE_PLUGIN_ROOT}/##' | sort -u); do
    [ -e "$p" ] || err "hooks/hooks.json: missing file $p"
  done
  for c in $(grep -oE 'session-context\.sh\\?"? +[a-z]+ +[a-z]+ +[A-Za-z0-9_.-]+' hooks/hooks.json | awk '{ print $NF }' | sort -u); do
    [ -f "context/$c" ] || err "hooks/hooks.json: missing context file context/$c"
  done
else
  err "missing hooks/hooks.json"
fi
# Claude Code truncates one hook's output to 10,000 characters; bytes ≥ characters, so 9000 B leaves headroom.
for f in context/*.md; do
  b=$(wc -c < "$f" | tr -d ' ')
  [ "$b" -le 9000 ] || err "$f: $b B > 9000 B — the hook will truncate the context; split the file and add an entry in hooks/hooks.json"
done

# --- 6. Retired names do not come back -----------------------------------------------------
# Old command names with the -sdd suffix (before the plugin) are retired too.
RETIRED='devops-engineer|templates/docs/deployment\.md|[a-z]+(-[a-z]+)*-sdd([^a-z-]|$)'
hits=$(echo "$REFS" | xargs grep -nE "$RETIRED" 2>/dev/null)
[ -z "$hits" ] || err "retired name in content: $hits"

# --- 6b. Language: artifacts are English ---------------------------------------------------
# Polish characters are allowed only where they are data: legacy markers that sdd-check.sh still
# accepts, test fixtures, and this file (the pattern below).
PL='ą|ć|ę|ł|ń|ó|ś|ź|ż|Ą|Ć|Ę|Ł|Ń|Ó|Ś|Ź|Ż'
hits=$(git ls-files --cached --others --exclude-standard 2>/dev/null \
  | grep -vE '^(scripts/framework-lint\.sh|scripts/sdd-check\.sh|scripts/tests/)' \
  | while IFS= read -r f; do [ -f "$f" ] && grep -lE "$PL" "$f" 2>/dev/null; done)
[ -z "$hits" ] || err "Polish text outside allowed data (rule \"Language\" in context/role.md): $(echo "$hits" | tr '\n' ' ')"

# --- 7. Regressions: fixed prompt bugs do not come back ------------------------------------
# forbid <file> <ERE regex> <reason> — the pattern must NOT occur
# require <file> <ERE regex> <reason> — the pattern MUST occur
forbid()  { ! grep -qE -- "$2" "$1" || err "$1: regression — $3 (pattern: $2)"; }
require() {   grep -qE -- "$2" "$1" || err "$1: regression — $3 (missing: $2)"; }

# (the list grows with fixes — add an entry in the same commit as the fix)
forbid  skills/archive/SKILL.md        'Replace the old behavior with the new|append method' "MODIFIED replaces the whole block, not a fragment"
require templates/spec-template.md     'Removed AC'                             "MODIFIED lists removed AC explicitly"
require agents/spec-writer.md          'full REQ block'                         "spec-writer copies the whole REQ block into MODIFIED"
forbid  templates/proposal-template.md '^## Acceptance Criteria'                "AC live only in the delta (one source of AC)"
forbid  templates/user-story-template.md '^## Acceptance Criteria'              "AC live only in the delta (one source of AC)"
forbid  skills/propose/SKILL.md        'solution, AC \(Given-When-Then\)'       "AC live only in the delta (one source of AC)"
forbid  agents/qa-engineer.md          'REQ-XXX-1'                              "one ID format: REQ-NNN/AC-n"
forbid  skills/propose/SKILL.md        '^## Tests$'                             "tests belong to their task (horizontal slicing)"
require agents/architect.md            'API↔UI contract in the "API / Interface Contract" section'  "the contract under the template's name — FE and BE agents look for it"
require agents/spec-writer.md          'verification'                           "every task says how to check it is done"
require skills/propose/SKILL.md        'resume the same .regent:spec-writer.'   "tasks.md is written after design.md"
require templates/proposal-template.md '^## Decisions and assumptions'          "Challenge answers survive the session"
require skills/propose/SKILL.md        '□ GAPS'                                 "Challenge looks for behavior gaps, not only for the sense of the change"
require skills/propose/SKILL.md        '^## Step 2\.5: Consistency check'       "artifact mismatch caught before the code"
require skills/propose/SKILL.md        'Reviewer checklist'                     "Draft review has an order and criteria"
require agents/spec-writer.md          '^## Self-check'                         "spec-writer checks spec quality before the report"
require agents/code-reviewer.md        'design\.md'                             "the reviewer compares code with design.md"
require agents/code-reviewer.md        'unrequested'                            "the reviewer detects out-of-scope code"
forbid  agents/code-reviewer.md        '^\| .partial. \|'                        "gap type incomplete ≠ status ⚠️ PARTIAL"
require agents/spec-writer.md          'first specification of existing'        "brownfield: undescribed behavior goes into ADDED"
require skills/apply/SKILL.md          '^## Step 4\.5: Change of course'        "a discovery during apply updates the plan with consent"
require skills/apply/SKILL.md          'One run = a new subagent'               "the next task does not go through SendMessage to an agent after its report — context grows with every task"
require agents/backend-dev.md          'SCOPE:'                                 "the dev does not narrow AC silently"
require agents/frontend-dev.md         'SCOPE:'                                 "the dev does not narrow AC silently"
require templates/design-template.md   '^## Deviations from principles'         "a deviation from MUST has a justification"
require skills/bugfix/SKILL.md         'Reproduce the original symptom'         "bugfix confirms the symptom is gone, not only green tests"
forbid  skills/verify/SKILL.md         'Happy path (from|of) AC-1'              "AC-1 without REQ is ambiguous — smoke from design.md"
require skills/archive/SKILL.md        'sdd-check.sh postmerge'                 "merge into the main spec checked by the script"
require skills/archive/SKILL.md        'sdd-check.sh preflight'                 "delta checked before the merge"
forbid  agents/backend-dev.md          'test contains the AC ID'                "REQ/AC numbers are local — they do not go into the code"
forbid  agents/frontend-dev.md         'test contains the AC ID'                "REQ/AC numbers are local — they do not go into the code"
require skills/explore/SKILL.md        'One candidate = one SDD change'         "discovery cuts an initiative into propose → archive changes"
require skills/explore/SKILL.md        'Candidate 1 = walking skeleton'         "discovery starts with an end-to-end slice, not with the foundation"
forbid  skills/status/SKILL.md         'git rev-parse HEAD`\)\. [Dd]ifference'  "drift by the change's files, not by the HEAD hash"
forbid  skills/explore/SKILL.md        'ai/product'                             "discovery without a live backlog in ai/ — candidates 2..N go to the tracker"
require context/sdd.md                 'no body and no footers'                 "commit without a footer — git-guard rejects attribution, every bounce costs a turn"
require hooks/hooks.json               'subagent sdd subagent\.md'               "the subagent gets the subagent contract"
forbid  skills/apply/SKILL.md          'regent\.sh|task packet'                 "task CLI removed — apply works on files"
require context/role.md                '^## Language'                           "artifacts in English, conversation in the user's language"
for f in agents/*.md skills/*/SKILL.md templates/*.md templates/docs/*.md; do
  forbid "$f" '[Ii]n (Polish|English)([^a-z]|$)' "the artifact language is set only by the \"Language\" rule in context/role.md"
done
forbid  hooks/hooks.json               'subagent sdd sdd-map\.md'                "skill map only in the main session — the subagent does not need it"

forbid  skills/init/SKILL.md           '"command": "f=.*git-guard\.sh'            "the plugin registers git-guard (hooks/hooks.json), not an entry in the project"
require hooks/hooks.json               'scripts/hooks/git-guard\.sh'           "the plugin registers git-guard"

# --- 8. Scripts: syntax and tests in every available bash ----------------------------------
# /bin/bash on macOS is 3.2 — bash from PATH is often newer (Homebrew) and hides 3.2 syntax errors.
shells=$( { [ -x /bin/bash ] && echo /bin/bash; command -v bash; } | awk '!seen[$0]++')
for sh in $shells; do
  for f in scripts/*.sh scripts/hooks/*.sh; do
    [ -f "$f" ] || continue
    "$sh" -n "$f" 2>/dev/null || err "$f: syntax error in $sh ($("$sh" -c 'echo $BASH_VERSION'))"
  done
  for t in scripts/tests/*.test.sh; do
    [ -f "$t" ] || continue
    res=$("$sh" "$t" 2>&1) || err "$t [$sh]: $(printf '%s\n' "$res" | tail -1)"
  done
done

# --- 9. Release: every change on master ships under a new version ---------------------------
# Claude Code updates the plugin only when plugin.json "version" changes, so a tagged version on
# another commit means a change without a bump (teammates would get different code under one version).
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json)
echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || err ".claude-plugin/plugin.json: version '$version' is not semver x.y.z"
grep -q "^## \[$version\]" CHANGELOG.md || err "CHANGELOG.md: no '## [$version]' entry"
if tagged=$(git rev-parse -q --verify "refs/tags/v$version^{commit}" 2>/dev/null) \
   && [ "$tagged" != "$(git rev-parse HEAD 2>/dev/null)" ]; then
  err "v$version is already released — make bump VERSION=<next> (CONTRIBUTING.md → Releases)"
fi
forbid  Makefile                       'regent\.git\\?#stable'                   "installs follow master; releases are tags, not a stable branch"
forbid  templates/project-settings.json.template '"ref"'                        "the project entry must match the plain user source (no ref)"

echo "RESULT: $([ $errors -gt 0 ] && echo ERROR || { [ $warnings -gt 0 ] && echo WARN || echo OK; }) (errors=$errors warnings=$warnings)"
[ $errors -eq 0 ]
