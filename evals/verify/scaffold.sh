#!/usr/bin/env bash
# Scaffold of the verify cases: notes-app from the apply set with the ui-search change implemented on
# the feat/ui-search branch — a commit per task and the tasks.md trace with their hashes, as after
# /regent:apply. Called by the case's scaffold.sh (the eval accepts only a script from the case dir).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
git init -q -b main .
g() { git -c user.name="Regent Eval" -c user.email=eval@example.invalid "$@"; }
git add -A -- . ':(exclude)ai'
g commit -qm "chore: notes-app test project"
git checkout -q -b feat/ui-search
done_dir="$here/fixtures/ui-search-done"
cp "$done_dir/web/search-box.js" web/ && cp "$done_dir/test/web-search-box.test.js" test/
git add web/search-box.js test/web-search-box.test.js
g commit -qm "feat: add the search box"
h1=$(git rev-parse --short HEAD)
cp "$done_dir/web/result-count.js" web/ && cp "$done_dir/test/web-result-count.test.js" test/
git add web/result-count.js test/web-result-count.test.js
g commit -qm "feat: add the result count with Polish plural forms"
h2=$(git rev-parse --short HEAD)
t=ai/changes/ui-search/tasks.md
awk -v h1="$h1" -v h2="$h2" '
  /^- \[ \] T-01:/ { sub(/^- \[ \] /, "- [x] "); $0 = $0 " ✅ (commit: " h1 " · tests: AC-1 → test/web-search-box.test.js › search box is a labelled search form with the current query; AC-2 → test/web-search-box.test.js › typing sets the query and clearing empties it)" }
  /^- \[ \] T-02:/ { sub(/^- \[ \] /, "- [x] "); $0 = $0 " ✅ (commit: " h2 " · tests: AC-1 → test/web-result-count.test.js › result count uses Polish plural forms)" }
  { print }' "$t" > "$t.new" && mv "$t.new" "$t"
