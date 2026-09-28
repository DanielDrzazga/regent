# Roadmapa i świadome decyzje

Zapis tego, **czego we frameworku nie ma i dlaczego**, pomysłów odłożonych na później i tego,
co z nich zrealizowano.
Po to, żeby przy nowym projekcie nie odkrywać tych decyzji od nowa — i żeby wiedzieć, jak
przywrócić coś, co zostało usunięte.

> Ten plik świadomie wymienia wycofane komendy i agentów, dlatego `framework-lint.sh` pomija go
> przy sprawdzaniu odwołań i wycofanych nazw.

## Świadomie poza frameworkiem

| Element | Status | Dlaczego | Ostatnia wersja |
|---------|--------|----------|-----------------|
| `/deploy-sdd`, agent `devops-engineer`, `templates/docs/deployment.md` | usunięte 2026-09-16 | Wdrożenie to proces organizacji i pipeline CI — framework go nie owija. Framework kończy się na `/regent:archive`; lokalną gotowość sprawdzają Etap 9 (Git & Release Readiness) i Etap 8 (Smoke) w `/regent:verify`. Przy osobistym `ai/` runbook wdrożenia w `ai/docs/` pasowałby jeszcze gorzej — to wiedza zespołu. | `39445f1` |
| `docs/audyt-prompt.md` | usunięty 2026-09-16 | Jednorazowe narzędzie robocze, nie dokumentacja; szybko się starzeje (opisywał 19 komend i cykl z discovery i deploy). Mechaniczną spójność sprawdza `scripts/framework-lint.sh`; przegląd z modelem — prompt spoza repo. | `39445f1` |
| `/discover-sdd`, agent `product-manager`, `templates/discovery-template.md` | poza rdzeniem | Potrzeba jest realna, ale stara forma kłóci się z frameworkiem: żywy backlog w `ai/product/` jest artefaktem zespołu, a `ai/` jest osobisty; wymagała powiązań statusów F-XX w `/regent:propose`, `/regent:archive` i `/regent:status`; osobny agent na Opusie. Potrzebę realizuje tryb `/regent:explore --discovery` (niżej, „Zrealizowane"); resztę pokrywają korzeń PROBLEM w Challenge i `/regent:wiki`. | `39445f1` |

**Przywrócenie** — hashe w tym pliku pochodzą z zamrożonego repo `claude-sdd-framework`
(Regent nie ma jego historii). W klonie tamtego repo plik wraca do working tree, potem
przenieś go do układu pluginu (`commands/<nazwa>-sdd.md` → `skills/<nazwa>/SKILL.md`):

```bash
git checkout 39445f1 -- commands/discover-sdd.md agents/product-manager.md templates/discovery-template.md
```

Po przywróceniu skilla dopisz go do tabel w `README.md` i `context/sdd.md` — inaczej
`framework-lint.sh` zgłosi błąd.

## Odłożone decyzje

| Pomysł | Decyzja | Kiedy wrócić | Źródło |
|--------|---------|--------------|--------|
| Lżejsza ścieżka dla zmian S — `/regent:propose` bez `regent:architect`, gdy zmiana nie ma nowego modułu, kontraktu ani DB | nie teraz (2026-09-23) — reguła „nie pomijaj kroków SDD, bo to mała zmiana"; Challenge i tak kończy się szybko przy S | retrospektywy pokażą, że architekt na Opusie przy S-kach to realny koszt | OpenSpec „Match the ceremony to the stakes", spec-kit `presets/lean` |

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
- Próba na sucho na TeronGo (wiedza sprzed budowy, wynik porównany z faktycznym przebiegiem):
  reguła „kandydat 1 sprawdza wartość albo odblokowuje resztę" dała na start tenant + zaproszenia
  + role — ten sam fundament, na którym projekt utknął, zanim pracownik terenowy dostał pierwszy
  ekran. Stąd „Kandydat 1 = walking skeleton" i fundament w minimalnym zakresie wewnątrz
  pierwszego kandydata (`require` w lincie).

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
