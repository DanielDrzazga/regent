#!/usr/bin/env bash
# framework-lint.sh — spójność pluginu Regent: frontmatter, odwołania, tabele, regresje.
#
# Plugin to prompty, więc „testem" jest spójność: każde odwołanie do skilla, agenta,
# szablonu i skryptu prowadzi do istniejącego pliku, tabele w context/sdd.md i README.md
# zgadzają się z skills/ i agents/, a naprawione błędy promptów nie wracają.
# Na końcu sprawdza składnię skryptów i uruchamia ich testy w /bin/bash (3.2) i w bashu z PATH.
#
# Użycie (w katalogu repo regent):  bash scripts/framework-lint.sh
# Kod wyjścia: 0 = brak ERROR, 1 = są ERROR.

set -u
cd "$(dirname "$0")/.." || exit 2

errors=0
warnings=0
err()  { echo "ERROR $*"; errors=$((errors + 1)); }
warn() { echo "WARN  $*"; warnings=$((warnings + 1)); }

# Poza lintem: reguły pracy nad repo (.claude/), wizja i plany zmian — opisują pliki, które
# dopiero powstaną, i dawne nazwy.
FILES=$(git ls-files --cached --others --exclude-standard -- '*.md' 2>/dev/null \
  | grep -vE '^(\.claude/|docs/vision\.md$|docs/plans/)')
[ -n "$FILES" ] || { echo "ERROR brak plików .md — uruchom w repo regent"; exit 2; }
# Dokumenty decyzji świadomie wymieniają wycofane komendy i usunięte pliki — sekcje 3, 4 i 6
# ich nie sprawdzają. Dopisuj tu tylko pliki-rejestry decyzji, nie zwykłą dokumentację.
DECISION_DOCS='^docs/roadmap\.md$'
REFS=$(echo "$FILES" | grep -vE "$DECISION_DOCS")

frontmatter() { awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1"; }

# --- 1. Agenci: frontmatter rozpoznawany przez Claude Code -------------------------------
for f in agents/*.md; do
  n=$(basename "$f" .md)
  fm=$(frontmatter "$f")
  echo "$fm" | grep -qx "name: $n"                                 || err "$f: pole name ≠ nazwa pliku ($n)"
  echo "$fm" | grep -qE '^model: (opus|sonnet|haiku|inherit)$'     || err "$f: brak poprawnego pola model"
  echo "$fm" | grep -qE '^tools: .+'                               || err "$f: brak pola tools"
  echo "$fm" | grep -qE '^description:'                            || err "$f: brak pola description"
done

# --- 2. Skille: frontmatter, nazwa bez sufiksu, nagłówek, uprawnienia --------------------
for f in skills/*/SKILL.md; do
  n=$(basename "$(dirname "$f")")
  fm=$(frontmatter "$f")
  case "$n" in *-sdd) err "$f: skill z sufiksem -sdd (namespace regent: zastępuje sufiks)" ;; esac
  echo "$fm" | grep -qE '^description: .+' || err "$f: brak description we frontmatterze"
  grep -qE "^# /regent:$n( |$)" "$f"        || err "$f: brak nagłówka '# /regent:$n'"
  tools=$(echo "$fm" | sed -n 's/^allowed-tools: //p')
  if [ -n "$tools" ]; then
    if grep -qE 'narzędziem Task|\(Task\)' "$f" && ! echo "$tools" | grep -qE '(^|, *)Task(,|$)'; then
      err "$f: deleguje przez Task, a allowed-tools nie zawiera Task"
    fi
    for t in AskUserQuestion SendMessage; do
      if grep -q "$t" "$f" && ! echo "$tools" | grep -qE "(^|, *)$t(,|$)"; then
        err "$f: używa $t, a allowed-tools go nie wymienia"
      fi
    done
    if grep -q 'sdd-check.sh' "$f" && ! echo "$tools" | grep -qE '(^|, *)Bash(,|$)|sdd-check\.sh'; then
      err "$f: woła sdd-check.sh, a allowed-tools tego nie dopuszcza"
    fi
  fi
done

# Agenci pluginu mają nazwę regent:<agent> — delegacja po gołej nazwie nie trafi do subagenta.
for a in agents/*.md; do
  n=$(basename "$a" .md)
  hits=$(grep -n "\`$n\`" skills/*/SKILL.md context/sdd.md 2>/dev/null)
  [ -z "$hits" ] || err "odwołanie do agenta $n bez prefiksu regent: — $hits"
done

# --- 3. Odwołania do skilli i agentów prowadzą do istniejących plików --------------------
refs=$(echo "$REFS" | xargs grep -ohE '/regent:[a-z]+(-[a-z]+)*' 2>/dev/null | sort -u)
for r in $refs; do
  [ -f "skills/${r#/regent:}/SKILL.md" ] || err "odwołanie do nieistniejącego skilla $r: $(echo "$REFS" | xargs grep -l -- "$r" | tr '\n' ' ')"
done
arefs=$(echo "$REFS" | xargs grep -ohE '(^|[^/a-z])regent:[a-z]+(-[a-z]+)*' 2>/dev/null \
  | sed -E 's/^[^r]*//' | sort -u)
for r in $arefs; do
  n=${r#regent:}
  [ -f "agents/$n.md" ] || [ -f "skills/$n/SKILL.md" ] || err "odwołanie do nieistniejącego agenta $r: $(echo "$REFS" | xargs grep -l -- "$r" | tr '\n' ' ')"
done

# --- 4. Odwołania do plików frameworka prowadzą do istniejących plików ---------------------
# Ścieżka ma zaczynać się od katalogu frameworka — `ai/docs/...` to pliki projektu, nie frameworka.
paths=$(echo "$REFS" | xargs grep -ohE '(^|[^A-Za-z0-9_./~-])(~/\.claude/|\$\{CLAUDE_PLUGIN_ROOT\}/)?(agents|skills|templates|scripts|docs|context)/[A-Za-z0-9_./-]+\.(md|sh|template)' 2>/dev/null \
  | sed -E 's#^[^A-Za-z~$]##; s#^~/\.claude/##; s#^\$\{CLAUDE_PLUGIN_ROOT\}/##' | sort -u)
for p in $paths; do
  [ -e "$p" ] || err "odwołanie do nieistniejącego pliku $p: $(echo "$REFS" | xargs grep -l -- "$p" | tr '\n' ' ')"
done

# --- 5. Tabele skilli i agentów zgodne z katalogami -----------------------------------------
for f in skills/*/SKILL.md; do
  n="/regent:$(basename "$(dirname "$f")")"
  for doc in context/sdd.md README.md; do
    grep -qE "^\| \`$n\` \|" "$doc" || err "$doc: brak $n w tabeli skilli"
  done
done
for f in agents/*.md; do
  n=$(basename "$f" .md)
  for doc in context/sdd.md README.md; do
    grep -q "\`regent:$n\`" "$doc" || err "$doc: brak agenta regent:$n"
  done
done
nc=$(ls skills/*/SKILL.md | wc -l | tr -d ' ')
na=$(ls agents/*.md | wc -l | tr -d ' ')
grep -qE "# $nc skilli" README.md     || err "README.md: drzewo repo podaje inną liczbę skilli niż $nc"
grep -qE "# $na subagentów" README.md || err "README.md: drzewo repo podaje inną liczbę agentów niż $na"
for s in scripts/*.sh; do
  grep -q "$s" docs/README.md || err "docs/README.md: brak skryptu $s w tabeli Skrypty"
done

# --- 6. Wycofane nazwy nie wracają ----------------------------------------------------------
# Dawne nazwy komend z sufiksem -sdd (przed pluginem) też są wycofane.
RETIRED='devops-engineer|templates/docs/deployment\.md|[a-z]+(-[a-z]+)*-sdd([^a-z-]|$)'
hits=$(echo "$REFS" | xargs grep -nE "$RETIRED" 2>/dev/null)
[ -z "$hits" ] || err "wycofana nazwa w treści: $hits"

# --- 7. Regresje: naprawione błędy promptów nie wracają ------------------------------------
# forbid <plik> <regex ERE> <powód> — wzorzec NIE może wystąpić
# require <plik> <regex ERE> <powód> — wzorzec MUSI wystąpić
forbid()  { ! grep -qE -- "$2" "$1" || err "$1: regresja — $3 (wzorzec: $2)"; }
require() {   grep -qE -- "$2" "$1" || err "$1: regresja — $3 (brak: $2)"; }

# (lista rośnie razem z poprawkami — dopisuj wpis w tym samym commicie co naprawę)
forbid  skills/archive/SKILL.md   'Zamień stare zachowanie na nowe|metodą append' "MODIFIED podmienia cały blok, nie fragment"
require templates/spec-template.md 'Usunięte AC'                               "MODIFIED jawnie wypisuje usuwane AC"
require agents/spec-writer.md      'pełny blok REQ'                            "spec-writer kopiuje cały blok REQ do MODIFIED"
forbid  templates/proposal-template.md '^## Acceptance Criteria'                "AC żyją tylko w delcie (jedno źródło AC)"
forbid  templates/user-story-template.md '^## Acceptance Criteria'              "AC żyją tylko w delcie (jedno źródło AC)"
forbid  skills/propose/SKILL.md        'rozwiązanie, AC \(Given-When-Then\)'   "AC żyją tylko w delcie (jedno źródło AC)"
forbid  agents/qa-engineer.md          'REQ-XXX-1'                              "jeden format ID: REQ-NNN/AC-n"
forbid  skills/propose/SKILL.md        '^## Tests$'                             "testy należą do swojego taska (horizontal slicing)"
require agents/spec-writer.md          'weryfikacja'                            "każdy task mówi, jak sprawdzić ukończenie"
require skills/propose/SKILL.md        'resume tego samego .regent:spec-writer.'       "tasks.md powstaje po design.md"
require templates/proposal-template.md '^## Decyzje i założenia'                "odpowiedzi z Challenge przeżywają sesję"
require skills/propose/SKILL.md        '□ LUKI'                                 "Challenge szuka luk w zachowaniu, nie tylko sensu zmiany"
require skills/propose/SKILL.md        '^## Krok 2\.5: Kontrola spójności'       "rozjazd artefaktów łapany przed kodem"
require skills/propose/SKILL.md        'Checklista recenzenta'                  "review Draft ma kolejność i kryteria"
require agents/spec-writer.md          '^## Samokontrola'                       "spec-writer sprawdza jakość speca przed raportem"
require agents/code-reviewer.md        'design\.md'                             "reviewer porównuje kod z design.md"
require agents/code-reviewer.md        'unrequested'                            "reviewer wykrywa kod spoza zakresu"
forbid  agents/code-reviewer.md        '^\| .partial. \|'                        "typ luki incomplete ≠ status ⚠️ PARTIAL"
require agents/spec-writer.md          'pierwsza specyfikacja istniejącego'      "brownfield: nieopisane zachowanie trafia do ADDED"
require skills/apply/SKILL.md          '^## Krok 4\.5: Zmiana kursu'            "odkrycie w trakcie apply aktualizuje plan za zgodą"
require agents/backend-dev.md          'ZAKRES:'                                "dev nie zawęża AC po cichu"
require agents/frontend-dev.md         'ZAKRES:'                                "dev nie zawęża AC po cichu"
require templates/design-template.md   '^## Odstępstwa od zasad'                "odstępstwo od MUST ma uzasadnienie"
require skills/bugfix/SKILL.md         'Odtwórz oryginalny symptom'             "bugfix potwierdza zniknięcie objawu, nie tylko zielone testy"
forbid  skills/verify/SKILL.md         'Happy path z AC-1'                      "AC-1 bez REQ jest niejednoznaczne — smoke z design.md"
require skills/archive/SKILL.md        'sdd-check.sh postmerge'                 "merge do main spec sprawdzany skryptem"
require skills/archive/SKILL.md        'sdd-check.sh preflight'                 "delta sprawdzana przed merge"
forbid  skills/archive/SKILL.md        'git diff --stat ai/specs'               "ai/ jest ignorowany — diff main specs z migawki"
forbid  skills/apply/SKILL.md          'git add ai/'                            "ai/ jest globalnie ignorowany — git add ścieżki w ai/ kończy się kodem 1"
forbid  skills/bugfix/SKILL.md         'git add .*ai/changes'                   "ai/ jest globalnie ignorowany"
forbid  agents/backend-dev.md          'testu zawiera ID AC'                    "numery REQ/AC są lokalne — nie trafiają do kodu"
forbid  agents/frontend-dev.md         'testu zawiera ID AC'                    "numery REQ/AC są lokalne — nie trafiają do kodu"
require skills/init/SKILL.md           'git check-ignore -q --no-index ai/'     "init sprawdza, że ai/ jest poza repo (także przy śledzonych plikach)"
forbid  skills/status/SKILL.md         'git rev-parse HEAD`\). Różnica'          "dryf po plikach zmiany, nie po hashu HEAD"
require skills/explore/SKILL.md        'Jeden kandydat = jedna zmiana SDD'      "discovery tnie inicjatywę na zmiany propose → archive"
require skills/explore/SKILL.md        'Kandydat 1 = walking skeleton'          "discovery zaczyna od przekroju end-to-end, nie od fundamentu"
forbid  skills/explore/SKILL.md        'ai/product'                             "discovery bez żywego backlogu w ai/ — kandydaci 2..N do trackera"

require docs/roadmap.md                 'git checkout 39445f1 --'                "rejestr decyzji podaje drogę przywrócenia usuniętych elementów"

# --- 8. Skrypty: składnia i testy w każdym dostępnym bashu ---------------------------------
# /bin/bash na macOS to 3.2 — bash z PATH bywa nowszy (Homebrew) i ukrywa błędy składni 3.2.
shells=$( { [ -x /bin/bash ] && echo /bin/bash; command -v bash; } | awk '!seen[$0]++')
for sh in $shells; do
  for f in scripts/*.sh scripts/hooks/*.sh; do
    [ -f "$f" ] || continue
    "$sh" -n "$f" 2>/dev/null || err "$f: błąd składni w $sh ($("$sh" -c 'echo $BASH_VERSION'))"
  done
  for t in scripts/tests/*.test.sh; do
    [ -f "$t" ] || continue
    res=$("$sh" "$t" 2>&1) || err "$t [$sh]: $(printf '%s\n' "$res" | tail -1)"
  done
done

echo "RESULT: $([ $errors -gt 0 ] && echo ERROR || { [ $warnings -gt 0 ] && echo WARN || echo OK; }) (errors=$errors warnings=$warnings)"
[ $errors -eq 0 ]
