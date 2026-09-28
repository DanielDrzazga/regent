# Regent — kontekst projektu

- Regent to narzędzie programisty łączące framework SDD i pomysły z OpenRig. Rozszerzenie na inne dziedziny („abstrakcja”) jest odłożone na później.
- Źródło prawdy o wizji: `docs/vision.md`. Przed propozycją architektury lub zakresu przeczytaj sekcje 16–18 (MVP, napięcia, otwarte pytania).
- Punkty oznaczone w `docs/vision.md` jako `[delegowane]` rozstrzygają agenci analityczni — nie dopytuj o nie ponownie. Punkty `[interpretacja]` nie są ustaleniami.
- Wiedza o projekcie (stack, wzorce, konwencje, słownik): `ai/docs/` — projekt pracuje w cyklu SDD.
- Etap: migracja frameworka SDD z `~/.claude` do pluginu w tym repo, w trzech zmianach:
  `plugin-import` → `plugin-hooks` → `retire-home-sdd`. Do końca `retire-home-sdd` cykle prowadzi
  stary framework z `~/.claude`; usunięcie SDD z `~/.claude` jest ostatnim krokiem.
- Komunikacja i dokumenty po polsku, z pełną polską ortografią. Identyfikatory i nazwy techniczne w oryginale.
