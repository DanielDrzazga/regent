# Plan: retire-home-sdd

> Zmiana 3 z 3 migracji (`plugin-import` → `plugin-hooks` → `retire-home-sdd`). Lekka ścieżka:
> gałąź `feat/retire-home-sdd`, ten plan, bramka i smoke. Pierwsza zmiana, która dotyka globalnej
> konfiguracji — każdy krok usuwający coś spoza repo jest potwierdzany osobno przed wykonaniem.

## Cel

Framework SDD działa na tym Macu wyłącznie z pluginu `regent` (zakres `user`): stare SDD znika
z `~/.claude`, statusline idzie z danych pluginu, stare repo `claude-sdd-framework` jest
zamrożone z odnośnikiem, a dla pozostałych maszyn jest checklista.

## Decyzje (2026-09-28)

| Decyzja | Wartość |
|---|---|
| Ten Mac | mieszany — projekty prywatne i z pracy etatowej; plugin w zakresie `user` obejmie też projekty z pracy (tak jak dziś `~/.claude`) |
| Zamrożenie | commit z odnośnikiem w README starego repo, wypchnięty na GitHub i na firmowy GitLab; working tree `~/.claude` (niezacommitowany `statusline.sh`, nieśledzone `session-tokens.sh` i `docs/announcements/`) nie trafia do tego commita |
| Wywołanie skilli | 17 skilli z `disable-model-invocation: true` (opisy poza kontekstem, uruchamia tylko użytkownik); model może sam wywołać wyłącznie `/regent:status` |
| Atrybucja | `attribution.pr: ""` w `~/.claude/settings.json` — zakaz atrybucji obejmuje też opisy PR |
| Wizja | poza repo (repo jest publiczne): `~/_Private/regent-notes/vision.md`, tylko na tym Macu |

## Taski

W repo `regent` (gałąź):

- [x] T1: `disable-model-invocation: true` we frontmatterze 17 skilli (wszystkie poza `status`);
  lint: każdy skill poza `status` ma to pole; README i CONTRIBUTING — skille uruchamia użytkownik
- [x] T2: checklista „Nowa maszyna" w `docs/getting-started.md` — marketplace i plugin, `statusLine`,
  `attribution`, usunięcie starego SDD z `~/.claude`, `git config user.email` w klonie `regent`
- [x] T3: bramka (lint w obu bashach + `claude plugin validate .`), merge do `main`, push —
  instalacja w T6 bierze plugin z `main`

Na tym Macu (każdy krok usuwający — po potwierdzeniu):

- [x] T4: kopia zapasowa SDD z `~/.claude` do `~/_Private/regent-notes/claude-home-sdd-2026-09-28.tar.gz`:
  `agents/`, `commands/`, `templates/`, `scripts/`, `docs/` (z `announcements/`), `README.md`,
  `CONTRIBUTING.md`, `CLAUDE.md`, `.gitignore`, `.git/`
- [~] T5 (zmiana decyzji — niżej): zamrożenie `claude-sdd-framework` — w `~/.claude` commit tylko `README.md` z odnośnikiem
  do `github.com/DanielDrzazga/regent`; push na `github` i `origin` (GitLab)
- [~] T6 (zmiana decyzji — niżej): `claude plugin marketplace add DanielDrzazga/regent` + `claude plugin install regent@regent`
  (zakres `user`)
- [~] T7 (zmiana decyzji — niżej): `~/.claude/settings.json` — `statusLine.command` →
  `bash "$HOME/.claude/plugins/data/regent-regent/bin/statusline.sh"`, `attribution.pr: ""`
- [~] T8 (zmiana decyzji — niżej): usunięcie SDD z `~/.claude` — lista z T4; `~/.claude` przestaje być repo gita
  (bez `skills/`, `plugins/`, `projects/`, `settings.json` i reszty konfiguracji Claude Code)
- [~] T9 (zmiana decyzji — niżej): usunięcie starego wpisu git-guard z
  `~/PhpstormProjects/external-communication-service/.claude/settings.local.json` (plik lokalny, poza repo projektu)
- [~] T10 (zmiana decyzji — niżej): weryfikacja w nowych sesjach (`claude -p`, Haiku):
  - lista komend: są `regent:*`, nie ma `*-sdd`;
  - projekt SDD dostaje `role.md`, `sdd.md` i `sdd-map.md`; `~/.claude/CLAUDE.md` nie istnieje, więc bez duplikatów;
  - opisy 17 skilli poza kontekstem, `/regent:status` działa;
  - statusline z danych pluginu zwraca linię;
  - git-guard w repo `regent` (nowa sesja) blokuje `git add .`
- [x] T11: zamknięcie — plan, pamięć, reguła projektu (etap: migracja zakończona)

## Poza zakresem

Instalacja na Fedorze, TrueNAS i Windows (checklista z T2 — wykonuje użytkownik albo sesja na tamtej
maszynie), instalacja na PC firmowym (decyzja użytkownika i polityka firmy), synchronizacja wizji
między maszynami, pełne usunięcie starych commitów z GitHuba (usunięcie i ponowne założenie repo
albo zgłoszenie do GitHub Support — decyzja użytkownika).

## Ryzyka

- **Okno bez frameworka** — między T8 a działającym pluginem; dlatego T6 i T7 przed T8, a weryfikacja
  pluginu przed usunięciem.
- **Nieodwracalność T8** — kopia z T4; stare repo zostaje na GitHubie i GitLabie.
- **Bieżąca sesja** — ma w kontekście stary `CLAUDE.md` i komendy `-sdd` do końca; zmiany widać
  dopiero w nowej sesji.
- **Projekty z pracy na tym Macu** — dostają kontekst i git-guard z pluginu tak jak dziś z `~/.claude`;
  treść z tych projektów nie trafia do repo `regent` (`.claude/rules/privacy.md`).

## Przebieg (2026-09-28) — zmiana decyzji w trakcie

W trakcie T5 użytkownik zdecydował: **„nic nie usuwaj repo z SDD"**. Nowy stan docelowy:

- SDD w `~/.claude` zostaje bez zmian (pliki i `.git`) i dalej obsługuje codzienną pracę; statusline
  zostaje z `~/.claude/scripts/statusline.sh`; wpis git-guard w `external-communication-service`
  zostaje (wskazuje istniejący skrypt).
- Plugin **nie jest nigdzie włączony** ani deklarowany w marketplace; **do czasu ukończenia projekt
  nie pojawia się w żadnym marketplace** — `.claude-plugin/marketplace.json` usunięty z repo,
  instrukcje mówią o `claude --plugin-dir`.
- Commit z odnośnikiem „repo zamrożone" w starym repo cofnięty commitem `revert` (`4b45307`,
  wypchnięty na GitHub). Na firmowy GitLab nic nie trafiło (był nieosiągalny, a jego historia
  rozeszła się z `main` o 12 commitów — tam nigdy force-push).
- Wykonane: T1–T3 (17 skilli z `disable-model-invocation`, checklista), T4 (kopia zapasowa
  `~/_Private/regent-notes/claude-home-sdd-2026-09-28.tar.gz`), `attribution.pr: ""`
  w `~/.claude/settings.json`. Powstał też klon `~/_Private/claude-sdd-framework` (remote `github`
  i `gitlab`) — nieusuwany.
- Źródło prawdy dla dalszych zmian frameworka: **`regent`** (decyzja użytkownika). `~/.claude`
  zostaje bez zmian i nie dostaje nowych poprawek.

## Przebieg (2026-09-30) — Regent we wszystkich projektach na Macu

Użytkownik chce testować Regenta wszędzie, nie w jednym projekcie. T8 wraca w wersji odwracalnej:
przeniesienie zamiast usunięcia, bez marketplace.

- Kopia zapasowa: `~/_Private/regent-notes/claude-home-sdd-2026-09-30.tar.gz` (jak T4).
- `~/.claude/CLAUDE.md`, `commands/` (18 komend `-sdd`) i `agents/` (9 agentów) przeniesione do
  `~/.claude/sdd-wylaczone-2026-09-30/`. Zostają `scripts/` (statusline i wpis git-guard
  w `external-communication-service`), `templates/`, `docs/`, `.git` i `skills/` spoza SDD.
- Plugin we wszystkich sesjach z terminala: alias `claude --plugin-dir "$HOME/_Private/regent"`
  w `~/.zshrc`. Sesje spoza zsh (aplikacja desktopowa, IDE bez terminala) nie mają frameworka.
- Weryfikacja nowej sesji (`claude -p`, Haiku) w projekcie SDD: `-sdd` nie ma, widać `/regent:*`,
  „Twoja rola” raz, „Kontrakt `make`” z prefiksem `regent:`, bez `~/.claude/CLAUDE.md`; hook
  pluginu zapisał sync zadań (źródło `hook`).
- Do poprawy poza repo: projektowy `.claude/CLAUDE.md` w jednym projekcie prywatnym opisuje cykl
  starymi nazwami `/…-sdd`. Komendy i agenci projektowi nie wołają agentów po starych nazwach.
- Cofnięcie: przenieść trzy pozycje z powrotem do `~/.claude/` i usunąć alias.

## Przebieg (2026-10-03) — aplikacja desktop z lokalnego marketplace

Wieczorem 2026-09-30 plugin trafił też do aplikacji desktop: lokalny marketplace `regent` z katalogu
klonu (nieśledzony `.claude-plugin/marketplace.json`, plugin `source: "./"`), `regent@regent`
w zakresie `user`. Wyszło przy `apply-kontynuacje`: sesje desktop pracowały na kopii z `7bf627c`,
bez poprawki git-guard (`9b095d3`) i nowej reguły skilla `apply`.

- Decyzja użytkownika: lokalny marketplace zostaje, `marketplace.json` nie trafia do repo (publikacja
  dalej dopiero po ukończeniu). Reguła w `.claude/rules/project.md` i krok 6 w
  `docs/getting-started.md`: po merge'u do `main` `claude plugin marketplace update regent`
  i `claude plugin update regent@regent`.
- Wykonane: aktualizacja `7bf627c` → `e2ddcf7` (cache z `tools/regent/dist`). Nowa sesja desktop
  wzięła skill z `cache/regent/regent/e2ddcf72cc38`.
- Terminal: obie kopie są widoczne (`claude plugin list`: `regent@regent` i `regent@inline`), ale
  skille idą z klonu — sesja `cli` z 2026-10-03 wzięła je z `~/_Private/regent`. Hook „Twoja rola”
  w sesji terminalowej raz.
