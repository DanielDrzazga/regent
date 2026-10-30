#!/usr/bin/env bash
# sync + graf: jak holdout-sync, plus strona wiki "Wydruk konsolowy" (obszar: cli/) dotknięta
# wyłącznie przez zależność pośrednią w grafie (cli/print-notes.js importuje web/note-list.js,
# zmienione w drugim commicie sync) — prefiks obszar: nie złapie tego sam.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
bash "$here/../scaffold.sh" sync graph
cp "$here/Wydruk konsolowy.md" ai/wiki/wiedza/
printf '| [[Wydruk konsolowy]] | przepływ | wyprowadzone | Wydruk Notatek w konsoli |\n' >> ai/wiki/index.md
