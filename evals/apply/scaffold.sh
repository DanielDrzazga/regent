#!/usr/bin/env bash
# Wspólny scaffold przypadków apply: projekt testowy notes-app w katalogu sandboksu evala.
# Woła go scaffold.sh każdego przypadku (eval przyjmuje tylko skrypt z katalogu przypadku).
# ai/ jest poza gitem jak w prawdziwym projekcie (/regent:init Krok 0.5), więc commit
# startowy ma sam kod i testy.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cp -R "$here/fixtures/notes-app/." .
git init -q -b main .
printf '/ai/\n' >> .git/info/exclude
git add -A
git -c user.name="Regent Eval" -c user.email=eval@example.invalid commit -qm "chore: projekt testowy notes-app"
