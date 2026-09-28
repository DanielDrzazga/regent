# Plan: plugin-import

> Zmiana 1 z 3 migracji frameworka SDD z `~/.claude` do pluginu Claude Code w repo `regent`
> (`plugin-import` → `plugin-hooks` → `retire-home-sdd`). Lekka ścieżka: gałąź
> `feat/plugin-import`, ten plan, bramka i smoke. Mechanikę robi sesja główna, bez subagentów.

## Cel

Framework SDD działa jako plugin `regent` ładowany przez `claude --plugin-dir .` obok
nietkniętego `~/.claude`. Zachowanie skilli i agentów jest takie jak dziś — zmieniają się tylko
nazwy, ścieżki i miejsce plików.

## Decyzje (2026-09-28)

| Decyzja | Wartość |
|---|---|
| Źródło | stan roboczy `~/.claude` (repo `claude-sdd-framework`, HEAD `661da82` + niezacommitowany `statusline.sh` + nieśledzony `session-tokens.sh`); bez `docs/announcements/` (ogłoszenie dla zespołu w pracy) |
| Historia gita | bez historii — kopia plików; stare repo zostaje zamrożone na `661da82` |
| Klucze w przykładach | `CAP-1028` / `1029` / `1030` → `PROJ-123` / `124` / `125` |
| Komendy | → skille `skills/<nazwa>/SKILL.md`, bez sufiksu `-sdd` → `/regent:<nazwa>` |
| Agenci | bez zmian w plikach; w odwołaniach pełna nazwa `regent:<agent>` |
| Reguły SDD z `CLAUDE.md` | → `context/sdd.md` (wstrzykiwany przez hook w zmianie 2, tylko przy `ai/docs/`) |
| „Twoja rola" | → `context/role.md` (wstrzykiwany przez hook w zmianie 2, zawsze) |
| Bramka | `bash scripts/framework-lint.sh` (w nim testy w obu bashach) + `claude plugin validate --strict .` |

## Układ docelowy

```
.claude-plugin/plugin.json        # manifest: name regent, version 0.1.0
.claude-plugin/marketplace.json   # marketplace regent, plugin source "./"
skills/<nazwa>/SKILL.md           # 18 ← ~/.claude/commands/<nazwa>-sdd.md
agents/*.md                       # 9  ← ~/.claude/agents/
templates/ (+ templates/docs/)    # 19 ← ~/.claude/templates/
scripts/ (+ hooks/, tests/)       # ← ~/.claude/scripts/ (z session-tokens.sh)
context/sdd.md, context/role.md   # ← ~/.claude/CLAUDE.md (podział)
docs/                             # ← ~/.claude/docs/ (bez announcements) + vision.md, plans/
README.md, CONTRIBUTING.md        # ← ~/.claude/
```

Nazwy skilli: `apply`, `archive`, `bugfix`, `code-review`, `commit`, `debugging`,
`dependency-update`, `explore`, `hotfix`, `init`, `logging`, `propose`, `refactor`, `revise`,
`status`, `testing`, `verify`, `wiki`. `init`, `status` i `code-review` kolidują z wbudowanymi
komendami — działają tylko jako `/regent:<nazwa>`, dlatego w treści zawsze pełna forma.

## Podmiany (jeden skrypt, te same reguły dla importu i dla kontroli parytetu)

| # | Z | Na | Uwagi |
|---|---|---|---|
| 1 | `/<nazwa>-sdd` (18 nazw z listy) | `/regent:<nazwa>` | ok. 585 wystąpień; wycofane `/deploy-sdd`, `/discover-sdd` w `docs/roadmap.md` zostają (rejestr decyzji) |
| 2 | `commands/<nazwa>-sdd.md` | `skills/<nazwa>/SKILL.md` | |
| 3 | `` `<agent>` `` (9 nazw) | `` `regent:<agent>` `` | ok. 180 wystąpień; kontrola kontekstów, gdzie chodzi o pole `name`, a nie o delegację |
| 4 | `~/.claude/templates/`, `~/.claude/scripts/` | `${CLAUDE_PLUGIN_ROOT}/templates/`, `${CLAUDE_PLUGIN_ROOT}/scripts/` | w treści skilli, agentów i w `allowed-tools` — dokumentacja CC potwierdza podstawianie |
| 5 | `CAP-1028` / `1029` / `1030` | `PROJ-123` / `124` / `125` | |

Ręcznie: 4 wystąpienia nazwy bez ukośnika, sekcja „Konwencja nazw: sufiks `-sdd`" (→ namespace
`regent:`), nagłówek zakresu w `context/sdd.md`, komentarze „Użycie:" w skryptach, README (drzewo,
instalacja pluginu). Poza zakresem tej zmiany: wpis hooka git-guard w `init` Krok 3.5 (`$HOME/.claude/…`)
— przepisuje go zmiana 2.

## Taski

- [ ] T1: import plików ze źródła (bez historii, bez `docs/announcements/`, bez `.gitignore` starego repo)
- [ ] T2: `commands/<nazwa>-sdd.md` → `skills/<nazwa>/SKILL.md`; `CLAUDE.md` → `context/sdd.md` + `context/role.md`
- [ ] T3: podmiany 1–5 skryptem (`scripts/migrate-names.sh` w scratchpadzie, nie w repo) + edycje ręczne
- [ ] T4: `framework-lint.sh` pod układ pluginu:
  - `FILES` bez `.claude/`, `docs/vision.md`, `docs/plans/`;
  - §2 po `skills/*/SKILL.md` — zakaz sufiksu `-sdd`, nagłówek `# /regent:<nazwa>`;
  - §3 `/regent:<nazwa>` → istniejący `skills/<nazwa>/SKILL.md`;
  - §4 ścieżki także z `${CLAUDE_PLUGIN_ROOT}/` i `skills/`;
  - §5 tabele w `context/sdd.md` i `README.md`, liczba skilli;
  - §6 dawne nazwy `/<nazwa>-sdd` na liście wycofanych (poza `docs/roadmap.md`);
  - §7 ścieżki `commands/…-sdd.md` → `skills/…/SKILL.md`;
  - nowa reguła: skille nie odwołują się do agenta bez prefiksu `regent:`
- [ ] T5: `.claude-plugin/plugin.json` i `.claude-plugin/marketplace.json`
- [ ] T6: README, CONTRIBUTING, `docs/`: instalacja (`/plugin marketplace add DanielDrzazga/regent`,
  `/plugin install regent@regent`, dev: `claude --plugin-dir .`), drzewo repo, wiersz dla `vision.md`
- [ ] T7: bramka zielona — `bash scripts/framework-lint.sh` w obu bashach (git-guard 28/28,
  sdd-check 124/124) i `claude plugin validate --strict .`
- [ ] T8: parytet — ten sam skrypt podmian na kopii źródła w `mktemp -d`, `diff -r` z repo:
  różnice tylko w edycjach ręcznych wymienionych wyżej
- [ ] T9: smoke w pustym repo testowym:
  - `/regent:status` przez `claude -p … --plugin-dir` (skill ładuje się, `sdd-check.sh` rusza przez `${CLAUDE_PLUGIN_ROOT}`);
  - lista agentów zawiera 9 × `regent:<agent>`;
  - jedna delegacja do `regent:<agent>` — tylko za zgodą (agent na Opusie kosztuje)
- [ ] T10: merge `feat/plugin-import` → `main`, push

## Poza zakresem (zmiany 2 i 3)

Hooki pluginu (git-guard, SessionStart z `context/`), statusline (błąd `stat -f` na GNU,
rejestracja poza pluginem), integracja `session-tokens.sh`, decyzja o `disable-model-invocation`,
instalacja na Fedorze, usunięcie SDD z `~/.claude`, sprzątanie wpisów git-guard w projektach,
zamrożenie `claude-sdd-framework`, usunięcie lokalnego `.claude/settings.local.json`.

## Ryzyka

- **Podmiana nazw agentów w złym kontekście** (np. opis pola `name`) — T8 pokazuje każdą różnicę.
- **Rozjazd tabel i odwołań** — pilnuje go lint (§3–§5) i nowa reguła prefiksu agentów.
- **Budowanie Regenta samym sobą** — do końca zmiany 3 prace prowadzi stary framework z `~/.claude`;
  plugin w tej zmianie nie jest instalowany globalnie, więc nie dubluje kontekstu w innych sesjach.
- **Stan źródła się zmieni w trakcie** — import robiony raz, z zapisanym `HEAD` i listą plików.
