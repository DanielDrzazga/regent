#!/usr/bin/env bash
# Shared scaffold of the wiki cases: notes-app from the apply set + the fixtures/project overlay
# (glossary, vault ai/wiki/, a note to ingest). Called by a case's scaffold.sh with a mode:
#   vault (default) — project with a vault
#   init            — without ai/wiki/
#   lint            — vault with planted errors: a confirmed page without sources (an orphan,
#                     missing from index.md) and an index.md entry without a file
#   sync            — last-sync-sha anchor on the start commit, then a commit in src/ and in web/
# Commit dates are fixed, so the hashes are known in advance (the anchor grader in holdout-sync).
# ai/ is tracked in a real project (/regent:init Step 0.5) but not committed yet before the first
# SDD commit — the start commit holds only code and tests.
set -eu
mode=${1:-vault}
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
cp -R "$here/fixtures/project/." .
git init -q -b main .
git config core.precomposeunicode true
printf '.DS_Store\n' >> .git/info/exclude
# Identity and dates through environment variables: they win over the machine's GIT_AUTHOR_*, -c user.name does not.
g() {
  GIT_AUTHOR_NAME="Regent Eval" GIT_AUTHOR_EMAIL=eval@example.invalid GIT_AUTHOR_DATE=2026-10-01T12:00:00Z \
  GIT_COMMITTER_NAME="Regent Eval" GIT_COMMITTER_EMAIL=eval@example.invalid GIT_COMMITTER_DATE=2026-10-01T12:00:00Z \
    git "$@"
}
git add -A -- . ':(exclude)ai'
g commit -qm "chore: notes-app test project"
anchor=$(git rev-parse HEAD)
sed "s/START_SHA/$anchor/" ai/wiki/Home.md > ai/wiki/Home.md.new && mv ai/wiki/Home.md.new ai/wiki/Home.md

case "$mode" in
  vault) ;;
  init) rm -rf ai/wiki ;;
  lint)
    cp "$here/fixtures/lint/Note export.md" ai/wiki/knowledge/
    printf '| [[Note tags]] | rule | hypothesis | A Note can carry many tags |\n' >> ai/wiki/index.md
    ;;
  sync)
    cp "$here/fixtures/sync/src/notes.js" src/
    git add src/notes.js
    g commit -qm "feat: reject a title longer than 80 characters"
    cp "$here/fixtures/sync/web/note-list.js" web/
    git add web/note-list.js
    g commit -qm "fix: escape the title on the note list"
    # The anchor-at-head grader in holdout-sync/case.yaml knows this hash. A change of the test project
    # (notes-app or fixtures/) changes the hash: fix the grader and this line.
    expected=99acad5
    head=$(git rev-parse --short=7 HEAD)
    [ "$head" = "$expected" ] || { echo "evals/wiki: HEAD $head ≠ $expected — fix anchor-at-head in holdout-sync/case.yaml and expected in scaffold.sh" >&2; exit 1; }
    ;;
  *) echo "evals/wiki/scaffold.sh: unknown mode $mode" >&2; exit 2 ;;
esac
