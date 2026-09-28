# Regent — kontekst projektu

- Regent to narzędzie programisty łączące framework SDD i pomysły z OpenRig. Rozszerzenie na inne dziedziny („abstrakcja”) jest odłożone na później.
- Źródło prawdy o wizji: `~/_Private/regent-notes/vision.md` — poza repo, bo repo jest publiczne; tylko na Macu Daniela. Przed propozycją architektury lub zakresu przeczytaj sekcje 16–18 (MVP, napięcia, otwarte pytania); na maszynie bez tego pliku zapytaj.
- Punkty oznaczone w wizji jako `[delegowane]` rozstrzygają agenci analityczni — nie dopytuj o nie ponownie. Punkty `[interpretacja]` nie są ustaleniami.
- Repo nie pracuje w cyklu SDD (bez `ai/`). Zmiany idą lekką ścieżką: gałąź, plan z checklistą w `docs/plans/<nazwa>.md`, bramka `bash scripts/framework-lint.sh` + `claude plugin validate .` (jedyne dozwolone ostrzeżenie: brak `version`) i smoke. Mechanikę robi sesja główna, bez subagentów.
- Etap: plugin gotowy w repo (`plugin-import`, `plugin-hooks`, `retire-home-sdd` zakończone). Stary framework w `~/.claude` zostaje bez zmian — **nic w nim nie usuwaj** (decyzja 2026-09-28). Plugin nie jest nigdzie włączony i **nie trafia do żadnego marketplace do czasu ukończenia** — praca przez `claude --plugin-dir`.
- Komunikacja i dokumenty po polsku, z pełną polską ortografią. Identyfikatory i nazwy techniczne w oryginale.
