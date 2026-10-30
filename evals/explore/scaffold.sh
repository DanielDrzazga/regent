#!/usr/bin/env bash
# Scaffold przypadków explore: notes-app z zestawu apply, z opcjonalnym grafem kodu.
# Argument "graph" (opcjonalny): po commicie startowym buduje graf (Graphify, tylko kod/zero
# LLM) do ai/graph/ — wymaga `graphify` w PATH, inaczej przypadek jawnie oblewa (exit 1), nie
# przechodzi po cichu.
set -eu
graph=${1:-}
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/../apply/fixtures/notes-app/." .
git init -q -b main .
printf '/ai/\n' >> .git/info/exclude
git add -A
git -c user.name="Regent Eval" -c user.email=eval@example.invalid commit -qm "chore: projekt testowy notes-app"

if [ "$graph" = graph ]; then
  command -v graphify >/dev/null 2>&1 \
    || { echo "evals/explore: graphify niedostępne w PATH — wariant graph wymaga zainstalowanego CLI" >&2; exit 1; }
  graphify extract . --code-only --out ai/graph >/dev/null
fi
