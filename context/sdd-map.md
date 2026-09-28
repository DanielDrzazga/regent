# Regent — mapa skilli i agentów SDD

> Reguły SDD: `context/sdd.md`.

## Wszystkie komendy

Skille poza `/regent:status` uruchamia wyłącznie użytkownik (`disable-model-invocation`). Gdy
przepływ prowadzi do kolejnego skilla (np. diagnoza → `/regent:bugfix`), podaj gotowe polecenie
do wpisania zamiast odtwarzać jego kroki.

| Komenda | Rola |
|---------|------|
| `/regent:init` | Inicjalizacja `ai/docs/` (stack, wzorce, konwencje) + Makefile |
| `/regent:propose` | Spec przed kodem (proposal, specs, design, tasks) |
| `/regent:apply` | Implementacja TDD (Red → Green → Refactor) |
| `/regent:verify` | 9-etapowa weryfikacja |
| `/regent:archive` | Merge delta specs → main, retrospektywa, przeniesienie do archiwum (`--abandon` — porzucenie) |
| `/regent:bugfix` | Naprawa buga w dev/staging (z testem regresji) |
| `/regent:hotfix` | Krytyczny fix na produkcji (max 30 min, 3 pliki) |
| `/regent:refactor` | Refactoring bez zmiany zachowania (INVARIANTS) |
| `/regent:revise` | Aktualizacja `ai/docs/` gdy podejście się zmienia |
| `/regent:logging` | Instrumentacja kodu logami wg `logging-patterns.md` |
| `/regent:testing` | Pisanie i weryfikacja testów |
| `/regent:code-review` | Peer review zmian |
| `/regent:commit` | Atomic commity wg git-workflow |
| `/regent:debugging` | Systematyczna diagnoza (fix przez `/regent:bugfix`) |
| `/regent:dependency-update` | Aktualizacja zależności i security patches |
| `/regent:status` | Przegląd stanu projektu |
| `/regent:explore` | Analiza read-only bez commitów |
| `/regent:wiki` | Wiki biznesowa w Obsidian (`ai/wiki/`) — poza cyklem SDD |

## Agenci (delegowani przez komendy)

`regent:architect`, `regent:spec-writer`, `regent:backend-dev`, `regent:frontend-dev`,
`regent:code-reviewer`, `regent:qa-engineer`, `regent:dba`, `regent:security-auditor`, `regent:logging-engineer`
— model per agent zdefiniowany w `agents/*.md` pluginu
(Opus dla design/security/review, Sonnet dla implementacji).

**Zasada delegacji (kluczowe!):** model agenta działa TYLKO, gdy komenda faktycznie
uruchomi go jako subagenta (narzędzie Task). Gdy komenda wskazuje agenta —
**deleguj do subagenta po pełnej nazwie `regent:<agent>`**, nie wykonuj jego pracy „w miejscu"
w głównej sesji (wtedy leci na modelu sesji, a nie na modelu agenta).

**Kontrakt subagenta:** subagent NIE może zablokować się w trakcie pracy i czekać
na odpowiedź użytkownika — działa do końca tury i zwraca raport. Bramki akceptacji
(pytania, zatwierdzenia) prowadzi sesja główna. Pętla pytań wygląda tak:

1. Subagent kończy turę raportem — niejasności w sekcji `OPEN QUESTIONS`.
2. Sesja główna zadaje pytania użytkownikowi.
3. Sesja główna **kontynuuje TEGO SAMEGO subagenta** (SendMessage / resume po
   `agentId`), przekazując odpowiedzi — agent zachowuje swój kontekst, bez
   re-delegacji od zera. Gdy kontynuacja niedostępna → re-delegacja z odpowiedziami
   w prompcie.

Subagent, który tworzy artefakty wymagające akceptacji, **zwraca ich treść w raporcie
końcowym** — pliki zapisuje sesja główna po akceptacji (lub kontynuowany subagent po
przekazaniu „zaakceptowano — zapisz").

| Komenda | Subagent(y) — pełna nazwa |
|---------|-------------------------------|
| `/regent:init` | `regent:architect` |
| `/regent:propose` | `regent:spec-writer` (+ `regent:architect` dla design.md) |
| `/regent:apply` | `regent:backend-dev` (taski `[BE]`/bez tagu) + `regent:frontend-dev` (taski `[FE]`) + `regent:dba` (taski `[DB]`) |
| `/regent:verify` | `regent:code-reviewer`, `regent:qa-engineer`, `regent:dba`, `regent:security-auditor` |
| `/regent:code-review` | `regent:code-reviewer` |
| `/regent:logging` | `regent:logging-engineer` |
| `/regent:testing` | `regent:qa-engineer` |
| `/regent:bugfix` | `regent:backend-dev` / `regent:frontend-dev` — wg obszaru buga |
| `/regent:hotfix` | `regent:backend-dev` / `regent:frontend-dev` — wg obszaru buga |
| `/regent:refactor` | `regent:backend-dev` / `regent:frontend-dev` wg obszaru (impl); `/regent:propose` i `/regent:verify` delegują same |
| `/regent:revise` | `regent:architect` (także `logging-patterns.md` — `regent:logging-engineer` przerywa przy braku wzorca) |
| `/regent:dependency-update` | `regent:security-auditor` (audyt) + `regent:backend-dev` / `regent:frontend-dev` wg pakietu (adaptacja kodu) |
| `/regent:debugging` | — (diagnoza w sesji głównej; fix przez handoff do `/regent:bugfix`) |
| `/regent:archive` | `regent:spec-writer` (tylko krok merge delta → main specs) |
| `/regent:explore` | `regent:architect` (read-only — analiza, bez plików/commitów) |
| `/regent:wiki` | `regent:architect` (analiza domeny + redakcja stron; zapis — sesja główna) |

Bez delegacji (mechaniczne, działają w głównej sesji): `/regent:commit`, `/regent:status`.
