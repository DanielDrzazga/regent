#!/usr/bin/env bash
# Testy scripts/code-map-compare.sh — bez prawdziwego evala: `claude` na PATH to stub, który wg
# --tag kopiuje gotowy JSON wyniku do --json. Sprawdza przekazywanie opcji do optimize-score.sh
# run/decide, linię różnic i kod wyjścia werdyktu.
# Użycie: bash scripts/tests/code-map-compare.test.sh      (kod wyjścia 0 = wszystkie zielone)

set -u
if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP code-map-compare.sh: brak jq"
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../code-map-compare.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/code-map-compare.XXXXXX")
trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL [$name] $1"; printf '%s\n' "out: $out" | sed 's/^/    /'; }

mkdir -p "$T/plugin/evals" "$T/bin"

# JSON-y wyniku: bez grafu — droższy; z grafem — taniej, ta sama jakość. Ta sama nazwa przypadku
# (po prefiksie do pierwszego „-") — tak jak w prawdziwych parach case.yaml (różny tag, ta sama
# scena) — inaczej `optimize-score.sh decide` zgłasza fałszywy spadek z 1.00 (różne nazwy).
cat > "$T/bez.json" <<'EOF'
{"cases":[{"name":"x-impact","arms":{"with":[
  {"score":1,"costUsd":1.0,"durationSeconds":100,"graders":[{"name":"g","passed":true}]}]}}]}
EOF
cat > "$T/z.json" <<'EOF'
{"cases":[{"name":"x-impact","arms":{"with":[
  {"score":1,"costUsd":0.6,"durationSeconds":80,"graders":[{"name":"g","passed":true}]}]}}]}
EOF

# Stub `claude`: wg --tag kopiuje gotowy JSON do --json. Zapisuje otrzymane argumenty, by
# sprawdzić przekazanie --runs/--budget/-j/--no-bash.
cat > "$T/bin/claude" <<EOF
#!/usr/bin/env bash
set -eu
tag=""; out=""
echo "\$*" >> "$T/calls.log"
while [ \$# -gt 0 ]; do
  case "\$1" in
    --tag) tag=\$2; shift 2 ;;
    --json) out=\$2; shift 2 ;;
    *) shift ;;
  esac
done
case "\$tag" in
  demo-bez) cp "$T/bez.json" "\$out" ;;
  demo-z) cp "$T/z.json" "\$out" ;;
  *) echo "stub claude: nieznany tag \$tag" >&2; exit 1 ;;
esac
EOF
chmod +x "$T/bin/claude"
PATH="$T/bin:$PATH"
export PATH

name="porównanie: dwie linie, różnice, keep (koszt niżej)"
out=$(bash "$SCRIPT" "$T/plugin" demo-bez demo-z "$T/out" --runs 2 --budget 5 2>&1); code=$?
case "$out" in *"bez grafu:  quality=1"*) ok ;; *) ko "linia bez grafu" ;; esac
case "$out" in *"z grafem:   quality=1"*) ok ;; *) ko "linia z grafem" ;; esac
case "$out" in *"różnica cost: 1 → 0.6"*) ok ;; *) ko "różnica cost" ;; esac
case "$out" in *"keep: koszt"*) ok ;; *) ko "werdykt keep" ;; esac
if [ "$code" -eq 0 ]; then ok; else ko "kod $code"; fi

name="opcje --runs/--budget przekazane obu przebiegom (optimize-score.sh tłumaczy na claude)"
n=$(grep -c -- '--runs 2' "$T/calls.log"); [ "$n" -eq 2 ] && ok || ko "--runs widoczne $n razy"
n=$(grep -c -- '--max-cost-usd 5' "$T/calls.log"); [ "$n" -eq 2 ] && ok || ko "--max-cost-usd widoczne $n razy"

name="--no-bash: ostrzeżenie na stderr, --disallow-tools Bash przekazane obu przebiegom"
: > "$T/calls.log"
err=$(bash "$SCRIPT" "$T/plugin" demo-bez demo-z "$T/out2" --no-bash 2>&1 >/dev/null)
case "$err" in *"graf nie zadziała"*) ok ;; *) ko "brak ostrzeżenia" ;; esac
n=$(grep -c -- '--disallow-tools Bash' "$T/calls.log"); [ "$n" -eq 2 ] && ok || ko "--disallow-tools Bash widoczne $n razy"

name="discard: jakość z grafem niżej"
cat > "$T/z-slabsze.json" <<'EOF'
{"cases":[{"name":"x-impact","arms":{"with":[
  {"score":0.5,"costUsd":0.6,"durationSeconds":80,"graders":[{"name":"g","passed":false}]}]}}]}
EOF
sed -i'' -e "s#demo-z) cp \"$T/z.json\"#demo-z) cp \"$T/z-slabsze.json\"#" "$T/bin/claude" 2>/dev/null \
  || sed -i "s#demo-z) cp \"$T/z.json\"#demo-z) cp \"$T/z-slabsze.json\"#" "$T/bin/claude"
out=$(bash "$SCRIPT" "$T/plugin" demo-bez demo-z "$T/out3" 2>&1); code=$?
case "$out" in *"discard: jakość"*) ok ;; *) ko "werdykt discard" ;; esac
if [ "$code" -eq 1 ]; then ok; else ko "kod $code"; fi

name="błędne użycie → kod 2"
out=$(bash "$SCRIPT" "$T/plugin" tylko-jeden-tag 2>&1); code=$?
if [ "$code" -eq 2 ]; then ok; else ko "kod $code"; fi

echo "code-map-compare.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
