#!/usr/bin/env bash
# Testy scripts/sdd-check.sh — fixture'y w katalogu tymczasowym, bez sieci.
# Użycie: bash scripts/tests/sdd-check.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
# Testy niezależne od globalnej konfiguracji gita użytkownika (np. globalny .gitignore z ai/changes/).
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

# Skrypt uruchamiamy TYM SAMYM interpreterem co testy ($BASH) — `/bin/bash test.sh` testuje bash 3.2.
run() { out=$(cd "$P" && "$BASH" "$CHECK" "$@" 2>&1); code=$?; }
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "$out" | sed 's/^/      /'; }
expect_code() { [ "$code" -eq "$1" ] && ok || bad "kod wyjścia $code, oczekiwano $1"; }
expect_has()  { printf '%s\n' "$out" | grep -qE -- "$1" && ok || bad "brak w wyjściu: $1"; }
expect_not()  { if printf '%s\n' "$out" | grep -qE -- "$1"; then bad "nieoczekiwane w wyjściu: $1"; else ok; fi; }
g() { git -C "$P" -c user.name=t -c user.email=t@t "$@" >/dev/null 2>&1; }
C="$P/ai/changes/add-login"

fresh() {
  rm -rf "$P"
  mkdir -p "$P/ai/specs" "$C/specs" "$P/src/auth" "$P/tests"
  cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Wymagania

### REQ-001: Logowanie hasłem

**Given** konto istnieje

**Acceptance Criteria:**
- [ ] AC-1: poprawne hasło loguje
- [ ] AC-2: złe hasło zwraca 401

## History

| Data | Zmiana | Typ | Opis |
|------|--------|-----|------|
EOF
  cat > "$C/proposal.md" <<'EOF'
# Proposal: add-login

## Metadane

| Pole | Wartość |
|------|---------|
| Typ | feature |
| Status | Approved |
EOF
  cat > "$C/specs/auth.md" <<'EOF'
# Spec: auth — Delta dla add-login

<!-- REQ-XXX w komentarzu nie jest placeholderem
     ### REQ-777: to też tylko komentarz -->

## ADDED

### REQ-002: Blokada po 5 próbach

**Acceptance Criteria:**
- [ ] AC-1: piąta nieudana próba blokuje konto
- [ ] AC-2: zablokowane konto dostaje 423

## MODIFIED

### REQ-001: Logowanie hasłem

**Acceptance Criteria:**
- [ ] AC-1: poprawne hasło loguje
- [ ] AC-2: złe hasło zwraca 401 i zwiększa licznik prób

**Było:** 401 bez licznika
**Powód:** blokada wymaga licznika

## Notes

```
### REQ-XXX: przykład w bloku kodu — ignorowany
```
EOF
  cat > "$C/design.md" <<'EOF'
# Design: add-login

### Affected Files

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Domain | licznik | `src/auth/login.ts`, `src/auth/lockout.ts` |
| Tests | testy | tests/ |

## API
EOF
  cat > "$C/tasks.md" <<'EOF'
# Tasks: add-login

## Setup
- [x] T-01: konfiguracja limitu — pliki: src/auth/config.ts — weryfikacja: make check ✅ (commit: 1111111)

## Implementation
- [x] T-02: [BE] licznik prób — REQ-001/AC-1, AC-2 — pliki: src/auth/login.ts — weryfikacja: test REQ-001/AC-2 ✅ (commit: 2222222 · testy: tests/login.test.ts › loguje)
- [ ] T-03: [BE] blokada — REQ-002 — pliki: src/auth/lockout.ts — weryfikacja: testy REQ-002 (po T-02)

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
name="change: poprawna zmiana"; fresh; run change add-login
expect_code 0; expect_has 'RESULT: OK'; expect_has '2/3 zrobione'; expect_not 'REQ-XXX|REQ-777'

name="change: placeholder z szablonu"; fresh
printf '\n## ADDED\n\n### REQ-XXX: [Nazwa]\n' >> "$C/specs/auth.md"; run change add-login
expect_code 1; expect_has 'ERROR .*placeholder'

name="change: REQ bez AC"; fresh
sed -i.bak 's/^## MODIFIED/### REQ-003: Pusty\n\n## MODIFIED/' "$C/specs/auth.md"
awk '/^## MODIFIED/ && !d { print "### REQ-003: Pusty"; print ""; d = 1 } { print }' "$C/specs/auth.md.bak" > "$C/specs/auth.md"
run change add-login
expect_code 1; expect_has 'ERROR .*REQ-003 bez AC'

name="change: AC bez taska"; fresh
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-2/' "$C/tasks.md"; run change add-login
expect_code 0; expect_has 'WARN .*REQ-001/AC-1 nie ma taska'; expect_has 'RESULT: WARN'

name="change: nietypowy checkbox i brak weryfikacji"; fresh
printf -- '- [~] T-04: [BE] coś — REQ-002\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*nietypowy checkbox'; expect_has 'WARN .*T-04 bez weryfikacja'; expect_has '2/4 zrobione'

name="change: odhaczony task bez śladu commit i testy"; fresh
printf -- '- [x] T-04: [BE] coś — REQ-002/AC-1 — weryfikacja: test\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*T-04 odhaczony bez śladu'; expect_has 'WARN .*T-04 odhaczony bez mapowania testy:'

name="change: task bez REQ poza Setup"; fresh
printf -- '- [ ] T-04: [BE] porządki — pliki: x — weryfikacja: lint\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*T-04 bez odwołania do REQ'

name="change: odwołanie do nieistniejącego REQ"; fresh
printf -- '- [ ] T-04: [BE] coś — REQ-099 — weryfikacja: test\n' >> "$C/tasks.md"; run change add-login
expect_has 'WARN .*nieistniejącego REQ-099'

name="change: Status z placeholderem"; fresh
sed -i.bak 's/| Status | Approved |/| Status | Draft \/ Approved \/ Rejected |/' "$C/proposal.md"; run change add-login
expect_code 1; expect_has 'ERROR .*Status'

name="change: Status jako linia"; fresh
printf '# Proposal\n\nTyp: feature\nStatus: Draft\n' > "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Draft'

name="change: pogrubiony Status w tabeli i w linii"; fresh
sed -i.bak 's/| Status | Approved |/| **Status** | **Approved** |/' "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Approved'
printf '# Proposal\n\n**Typ:** feature\n**Status:** `Draft`\n' > "$C/proposal.md"; run change add-login
expect_code 0; expect_has 'Status: Draft'

name="change: refactor bez INVARIANTS"; fresh
sed -i.bak 's/| Typ | feature |/| Typ | refactor |/' "$C/proposal.md"; run change add-login
expect_code 1; expect_has 'ERROR .*refactor bez INVARIANTS'

name="change: REMOVED bez powodu"; fresh
printf '\n## REMOVED\n\n### REQ-005: Stare\n' >> "$C/specs/auth.md"; run change add-login
expect_code 1; expect_has 'ERROR .*REQ-005 w REMOVED bez'

name="change: brak zmiany"; fresh; run change nie-ma
expect_code 1; expect_has 'brak katalogu zmiany'

name="change: refactor z samymi INVARIANTS"; fresh
sed -i.bak 's/| Typ | feature |/| Typ | refactor |/' "$C/proposal.md"
printf '# Delta\n\n## INVARIANTS\n\n- **INV-1:** API bez zmian\n- **INV-2:** testy bez modyfikacji\n' > "$C/specs/auth.md"
printf '# Tasks\n\n## Implementation\n- [ ] T-01: [BE] wydziel serwis — INV-1, INV-2 — pliki: src/auth/login.ts — weryfikacja: istniejące testy zielone bez zmian\n- [ ] T-02: [BE] porządki — INV-3 — weryfikacja: lint\n' > "$C/tasks.md"
run change add-login
expect_code 0; expect_not 'T-01 bez odwołania'; expect_has 'WARN .*T-02 odwołuje się do nieistniejącego INV-3'
run preflight add-login
expect_code 0; expect_has 'INFO .*delta bez REQ \(tylko INVARIANTS\)'; expect_not 'nowy main spec'
rm "$P/ai/specs/auth.md"; run postmerge add-login
expect_code 0; expect_not '^ERROR'

name="change: AC (bez zmian) nie wymaga taska"; fresh
sed -i.bak 's/^- \[ \] AC-1: poprawne hasło loguje$/- [ ] AC-1: poprawne hasło loguje (bez zmian)/' "$C/specs/auth.md"
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-2/' "$C/tasks.md"
run change add-login
expect_code 0; expect_not 'REQ-001/AC-1 nie ma taska'; expect_has 'RESULT: OK'

name="change: zakres AC w tasku i nagłówek #### pod REQ"; fresh
sed -i.bak 's/REQ-001\/AC-1, AC-2/REQ-001\/AC-1..2/' "$C/tasks.md"
awk '{ print } /^### REQ-002:/ { print ""; print "#### Scenariusz: blokada" }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run change add-login
expect_code 0; expect_has 'RESULT: OK'; expect_not 'bez AC'

# ---------------------------------------------------------------- preflight
name="preflight: poprawna delta"; fresh; run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight: MODIFIED gubi AC"; fresh
grep -v 'zwiększa licznik' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-001/AC-2 jest w main spec'

name="preflight: MODIFIED usuwa AC jawnie"; fresh
awk '/zwiększa licznik/ { next } /^\*\*Było:\*\*/ { print "**Usunięte AC:** AC-2 — scalone z REQ-002" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight: Usunięte AC jako lista"; fresh
awk '/zwiększa licznik/ { next } /^\*\*Było:\*\*/ { print "**Usunięte AC:**"; print "- AC-2 — scalone z REQ-002"; print "" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'

name="preflight/postmerge: pusta linia między Usunięte AC a listą"; fresh
awk '/zwiększa licznik/ { next } /^\*\*Było:\*\*/ { print "**Usunięte AC:**"; print ""; print "- AC-2 — scalone z REQ-002"; print "" } { print }' "$C/specs/auth.md" > "$C/specs/auth.md.new" && mv "$C/specs/auth.md.new" "$C/specs/auth.md"
run preflight add-login
expect_code 0; expect_not '^ERROR'
cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Wymagania

### REQ-001: Logowanie hasłem

- [ ] AC-1: poprawne hasło loguje

### REQ-002: Blokada po 5 próbach

- [ ] AC-1: piąta nieudana próba blokuje konto
- [ ] AC-2: zablokowane konto dostaje 423
EOF
run postmerge add-login
expect_code 0; expect_not '^ERROR'

name="preflight: ADDED koliduje z innym main spec"; fresh
printf '# Spec: billing\n\n## Wymagania\n\n### REQ-002: Faktura\n\n- [ ] AC-1: jest\n' > "$P/ai/specs/billing.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-002 \(ADDED\) już istnieje w ai/specs/billing.md'

name="preflight: ADDED koliduje z aktywną zmianą"; fresh
mkdir -p "$P/ai/changes/other/specs"
printf '## ADDED\n\n### REQ-002: Inne\n\n- [ ] AC-1: x\n' > "$P/ai/changes/other/specs/auth.md"
run preflight add-login
expect_code 1; expect_has 'ERROR .*dodaje też aktywna zmiana'

name="preflight: MODIFIED nieistniejącego REQ"; fresh
sed -i.bak 's/^### REQ-001: Logowanie hasłem/### REQ-009: Logowanie hasłem/' "$C/specs/auth.md"; run preflight add-login
expect_code 1; expect_has 'ERROR .*REQ-009 \(MODIFIED\) nie istnieje'

name="preflight: równoległy MODIFIED"; fresh
mkdir -p "$P/ai/changes/other/specs"
printf '## MODIFIED\n\n### REQ-001: Logowanie hasłem\n\n- [ ] AC-1: x\n- [ ] AC-2: y\n' > "$P/ai/changes/other/specs/auth.md"
run preflight add-login
expect_code 0; expect_has 'WARN .*REQ-001 zmienia też aktywna zmiana'

name="preflight: nowa domena"; fresh
mv "$C/specs/auth.md" "$C/specs/payments.md"
awk '/^## MODIFIED/ { exit } { print }' "$C/specs/payments.md" > "$C/specs/payments.md.new" && mv "$C/specs/payments.md.new" "$C/specs/payments.md"
run preflight add-login
expect_code 0; expect_has 'INFO .*nowy main spec ai/specs/payments.md'

# ---------------------------------------------------------------- postmerge
merged() {
  cat > "$P/ai/specs/auth.md" <<'EOF'
# Spec: auth

## Wymagania

### REQ-001: Logowanie hasłem

- [ ] AC-1: poprawne hasło loguje
- [ ] AC-2: złe hasło zwraca 401 i zwiększa licznik prób

### REQ-002: Blokada po 5 próbach

- [ ] AC-1: piąta nieudana próba blokuje konto
- [ ] AC-2: zablokowane konto dostaje 423

## History
EOF
}
name="postmerge: poprawny merge"; fresh; merged; run postmerge add-login
expect_code 0; expect_has 'RESULT: OK'

name="postmerge: nagłówek delty i Było w main"; fresh; merged
printf '\n## ADDED\n\n**Było:** x\n' >> "$P/ai/specs/auth.md"; run postmerge add-login
expect_code 1; expect_has 'ERROR .*nagłówek delty'; expect_has 'ERROR .*Było'

name="postmerge: znacznik (bez zmian) w main"; fresh; merged
sed -i.bak 's/^- \[ \] AC-1: poprawne hasło loguje$/- [ ] AC-1: poprawne hasło loguje (bez zmian)/' "$P/ai/specs/auth.md"
run postmerge add-login
expect_code 1; expect_has 'ERROR .*znacznik \(bez zmian\) w main spec'

name="postmerge: REQ z delty nie trafił do main"; fresh; run postmerge add-login
expect_code 1; expect_has 'ERROR .*REQ-002 \(ADDED\) nie trafił do main spec'

name="postmerge: AC w main spoza bloku"; fresh; merged
sed -i.bak 's/^- \[ \] AC-2: zablokowane konto dostaje 423/&\n/' "$P/ai/specs/auth.md"
awk '{ print } /zablokowane konto dostaje 423/ { print "- [ ] AC-3: dopisane z głowy" }' "$P/ai/specs/auth.md.bak" > "$P/ai/specs/auth.md"
run postmerge add-login
expect_code 1; expect_has 'ERROR .*REQ-002/AC-3 w main spec, a nie ma go w bloku'

# ---------------------------------------------------------------- next-req
name="next-req: max + 1, z archiwum (numer nie wraca)"; fresh
mkdir -p "$P/ai/changes/archive/2026-01-01-old/specs"
printf '### REQ-050: stare\n' > "$P/ai/changes/archive/2026-01-01-old/specs/x.md"
run next-req
expect_code 0; expect_has '^REQ-051$'

# ---------------------------------------------------------------- status
name="status: jedna linia na zmianę"; fresh
printf 'Verdict: PASS\nCommit HEAD: abc1234\n' > "$C/verification.md"; run status
expect_code 0; expect_has 'add-login: Status=Approved tasks=2/3 verification=PASS@abc1234'

# ---------------------------------------------------------------- drift
name="drift: bez zmian od weryfikacji"; fresh
printf 'Verdict: PASS\nCommit HEAD: %s\n' "$(git -C "$P" rev-parse HEAD)" > "$C/verification.md"
run drift add-login
expect_code 0; expect_has 'bez zmian od weryfikacji'

name="drift: zmiana poza plikami zmiany nie alarmuje"; printf 'x\n' >> "$P/src/other.ts"; run drift add-login
expect_code 0; expect_not 'WARN'

name="drift: zmieniony plik zmiany"; printf '// zmiana\n' >> "$P/src/auth/login.ts"; run drift add-login
expect_has 'WARN .*src/auth/login.ts zmieniony od weryfikacji'

name="drift: commit niedostępny"; fresh
printf 'Verdict: PASS\nCommit HEAD: deadbeefdeadbeef\n' > "$C/verification.md"; run drift add-login
expect_has 'WARN .*niedostępny'

name="affected: komentarz, endpoint, gołe ścieżki i nazwa pliku"; fresh
cat > "$C/design.md" <<'EOF'
# Design: add-login

### Affected Files

<!-- Ta sekcja to kontrakt czytania dla /apply-sdd i /verify-sdd -->

| Warstwa | Zmiany | Pliki |
|---------|--------|-------|
| Interface | POST /api/login, kontrakt API/UI | src/auth/extra.ts, `src/auth/login.ts` |
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
expect_has 'WARN .*src/auth/extra.ts zmieniony od weryfikacji'
expect_has 'WARN .*src/lockout.ts zmieniony od weryfikacji'
expect_not 'xlockout'
expect_not 'bez zmian od weryfikacji'
g add -A; g commit -m work2
run diff add-login "$(git -C "$P" rev-parse HEAD~1)"
expect_not '/apply-sdd|/verify-sdd|/api/login|API/UI'
expect_has 'INFO .*src/xlockout.ts poza Affected Files'

# ---------------------------------------------------------------- diff
name="diff: integralność testów i zakres"; fresh
base=$(git -C "$P" rev-parse HEAD)
printf 'it.only("REQ-002/AC-1", () => { expect(1).toBe(1); });\n' > "$P/tests/lockout.test.ts"
printf 'it("REQ-001/AC-1", () => { expect(1).toBe(1); });\n' > "$P/tests/login.test.ts"
rm "$P/tests/old.test.ts"
printf 'export const x = 2;\n' >> "$P/src/other.ts"
printf 'export const lock = 1;\n' > "$P/src/auth/lockout.ts"
g add -A; g commit -m work
run diff add-login "$base"
expect_code 0
expect_has 'WARN .*tests/old.test.ts usunięty plik testu'
expect_has 'WARN .*tests/login.test.ts mniej asercji niż w bazie \(2 -> 1\)'
expect_has 'WARN .*tests/lockout.test.ts dodany marker pominięcia testu'
expect_has 'INFO .*src/other.ts poza Affected Files'
expect_not 'src/auth/lockout.ts poza Affected Files'

name="diff: baza = rodzic pierwszego commitu zmiany"; fresh
rm -rf "$P/.git"; git -C "$P" -c init.defaultBranch=main init -q
g add src tests; g commit -m base
g add -A; g commit -m tasks
first=$(git -C "$P" rev-parse HEAD)
run diff add-login
expect_has "rodzic pierwszego commitu"; expect_has "baza porównania: $first\\^"

name="diff: zmiana w commicie początkowym → merge-base"; fresh; run diff add-login
expect_has 'baza: merge-base HEAD z'

name="diff: brak bazy"; fresh; git -C "$P" branch -q -m odd; run diff add-login
expect_code 1; expect_has 'ERROR .*brak bazy'

# ---------------------------------------------------------------- index
name="index: spis wymagań"; fresh; run index
expect_code 0; expect_has '^auth: REQ-001 Logowanie hasłem \(AC: 2\)$'

# ---------------------------------------------------------------- stale
name="stale: commit poza cyklem SDD"; fresh
mkdir -p "$P/ai/changes/archive/2000-01-01-old-login"
cp "$C/design.md" "$P/ai/changes/archive/2000-01-01-old-login/design.md"
g add -A; g commit -m archive
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix login"
run stale
expect_has 'WARN .*old-login: .* hotfix login — pliki zmiany ruszone poza cyklem SDD'
expect_not 'init|archive —'

name="stale: commit z tasks.md należy do cyklu"
printf '// bugfix\n' >> "$P/src/auth/login.ts"; printf -- '- [x] T-09: fix ✅\n' >> "$C/tasks.md"
g add -A; g commit -m "bugfix login"
run stale
expect_not 'bugfix login'

# ---------------------------------------------------------------- tryb lokalny (ai/changes/ poza repo)
name="lokalny ai/changes: stale i diff z hashy w tasks.md"; fresh
rm -rf "$P/.git"; git -C "$P" -c init.defaultBranch=main init -q
printf 'ai/changes/\n' > "$P/.gitignore"
g add -A; g commit -m base
mkdir -p "$P/ai/changes/archive/2000-01-01-old-login"
cp "$C/design.md" "$P/ai/changes/archive/2000-01-01-old-login/design.md"
printf '// t1\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "task one"
t1=$(git -C "$P" rev-parse --short HEAD)
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix login"
printf -- '- [x] T-01: x ✅ (commit: %s)\n' "$t1" > "$P/ai/changes/archive/2000-01-01-old-login/tasks.md"
sed -i.bak "s/T-02: \[BE\] licznik prób/T-02: [BE] licznik prób ✅ (commit: $t1)/" "$C/tasks.md"
run stale
expect_has 'WARN .*hotfix login'; expect_not 'task one'
printf '# Proposal\n\n| Ticket | CAP-7 |\n' > "$P/ai/changes/archive/2000-01-01-old-login/proposal.md"
printf '// squash\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "feat: (CAP-7) squash z MR"
run stale
expect_not 'CAP-7'; expect_has 'WARN .*hotfix login'
printf '// kap\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "fix: (CAP-70) inny ticket"
run stale
expect_has 'WARN .*CAP-70'

run diff add-login
expect_has 'rodzic najstarszego commitu z tasks.md'

name="stale: squash bez klucza odtwarza stan commitu cyklu"; fresh
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
printf '// hotfix\n' >> "$P/src/auth/login.ts"; g add -A; g commit -m "hotfix po squashu"
run stale
expect_has 'WARN .*hotfix po squashu'; expect_not 'Login lockout'

# ---------------------------------------------------------------- użycie
name="użycie: bez argumentów"; fresh; run
expect_code 2

name="użycie: poza projektem SDD"; out=$(cd "$T" && "$BASH" "$CHECK" status 2>&1); code=$?
expect_code 2; expect_has 'brak katalogu ai/'

name="użycie: niepoprawna nazwa"; fresh; run change ../x
expect_code 2

echo "sdd-check tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
