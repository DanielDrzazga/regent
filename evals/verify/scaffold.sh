#!/usr/bin/env bash
# Scaffold przypadków verify: notes-app z zestawu apply ze zmianą ui-search zaimplementowaną na
# gałęzi feat/ui-search — commit na task i ślad w tasks.md z ich hashami, jak po /regent:apply.
# Woła go scaffold.sh przypadku (eval przyjmuje tylko skrypt z katalogu przypadku).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
git init -q -b main .
printf '/ai/\n' >> .git/info/exclude
g() { git -c user.name="Regent Eval" -c user.email=eval@example.invalid "$@"; }
git add -A
g commit -qm "chore: projekt testowy notes-app"
git checkout -q -b feat/ui-search
done_dir="$here/fixtures/ui-search-done"
cp "$done_dir/web/search-box.js" web/ && cp "$done_dir/test/web-search-box.test.js" test/
git add web/search-box.js test/web-search-box.test.js
g commit -qm "feat: dodaj pole wyszukiwania"
h1=$(git rev-parse --short HEAD)
cp "$done_dir/web/result-count.js" web/ && cp "$done_dir/test/web-result-count.test.js" test/
git add web/result-count.js test/web-result-count.test.js
g commit -qm "feat: dodaj licznik wyników z polską odmianą"
h2=$(git rev-parse --short HEAD)
t=ai/changes/ui-search/tasks.md
awk -v h1="$h1" -v h2="$h2" '
  /^- \[ \] T-01:/ { sub(/^- \[ \] /, "- [x] "); $0 = $0 " ✅ (commit: " h1 " · testy: AC-1 → test/web-search-box.test.js › search box is a labelled search form with the current query; AC-2 → test/web-search-box.test.js › typing sets the query and clearing empties it)" }
  /^- \[ \] T-02:/ { sub(/^- \[ \] /, "- [x] "); $0 = $0 " ✅ (commit: " h2 " · testy: AC-1 → test/web-result-count.test.js › result count uses Polish plural forms)" }
  { print }' "$t" > "$t.new" && mv "$t.new" "$t"
