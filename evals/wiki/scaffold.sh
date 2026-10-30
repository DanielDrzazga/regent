#!/usr/bin/env bash
# Wspólny scaffold przypadków wiki: notes-app z zestawu apply + nakładka fixtures/project
# (słownik, vault ai/wiki/, notatka do ingest). Woła go scaffold.sh przypadku z trybem:
#   vault (domyślny) — projekt z vaultem
#   init             — bez ai/wiki/
#   lint             — vault z podrzuconymi błędami: strona potwierdzone bez sources (sierota,
#                      brak w index.md) i wpis w index.md bez pliku
#   sync             — kotwica last-sync-sha na commicie startowym, po niej commit w src/ i w web/
# Daty commitów są stałe, więc hashe są znane z góry (oceniacz kotwicy w holdout-sync).
#
# Drugi argument "graph" (opcjonalny): po trybie buduje graf kodu (Graphify, tylko kod/zero LLM)
# do ai/graph/ — wymaga `graphify` w PATH, inaczej przypadek jawnie oblewa (exit 1), nie przechodzi
# po cichu. W trybie sync+graph dopisuje też cli/print-notes.js (zależny od web/note-list.js) +
# commit, TYLKO w tym wariancie — hash trybu sync bez "graph" zostaje nietknięty.
set -eu
mode=${1:-vault}
graph=${2:-}
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
cp -R "$here/fixtures/project/." .
git init -q -b main .
git config core.precomposeunicode true
printf '/ai/\n.DS_Store\n' >> .git/info/exclude
# Tożsamość i daty przez zmienne środowiska: wygrywają z GIT_AUTHOR_* maszyny, a -c user.name nie.
g() {
  GIT_AUTHOR_NAME="Regent Eval" GIT_AUTHOR_EMAIL=eval@example.invalid GIT_AUTHOR_DATE=2026-10-01T12:00:00Z \
  GIT_COMMITTER_NAME="Regent Eval" GIT_COMMITTER_EMAIL=eval@example.invalid GIT_COMMITTER_DATE=2026-10-01T12:00:00Z \
    git "$@"
}
git add -A
g commit -qm "chore: projekt testowy notes-app"
anchor=$(git rev-parse HEAD)
sed "s/SHA_STARTOWY/$anchor/" ai/wiki/Home.md > ai/wiki/Home.md.new && mv ai/wiki/Home.md.new ai/wiki/Home.md

case "$mode" in
  vault) ;;
  init) rm -rf ai/wiki ;;
  lint)
    cp "$here/fixtures/lint/Eksport notatek.md" ai/wiki/wiedza/
    printf '| [[Tagi notatek]] | reguła | hipoteza | Notatkę można oznaczyć wieloma tagami |\n' >> ai/wiki/index.md
    ;;
  sync)
    cp "$here/fixtures/sync/src/notes.js" src/
    git add src/notes.js
    g commit -qm "feat: odrzucaj tytuł dłuższy niż 80 znaków"
    cp "$here/fixtures/sync/web/note-list.js" web/
    git add web/note-list.js
    g commit -qm "fix: escapuj tytuł na liście notatek"
    if [ "$graph" = graph ]; then
      # Zależność pośrednia dla holdout-sync-graph: cli/ importuje web/note-list.js, a żadna
      # strona nie ma obszar: cli/ po prefiksie — tylko graf ją znajdzie.
      mkdir -p cli
      cp "$here/fixtures/sync/cli/print-notes.js" cli/
      git add cli/print-notes.js
      g commit -qm "feat: dodaj wydruk notatek w konsoli"
    else
      # Oceniacz kotwica-na-head w holdout-sync/case.yaml zna ten hash. Zmiana projektu testowego
      # (notes-app albo fixtures/) zmienia hash: popraw oceniacz i tę linię.
      expected=2ff82e9
      head=$(git rev-parse --short=7 HEAD)
      [ "$head" = "$expected" ] || { echo "evals/wiki: HEAD $head ≠ $expected — popraw kotwica-na-head w holdout-sync/case.yaml i expected w scaffold.sh" >&2; exit 1; }
    fi
    ;;
  *) echo "evals/wiki/scaffold.sh: nieznany tryb $mode" >&2; exit 2 ;;
esac

if [ "$graph" = graph ]; then
  command -v graphify >/dev/null 2>&1 \
    || { echo "evals/wiki: graphify niedostępne w PATH — wariant graph wymaga zainstalowanego CLI" >&2; exit 1; }
  graphify extract . --code-only --out ai/graph >/dev/null
fi
