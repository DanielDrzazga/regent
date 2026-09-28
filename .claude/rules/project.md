# Regent — kontekst projektu

- Regent to narzędzie programisty łączące framework SDD i pomysły z OpenRig. Rozszerzenie na inne dziedziny („abstrakcja”) jest odłożone na później.
- Źródło prawdy o wizji: `docs/vision.md`. Przed propozycją architektury lub zakresu przeczytaj sekcje 16–18 (MVP, napięcia, otwarte pytania).
- Punkty oznaczone w `docs/vision.md` jako `[delegowane]` rozstrzygają agenci analityczni — nie dopytuj o nie ponownie. Punkty `[interpretacja]` nie są ustaleniami.
- Repo nie pracuje w cyklu SDD (bez `ai/`). Zmiany idą lekką ścieżką: gałąź, plan z checklistą w `docs/plans/<nazwa>.md`, bramka `bash scripts/framework-lint.sh` + `claude plugin validate .` (jedyne dozwolone ostrzeżenie: brak `version`) i smoke. Mechanikę robi sesja główna, bez subagentów.
- Etap: migracja frameworka SDD z `~/.claude` do pluginu w tym repo, w trzech zmianach: `plugin-import` → `plugin-hooks` → `retire-home-sdd`. Do końca `retire-home-sdd` stary framework w `~/.claude` zostaje nietknięty; jego usunięcie jest ostatnim krokiem.
- Komunikacja i dokumenty po polsku, z pełną polską ortografią. Identyfikatory i nazwy techniczne w oryginale.
