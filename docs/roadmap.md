# Roadmapa i świadome decyzje

Zapis tego, **czego we frameworku nie ma i dlaczego**, pomysłów odłożonych na później i tego,
co z nich zrealizowano — po to, żeby przy nowym projekcie nie odkrywać tych decyzji od nowa.

> Ten plik świadomie wymienia wycofane komendy i agentów, dlatego `framework-lint.sh` pomija go
> przy sprawdzaniu odwołań i wycofanych nazw.

## Świadomie poza frameworkiem

| Element | Status | Dlaczego |
|---------|--------|----------|
| `/deploy-sdd`, agent `devops-engineer`, `templates/docs/deployment.md` | usunięte 2026-09-16 | Wdrożenie to proces organizacji i pipeline CI — framework go nie owija. Framework kończy się na `/regent:archive`; lokalną gotowość sprawdzają Etap 9 (Git & Release Readiness) i Etap 8 (Smoke) w `/regent:verify`. |
| `docs/audyt-prompt.md` | usunięty 2026-09-16 | Jednorazowe narzędzie robocze, nie dokumentacja; szybko się starzeje. Mechaniczną spójność sprawdza `scripts/framework-lint.sh`. |
| `/discover-sdd`, agent `product-manager`, `templates/discovery-template.md` | poza rdzeniem | Potrzeba jest realna, ale stara forma kłóci się z frameworkiem: żywy backlog w `ai/product/` wymagał powiązań statusów F-XX w `/regent:propose`, `/regent:archive` i `/regent:status` i osobnego agenta na Opusie. Potrzebę realizuje tryb `/regent:explore --discovery` (niżej, „Zrealizowane"); resztę pokrywają korzeń PROBLEM w Challenge i `/regent:wiki`. |
| Task CLI with a SQLite store, an `apply` packet, a TUI for agent sessions | removed 2026-11-04 | Each needed Node and a manual build — after installing the plugin they worked for nobody but the author. The task trace already lives in `tasks.md` and `sdd-check.sh status` computes the state. If it comes back — as a bash script with no build step. |
| `/regent:optimize` (skill optimisation loop over `claude plugin eval` suites) | removed 2026-11-04 | The eval suites were maintained by one person and are out of scope for the company harness; without them the skill has nothing to run. |

## Odłożone decyzje

| Pomysł | Decyzja | Kiedy wrócić | Źródło |
|--------|---------|--------------|--------|
| Lżejsza ścieżka dla zmian S — `/regent:propose` bez `regent:architect`, gdy zmiana nie ma nowego modułu, kontraktu ani DB | nie teraz (2026-09-23) — reguła „nie pomijaj kroków SDD, bo to mała zmiana"; Challenge i tak kończy się szybko przy S | retrospektywy pokażą, że architekt na Opusie przy S-kach to realny koszt | OpenSpec „Match the ceremony to the stakes", spec-kit `presets/lean` |
| Plugin publication in a remote marketplace (marketplace added by URL, `version` and the update channel) | not now (2026-11-04) — the plugin installs from a local marketplace in the clone (`Makefile`, targets `plugin-*`) | after researching how the company distributes Claude Code plugins | — |
| Pełne tłumaczenie skilli, szablonów i agentów na angielski (ze znacznikami czytanymi przez `sdd-check.sh`) | etap 2 (2026-11-04) — na razie tylko reguła „Język" w `context/role.md` z wyjątkiem przejściowym dla nagłówków i znaczników | one change: templates + scripts + tests + lint together | — |

## Zrealizowane

Pomysły, które weszły do frameworka. Działanie opisuje plik komendy — tu zostaje to, czego plik
nie mówi: co wzięliśmy, czego świadomie nie i czego nauczyła próba.

| Pomysł | Realizacja | Kiedy |
|--------|------------|-------|
| Discovery dla nowych projektów | tryb `/regent:explore --discovery` — `skills/explore/SKILL.md`, sekcja „Tryb `--discovery`" | 2026-09-24 |

**Discovery — decyzje:**
- Ze starego `/discover-sdd`: pytania wywiadu, „jeden kandydat = jedna zmiana SDD", cięcie MVP,
  bez finansów, werdykt z uzasadnieniem (`BUDUJEMY` / `DOPRECYZUJ` / `NIE BUDUJEMY` zamiast
  GO / PIVOT / NO-GO).
- Bez `ai/product/` z żywym backlogiem, statusów F-XX i agenta `product-manager`: explore zostaje
  read-only, kandydaci 2..N idą do trackera za zgodą (pilnuje `forbid 'ai/product'` w lincie).
- Inspiracja: spec-kit `extensions/assess` — esencja (rozbicie + werdykt), nie pięć artefaktów.
- „Kandydat 1 = walking skeleton": a first candidate that only builds the foundation (tenants,
  invitations, roles) delays the first screen a user can check, so the foundation goes inside the
  first candidate in its minimal scope (`require` w lincie).

## Czego świadomie nie bierzemy z OpenSpec i spec-kit

Wynik analizy z 2026-09-23 (trzy niezależne podejścia, zgodne co do poniższych):

- **CLI z kontraktem JSON, silnik workflow w YAML, konfigurowalny DAG artefaktów** — runtime to
  Claude Code, a stan zmiany da się odczytać z plików; to, co warto policzyć, liczy `sdd-check.sh`.
- **Integracje z 30+ narzędziami, extensions / presets / bundles / katalogi** — framework działa
  tylko w Claude Code; boilerplate hooków w każdej komendzie spec-kit kosztuje tokeny.
- **Filozofia „bez bramek" OpenSpec** — `Draft → Approved` i `Verdict: PASS` to wartość rdzeniowa;
  wzięliśmy tylko mechanizm zmiany kursu (AMEND za zgodą).
- **„Tests are OPTIONAL" (spec-kit) i auto-commit po komendzie** — sprzeczne z TDD i commitem po GREEN.
- **Pełna konstytucja z wersjonowaniem, pełny assess, multi-repo stores/worksets** — ceremonia
  ponad potrzebę; wzięliśmy „Zasady nienegocjowalne (MUST)" w `architecture.md`.
- **Clarify „jedno pytanie na turę"** — rundy frontiera w Challenge są tańsze w turach.
- **SHALL/MUST jako wymóg walidatora** — polskie Given-When-Then jest testowalne bez tego.
