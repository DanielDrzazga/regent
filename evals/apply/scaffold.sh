#!/usr/bin/env bash
# Shared scaffold of the apply cases: the notes-app test project in the eval sandbox dir.
# Called by every case's scaffold.sh (the eval accepts only a script from the case dir).
# ai/ is tracked in a real project (/regent:init Step 0.5) but not committed yet before the first
# SDD commit — the start commit holds only code and tests; apply commits ai/ itself.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/fixtures/notes-app/." .
git init -q -b main .
git add -A -- . ':(exclude)ai'
git -c user.name="Regent Eval" -c user.email=eval@example.invalid commit -qm "chore: notes-app test project"
