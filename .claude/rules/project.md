# Regent — kontekst projektu

- Regent to narzędzie programisty: framework SDD (Spec-Driven Development) jako plugin Claude Code.
- Harness to warstwa runtime Regenta, nie osobny produkt: jedno repo, plugin to przepis SDD
  i adapter (hooki, statusline). Bez komponentów wymagających builda — plugin działa od razu po
  instalacji (`tools/` usunięte 2026-11-04, `docs/roadmap.md`).
- Repo nie pracuje w cyklu SDD (bez `ai/`). Zmiany idą lekką ścieżką: gałąź, plan z checklistą
  w `docs/plans/<nazwa>.md`, bramka `bash scripts/framework-lint.sh` + `claude plugin validate .`
  (jedyne dozwolone ostrzeżenie: brak `version`) i smoke. Mechanikę robi sesja główna, bez
  subagentów.
- Źródłem prawdy frameworka SDD jest to repo. Historia decyzji i zrealizowanych/odłożonych
  pomysłów: `docs/roadmap.md`; plany zmian z przebiegiem: `docs/plans/`.
- Komunikacja i dokumenty po polsku, z pełną polską ortografią. Identyfikatory i nazwy techniczne
  w oryginale.
