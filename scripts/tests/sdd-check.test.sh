#!/usr/bin/env bash
# Tests for scripts/sdd-check.sh — fixtures in a temp directory, no network.
# Usage: bash scripts/tests/sdd-check.test.sh      (exit code 0 = all green)

set -u
# Tests independent of the user's global git config (e.g. a global .gitignore with ai/changes/).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
HERE=$(cd "$(dirname "$0")" && pwd)
CHECK="$HERE/../sdd-check.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/sdd-check-test.XXXXXX")
export XDG_CONFIG_HOME="$T/xdg"
trap 'rm -rf "$T"' EXIT
P="$T/p"
pass=0
fail=0
name=""
out=""
code=0

# The script runs with THE SAME interpreter as the tests ($BASH) — `/bin/bash test.sh` tests bash 3.2.
run() { out=$(cd "$P" && "$BASH" "$CHECK" "$@" 2>&1); code=$?; }
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/      /'; }
expect_code() { [ "$code" -eq "$1" ] && ok || bad "exit code $code, expected $1"; }
expect_has()  { printf '%s\n' "$out" | grep -qE -- "$1" && ok || bad "missing from output: $1"; }
expect_not()  { if printf '%s\n' "$out" | grep -qE -- "$1"; then bad "unexpected in output: $1"; else ok; fi; }
g() { git -C "$P" -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
C="$P/ai/changes/add-login"

fresh() {
  rm -rf "$P"
  mkdir -p "$P/ai/specs" "$C/specs" "$P/src/auth" "$P/tests"
  cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Requirements

### REQ-001: Password login

**Given** the account exists

**Acceptance Criteria:**
- [ ] AC-1: correct password logs in
- [ ] AC-2: wrong password returns 401

## History

| Date | Change | Type | Description |
|------|--------|-----|------|
EOF
  cat > "$C/proposal.md" <<'EOF'
# Proposal: add-login

## Metadata

| Field | Value |
|-------|-------|
| Type | feature |
| Status | Approved |
EOF
  cat > "$C/specs/auth.md" <<'EOF'
# Spec: auth — Delta for add-login

<!-- REQ-XXX in a comment is not a placeholder
     ### REQ-777: this is only a comment too -->

## ADDED

### REQ-002: Lockout after 5 attempts

**Acceptance Criteria:**
- [ ] AC-1: the fifth failed attempt locks the account
- [ ] AC-2: a locked account gets 423

## MODIFIED

### REQ-001: Password login

**Acceptance Criteria:**
- [ ] AC-1: correct password logs in
- [ ] AC-2: wrong password returns 401 and increments the attempt counter

**Was:** 401 without a counter
**Reason:** the lockout needs a counter

## Notes

```
### REQ-XXX: example in a code block — ignored
```
EOF
  cat > "$C/design.md" <<'EOF'
# Design: add-login

### Affected Files

| Layer | Changes | Files |
|-------|---------|-------|
| Domain | counter | `src/auth/login.ts`, `src/auth/lockout.ts` |
| Tests | tests | tests/ |

## API
EOF
  cat > "$C/tasks.md" <<'EOF'
# Tasks: add-login

## Setup
- [x] T-01: limit config — files: src/auth/config.ts — verification: make check ✅ (commit: 1111111)

## Implementation
- [x] T-02: [BE] attempt counter — REQ-001/AC-1, AC-2 — files: src/auth/login.ts — verification: test REQ-001/AC-2 ✅ (commit: 2222222 · tests: tests/login.test.ts › logs in)
- [ ] T-03: [BE] lockout — REQ-002 — files: src/auth/lockout.ts — verification: tests REQ-002 (after T-02)

---
Total: 3 tasks | Size: S
EOF
  printf 'export const login = () => 1;\n' > "$P/src/auth/login.ts"
  printf 'export const other = 1;\n' > "$P/src/other.ts"
  printf 'it("REQ-001/AC-1", () => { expect(1).toBe(1); expect(2).toBe(2); });\n' > "$P/tests/login.test.ts"
  printf 'it("old", () => { expect(1).toBe(1); });\n' > "$P/tests/old.test.ts"
  git -C "$P" -c init.defaultBranch=main init -q
  g add -A
  g commit -m init
}

# ---------------------------------------------------------------- change
name="change: valid change"; fresh; run change add-login
expect_code 0; expect_has 'RESULT: OK'; expect_has '2/3 done'; expect_not 'REQ-XXX|REQ-777'

name="change: template placeholder"; fresh
printf '\n## ADDED\n\n### REQ-XXX: [Name]\n' >> "$C/specs/auth.md"; run change add-login
expect_code 1; expect_has 'ERROR .*placeholder'
fresh; printf '\n## ADDED\n\n### REQ-004: Real\n\n- [ ] AC-1: [testable criterion]\n' >> "$C/specs/auth.md"; run change add-login
expect_code 1; expect_has 'ERROR .*template placeholder: - \[ \] AC-1: \[testable criterion\]'

name="change: REQ without AC"; fresh
sed -i.bak 's/^## MODIFIED/### REQ-003: Empty\n\n## MODIFIED/' "$C/specs/auth.md"
awk '/^## MODIFIED/ && !d { print "### REQ-003: Empty"; print ""; d = 1 } { print }' "$C/specs/auth.md.bak" > "$C/specs/auth.md"
run change add-login
expect_code 1; expect_has 'ERROR .*REQ-003 without AC'

name="change: AC without a task"; fresh
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-2/' "$C/tasks.md"; run change add-login
expect_code 0; expect_has 'WARN .*REQ-001/AC-1 has no task'; expect_has 'RESULT: WARN'

name="change: unusual checkbox and no verification"; fresh
printf -- '- [~] T-04: [BE] something — REQ-002\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*unusual checkbox'; expect_has 'WARN .*T-04 without verification:'; expect_has '2/4 done'

name="change: checked-off task without commit trace and tests"; fresh
printf -- '- [x] T-04: [BE] something — REQ-002/AC-1 — verification: test\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*T-04 checked off without a trace'; expect_has 'WARN .*T-04 checked off without a tests: mapping'

name="change: task without REQ outside Setup"; fresh
printf -- '- [ ] T-04: [BE] cleanup — files: x — verification: lint\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*T-04 without a REQ/AC, INV reference'
fresh; printf -- '- [ ] T-04: [BE] cleanup — no REQ: housekeeping — verification: lint\n' >> "$C/tasks.md"; run change add-login
expect_not 'T-04 without a REQ'

name="change: reference to a nonexistent REQ"; fresh
printf -- '- [ ] T-04: [BE] something — REQ-099 — verification: test\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*nonexistent REQ-099'

name="change: Status with a placeholder"; fresh
sed -i.bak 's/| Status | Approved |/| Status | Draft \/ Approved \/ Rejected |/' "$C/proposal.md"; run change add-login
expect_code 1; expect_has 'ERROR .*Status'

name="change: Status as a line"; fresh
printf '# Proposal\n\nType: feature\nStatus: Draft\n' > "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Draft'

name="change: bold Status in the table and in a line"; fresh
sed -i.bak 's/| Status | Approved |/| **Status** | **Approved** |/' "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Approved'
printf '# Proposal\n\n**Type:** feature\n**Status:** `Draft`\n' > "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Draft'

name="change: refactor without INVARIANTS"; fresh
sed -i.bak 's/| Type | feature |/| Type | refactor |/' "$C/proposal.md"; run change add-login
expect_code 1; expect_has 'ERROR .*refactor without INVARIANTS'

name="change: REMOVED without a reason"; fresh
printf '\n## REMOVED\n\n### REQ-005: Old\n' >> "$C/specs/auth.md"; run change add-login
expect_code 1; expect_has 'ERROR .*REQ-005 in REMOVED without \*\*Reason:\*\*'

name="change: no such change"; fresh; run change does-not-exist
expect_code 1; expect_has 'no change directory'

name="change: refactor with INVARIANTS only"; fresh
sed -i.bak 's/| Type | feature |/| Type | refactor |/' "$C/proposal.md"
printf '# Delta\n\n## INVARIANTS\n\n- **INV-1:** API unchanged\n- **INV-2:** tests without modification\n' > "$C/specs/auth.md"
printf '# Tasks\n\n## Implementation\n- [ ] T-01: [BE] extract a service — INV-1, INV-2 — files: src/auth/login.ts — verification: existing tests green, unchanged\n- [ ] T-02: [BE] cleanup — INV-3 — verification: lint\n' > "$C/tasks.md"
run change add-login
expect_code 0; expect_not 'T-01 without a REQ'; expect_has 'WARN .*T-02 refers to a nonexistent INV-3'
run preflight add-login
expect_code 0; expect_has 'INFO .*delta without REQ \(INVARIANTS only\)'; expect_not 'new main spec'
rm "$P/ai/specs/auth.md"; run postmerge add-login
expect_code 0; expect_not '^ERROR'

name="change: AC marked (unchanged) needs no task"; fresh
sed -i.bak 's/^- \[ \] AC-1: correct password logs in$/- [ ] AC-1: correct password logs in (unchanged)/' "$C/specs/auth.md"
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-2/' "$C/tasks.md"
run change add-login
expect_code 0; expect_not 'REQ-001/AC-1 has no task'; expect_has 'RESULT: OK'

name="change: AC range in a task and a #### heading under REQ"; fresh
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-1..2/' "$C/tasks.md"
awk '{ print } /^### REQ-002:/ { print ""; print "#### Scenario: lockout" }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run change add-login
expect_code 0; expect_has 'RESULT: OK'; expect_not 'without AC'

# ---------------------------------------------------------------- legacy Polish markers
# Artifacts written before the translation keep parsing: Typ, Usunięte AC, Było, Powód,
# (bez zmian), weryfikacja:, testy:, bez REQ.
name="legacy: Polish markers still parse"; fresh
cat > "$C/proposal.md" <<'EOF'
# Proposal: add-login

| Pole | Wartość |
|------|---------|
| Typ | feature |
| Status | Approved |
EOF
cat >> "$P/ai/specs/auth.md" <<'EOF'

### REQ-003: Old lockout

- [ ] AC-1: old behavior
EOF
cat > "$C/specs/auth.md" <<'EOF'
# Spec: auth — Delta for add-login

## ADDED

### REQ-002: Lockout after 5 attempts

- [ ] AC-1: the fifth failed attempt locks the account
- [ ] AC-2: a locked account gets 423

## MODIFIED

### REQ-001: Password login

- [ ] AC-1: correct password logs in (bez zmian)

**Usunięte AC:** AC-2 — merged into REQ-002
**Było:** 401 without a counter
**Powód:** the lockout needs a counter

## REMOVED

### REQ-003: Old lockout

**Powód:** replaced by REQ-002
EOF
cat > "$C/tasks.md" <<'EOF'
# Tasks: add-login

## Implementation
- [x] T-01: [BE] lockout — REQ-002 — weryfikacja: tests REQ-002 ✅ (commit: 2222222 · testy: tests/login.test.ts › locks)
- [ ] T-02: [BE] cleanup — bez REQ: housekeeping — weryfikacja: lint
EOF
run change add-login
expect_code 0; expect_has 'RESULT: OK'; expect_has '1/2 done'
expect_not 'without verification:|without a tests: mapping|without a REQ|without \*\*Reason|has no task'
run preflight add-login
expect_code 0; expect_not '^ERROR'
printf '# Proposal\n\n| Typ | refactor |\n| Status | Draft |\n' > "$C/proposal.md"; run change add-login
expect_code 1; expect_has 'ERROR .*refactor without INVARIANTS'
printf '\n**Było:** x\n\n### REQ-004: Legacy\n\n- [ ] AC-1: x (bez zmian)\n\n**Usunięte AC:** AC-2\n' >> "$P/ai/specs/auth.md"; run postmerge add-login
expect_code 1; expect_has 'ERROR .*Was: line in the main spec'; expect_has 'ERROR .*\(unchanged\) marker in the main spec'
expect_has 'ERROR .*Removed AC line in the main spec'

# ---------------------------------------------------------------- preflight
name="preflight: valid delta"; fresh; run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight: MODIFIED loses an AC"; fresh
grep -v 'increments the attempt counter' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-001/AC-2 is in the main spec but neither in the MODIFIED block nor in Removed AC'

name="preflight: MODIFIED removes an AC explicitly"; fresh
awk '/increments the attempt counter/ { next } /^\*\*Was:\*\*/ { print "**Removed AC:** AC-2 — merged into REQ-002" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight: Removed AC as a list"; fresh
awk '/increments the attempt counter/ { next } /^\*\*Was:\*\*/ { print "**Removed AC:**"; print "- AC-2 — merged into REQ-002"; print "" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight/postmerge: blank line between Removed AC and the list"; fresh
awk '/increments the attempt counter/ { next } /^\*\*Was:\*\*/ { print "**Removed AC:**"; print ""; print "- AC-2 — merged into REQ-002"; print "" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'
cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Requirements

### REQ-001: Password login

- [ ] AC-1: correct password logs in

### REQ-002: Lockout after 5 attempts

- [ ] AC-1: the fifth failed attempt locks the account
- [ ] AC-2: a locked account gets 423
EOF
run postmerge add-login
expect_code 0; expect_not '^ERROR'

name="preflight: ADDED collides with another main spec"; fresh
printf '# Spec: billing\n\n## Requirements\n\n### REQ-002: Invoice\n\n- [ ] AC-1: exists\n' > "$P/ai/specs/billing.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-002 \(ADDED\) already exists in ai/specs/billing.md — number collision'

name="preflight: ADDED collides with an active change"; fresh
mkdir -p "$P/ai/changes/other/specs"
printf '## ADDED\n\n### REQ-002: Other\n\n- [ ] AC-1: x\n' > "$P/ai/changes/other/specs/auth.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*is also added by active change'

name="preflight: MODIFIED of a nonexistent REQ"; fresh
sed -i.bak 's/^### REQ-001: Password login/### REQ-009: Password login/' "$C/specs/auth.md"; run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-009 \(MODIFIED\) does not exist'

name="preflight: parallel MODIFIED"; fresh
mkdir -p "$P/ai/changes/other/specs"
printf '## MODIFIED\n\n### REQ-001: Password login\n\n- [ ] AC-1: x\n- [ ] AC-2: y\n' > "$P/ai/changes/other/specs/auth.md"
run preflight add-login
expect_code 0; expect_has 'WARN .*REQ-001 is also changed by active change'

name="preflight: new domain"; fresh
mv "$C/specs/auth.md" "$C/specs/payments.md"
awk '/^## MODIFIED/ { exit } { print }' "$C/specs/payments.md" > "$C/specs/payments.md.new" && mv "$C/specs/payments.md.new" "$C/specs/payments.md"
run preflight add-login
expect_code 0; expect_has 'INFO .*new main spec ai/specs/payments.md'

# ---------------------------------------------------------------- postmerge
merged() {
  cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Requirements

### REQ-001: Password login

- [ ] AC-1: correct password logs in
- [ ] AC-2: wrong password returns 401 and increments the attempt counter

### REQ-002: Lockout after 5 attempts

- [ ] AC-1: the fifth failed attempt locks the account
- [ ] AC-2: a locked account gets 423

## History
EOF
}
name="postmerge: valid merge"; fresh; merged; run postmerge add-login
expect_code 0; expect_has 'RESULT: OK'

name="postmerge: delta heading and Was: in main"; fresh; merged
printf '\n## ADDED\n\n**Was:** x\n' >> "$P/ai/specs/auth.md"; run postmerge add-login
expect_code 1; expect_has 'ERROR .*delta heading'; expect_has 'ERROR .*Was: line in the main spec'

name="postmerge: (unchanged) marker in main"; fresh; merged
sed -i.bak 's/^- \[ \] AC-1: correct password logs in$/- [ ] AC-1: correct password logs in (unchanged)/' "$P/ai/specs/auth.md"
run postmerge add-login
expect_code 1; expect_has 'ERROR .*\(unchanged\) marker in the main spec'

name="postmerge: REQ from the delta did not reach main"; fresh; run postmerge add-login
expect_code 1; expect_has 'ERROR .*REQ-002 \(ADDED\) did not reach the main spec'

name="postmerge: AC in main outside the block"; fresh; merged
sed -i.bak 's/^- \[ \] AC-2: a locked account gets 423/&\n/' "$P/ai/specs/auth.md"
awk '{ print } /a locked account gets 423/ { print "- [ ] AC-3: added off the top of the head" }' "$P/ai/specs/auth.md.bak" > "$P/ai/specs/auth.md"
run postmerge add-login
expect_code 1; expect_has 'ERROR .*REQ-002/AC-3 in the main spec but not in the delta block'

# ---------------------------------------------------------------- next-req
name="next-req: max + 1, including the archive (a number does not come back)"; fresh
mkdir -p "$P/ai/changes/archive/2026-01-01-old/specs"
printf '### REQ-050: old\n' > "$P/ai/changes/archive/2026-01-01-old/specs/x.md"
run next-req
expect_code 0; expect_has '^REQ-051$'

name="next-req: number from a delta on another branch"; fresh
g checkout -q -b other; mkdir -p "$P/ai/changes/pay/specs"
printf '## ADDED\n\n### REQ-040: payment\n' > "$P/ai/changes/pay/specs/billing.md"
g add -A; g commit -m pay; g checkout -q main
run next-req
expect_code 0; expect_has '^REQ-041$'

# ---------------------------------------------------------------- cross-branch collisions
name="preflight: ADDED taken on the default branch"; fresh
g checkout -q -b feat; g checkout -q main
printf '# Spec: billing\n\n### REQ-002: Invoice\n\n- [ ] AC-1: the invoice is created\n' > "$P/ai/specs/billing.md"
g add -A; g commit -m billing; g checkout -q feat
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-002 \(ADDED\) is already in main:ai/specs/billing.md — collision with the default branch'

name="preflight: the same ADDED in a delta on another branch"; fresh
g checkout -q -b other; mkdir -p "$P/ai/changes/pay/specs"
printf '## ADDED\n\n### REQ-002: payment\n\n- [ ] AC-1: x\n\n## MODIFIED\n\n### REQ-001: y\n' > "$P/ai/changes/pay/specs/billing.md"
g add -A; g commit -m pay; g checkout -q main
run preflight add-login
expect_code 0; expect_has 'WARN .*REQ-002 \(ADDED\) is also added by change pay on branch other — whoever archives second runs sdd-check renumber'; expect_not 'REQ-001 \(ADDED\)'

name="preflight: a change from another branch already archived"
mkdir -p "$P/ai/changes/archive/2026-01-01-pay"; printf '# x\n' > "$P/ai/changes/archive/2026-01-01-pay/proposal.md"
run preflight add-login
expect_not 'is also added by change pay'

name="preflight: duplicate number in main specs"; fresh
printf '# Spec: billing\n\n### REQ-001: Invoice\n\n- [ ] AC-1: x\n' > "$P/ai/specs/billing.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-001 also appears in ai/specs/.* — duplicate number'

# ---------------------------------------------------------------- renumber
name="renumber: ADDED to next-req in the change's files"; fresh
printf 'REQ-0021 is a different number\n' >> "$C/proposal.md"
run renumber add-login REQ-002
expect_code 0; expect_has 'specs/auth.md: REQ-002 -> REQ-003'; expect_has 'tasks.md: REQ-002 -> REQ-003'
grep -q '^### REQ-003: Lockout' "$C/specs/auth.md" && ok || bad "no REQ-003 in the delta"
grep -q 'REQ-002' "$C/specs/auth.md" "$C/tasks.md" && bad "REQ-002 left behind" || ok
grep -q 'REQ-0021' "$C/proposal.md" && ok || bad "longer number REQ-0021 touched"
grep -q '^### REQ-001: Password' "$C/specs/auth.md" && ok || bad "REQ-001 touched"

name="renumber: MODIFIED rejected"; fresh; run renumber add-login REQ-001
expect_code 1; expect_has 'is not in ADDED'

name="renumber: target number taken"; fresh; run renumber add-login REQ-002 REQ-001
expect_code 1; expect_has 'REQ-001 is taken'

name="renumber: explicit free number"; fresh; run renumber add-login REQ-002 REQ-010
expect_code 0; expect_has 'REQ-002 -> REQ-010'

# ---------------------------------------------------------------- status
name="status: one line per change"; fresh
printf 'Verdict: PASS\nCommit HEAD: abc1234\n' > "$C/verification.md"; run status
expect_code 0; expect_has 'add-login: Status=Approved tasks=2/3 verification=PASS@abc1234'

# ---------------------------------------------------------------- drift
name="drift: unchanged since verification"; fresh
printf 'Verdict: PASS\nCommit HEAD: %s\n' "$(git -C "$P" rev-parse HEAD)" > "$C/verification.md"
run drift add-login
expect_code 0; expect_has 'unchanged since verification'

name="drift: a change outside the change's files raises no alarm"; printf 'x\n' >> "$P/src/other.ts"; run drift add-login
expect_code 0; expect_not 'WARN'

name="drift: a change file modified"; printf '// change\n' >> "$P/src/auth/login.ts"; run drift add-login
expect_has 'WARN .*src/auth/login.ts changed since verification'

name="drift: commit not available"; fresh
printf 'Verdict: PASS\nCommit HEAD: deadbeefdeadbeef\n' > "$C/verification.md"; run drift add-login
expect_has 'WARN .*not available locally'

name="affected: comment, endpoint, bare paths and a file name"; fresh
cat > "$C/design.md" <<'EOF'
# Design: add-login

### Affected Files

<!-- This section is the reading contract for /apply-sdd and /verify-sdd -->

| Layer | Changes | Files |
|-------|---------|-------|
| Interface | POST /api/login, API/UI contract | src/auth/extra.ts, `src/auth/login.ts` |
| Domain | helper | `lockout.ts` |

## API
EOF
printf 'export const extra = 1;\n' > "$P/src/auth/extra.ts"
printf 'export const l = 1;\n' > "$P/src/lockout.ts"
printf 'export const x = 1;\n' > "$P/src/xlockout.ts"
g add -A; g commit -m design
printf 'Verdict: PASS\nCommit HEAD: %s\n' "$(git -C "$P" rev-parse HEAD)" > "$C/verification.md"
printf '// a\n' >> "$P/src/auth/extra.ts"; printf '// b\n' >> "$P/src/lockout.ts"; printf '// c\n' >> "$P/src/xlockout.ts"
run drift add-login
expect_has 'WARN .*src/auth/extra.ts changed since verification'
expect_has 'WARN .*src/lockout.ts changed since verification'
expect_not 'xlockout'
expect_not 'unchanged since verification'
g add -A; g commit -m work2
run diff add-login "$(git -C "$P" rev-parse HEAD~1)"
expect_not '/apply-sdd|/verify-sdd|/api/login|API/UI'
expect_has 'INFO .*src/xlockout.ts outside Affected Files \(possibly unrequested\)'

# ---------------------------------------------------------------- diff
name="diff: test integrity and scope"; fresh
base=$(git -C "$P" rev-parse HEAD)
printf 'it.only("REQ-002/AC-1", () => { expect(1).toBe(1); });\n' > "$P/tests/lockout.test.ts"
printf 'it("REQ-001/AC-1", () => { expect(1).toBe(1); });\n' > "$P/tests/login.test.ts"
rm "$P/tests/old.test.ts"
printf 'export const x = 2;\n' >> "$P/src/other.ts"
printf 'export const lock = 1;\n' > "$P/src/auth/lockout.ts"
g add -A; g commit -m work
run diff add-login "$base"
expect_code 0
expect_has 'WARN .*tests/old.test.ts test file removed'
expect_has 'WARN .*tests/login.test.ts fewer assertions than in the base \(2 -> 1\)'
expect_has 'WARN .*tests/lockout.test.ts test skip marker added'
expect_has 'INFO .*src/other.ts outside Affected Files'
expect_not 'src/auth/lockout.ts outside Affected Files'

name="diff: base = parent of the change's first commit"; fresh
rm -rf "$P/.git"; git -C "$P" -c init.defaultBranch=main init -q
g add src tests; g commit -m base
g add -A; g commit -m tasks
first=$(git -C "$P" rev-parse HEAD)
run diff add-login
expect_has "parent of the first commit"; expect_has "comparison base: $first\\^"

name="diff: change in the initial commit → merge-base"; fresh; run diff add-login
expect_has 'base: merge-base of HEAD with'

name="diff: no base"; fresh; git -C "$P" branch -q -m odd; run diff add-login
expect_code 1; expect_has 'ERROR .*no comparison base'

# ---------------------------------------------------------------- index
name="index: requirements index"; fresh; run index
expect_code 0; expect_has '^auth: REQ-001 Password login \(AC: 2\)$'

# ---------------------------------------------------------------- stale
name="stale: commit outside the SDD cycle"; fresh
mkdir -p "$P/ai/changes/archive/2000-01-01-old-login"
cp "$C/design.md" "$P/ai/changes/archive/2000-01-01-old-login/design.md"
g add -A; g commit -m archive
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix login"
run stale
expect_has 'WARN .*old-login: .* hotfix login — change files touched outside the SDD cycle'
expect_not 'init|archive —'

name="stale: a commit from tasks.md belongs to the cycle"
printf '// bugfix\n' >> "$P/src/auth/login.ts"; printf -- '- [x] T-09: fix ✅\n' >> "$C/tasks.md"
g add -A; g commit -m "bugfix login"
run stale
expect_not 'bugfix login'

# ---------------------------------------------------------------- local mode (ai/changes/ outside the repo)
name="local ai/changes: stale and diff from hashes in tasks.md"; fresh
rm -rf "$P/.git"; git -C "$P" -c init.defaultBranch=main init -q
printf 'ai/changes/\n' > "$P/.gitignore"
g add -A; g commit -m base
mkdir -p "$P/ai/changes/archive/2000-01-01-old-login"
cp "$C/design.md" "$P/ai/changes/archive/2000-01-01-old-login/design.md"
printf '// t1\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "task one"
t1=$(git -C "$P" rev-parse --short HEAD)
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix login"
printf -- '- [x] T-01: x ✅ (commit: %s)\n' "$t1" > "$P/ai/changes/archive/2000-01-01-old-login/tasks.md"
sed -i.bak "s/T-02: \[BE\] attempt counter/T-02: [BE] attempt counter ✅ (commit: $t1)/" "$C/tasks.md"
run stale
expect_has 'WARN .*hotfix login'; expect_not 'task one'
printf '# Proposal\n\n| Ticket | PROJ-7 |\n' > "$P/ai/changes/archive/2000-01-01-old-login/proposal.md"
printf '// squash\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "feat: (PROJ-7) squash from MR"
run stale
expect_not 'PROJ-7'; expect_has 'WARN .*hotfix login'
printf '// kap\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "fix: (PROJ-70) another ticket"
run stale
expect_has 'WARN .*PROJ-70'

run diff add-login
expect_has 'parent of the oldest commit from tasks.md'

name="stale: a squash without a key reproduces a cycle commit's state"; fresh
rm -rf "$P/.git"; git -C "$P" -c init.defaultBranch=main init -q
printf 'ai/changes/\n' > "$P/.gitignore"
g add -A; g commit -m base
mkdir -p "$P/ai/changes/archive/2000-01-01-old-login"
cp "$C/design.md" "$P/ai/changes/archive/2000-01-01-old-login/design.md"
git -C "$P" checkout -q -b feature
printf '// t1\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "task one"
printf '// t2\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "task two"
t2=$(git -C "$P" rev-parse --short HEAD)
printf -- '- [x] T-01: x ✅ (commit: %s)\n' "$t2" > "$P/ai/changes/archive/2000-01-01-old-login/tasks.md"
git -C "$P" checkout -q main
git -C "$P" -c user.name=t -c user.email=t@t merge -q --squash feature >/dev/null 2>&1
g commit -m "Login lockout (#12)"
run stale
expect_not 'Login lockout'
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix after squash"
run stale
expect_has 'WARN .*hotfix after squash'; expect_not 'Login lockout'

# ---------------------------------------------------------------- usage
name="usage: no arguments"; fresh; run
expect_code 2

name="usage: outside an SDD project"; out=$(cd "$T" && "$BASH" "$CHECK" status 2>&1); code=$?
expect_code 2; expect_has 'no ai/ directory'

name="usage: invalid name"; fresh; run change ../x
expect_code 2

echo "sdd-check tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
