#!/usr/bin/env bash
# Shared scaffold of the propose cases: notes-app from the apply set without its active changes —
# ai/docs/ and ai/specs/ stay, so /regent:propose has a configured project and no change to conflict
# with. Called by a case's scaffold.sh (the eval accepts only a script from the case dir).
# ai/ is tracked in a real project (/regent:init Step 0.5) but not committed yet before the first
# SDD commit — the start commit holds only code and tests.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
rm -rf ai/changes
git init -q -b main .
git add -A -- . ':(exclude)ai'
git -c user.name="Regent Eval" -c user.email=eval@example.invalid commit -qm "chore: notes-app test project"
