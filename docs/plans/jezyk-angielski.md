# Plan: jezyk-angielski

> Lekka ścieżka: gałąź `feat/jezyk-angielski`, ten plan, bramka i smoke.

## Cel

Regent jest optymalizowany pod całą firmę: agenci piszą wszystko po angielsku (kod, dokumenty,
raporty, commity). Wyjątek: rozmowa z użytkownikiem — w języku, w którym ją zaczął.

## Decyzje (2026-11-04)

| Decyzja | Wartość |
|---|---|
| Miejsce reguły | `context/role.md` — wstrzykiwany zawsze, sesji głównej i każdemu subagentowi |
| Zakres etapu 1 | tylko reguła ogólna + usunięcie sprzecznych „po polsku" z agentów i `/regent:wiki`; skille i szablony zostają po polsku |
| Nagłówki i znaczniki | przepisywane dosłownie z szablonów — czytają je `sdd-check.sh` i `tools/regent` (`BASE_SECTIONS` w `packet.ts`, `BRAK W PACZCE`) |
| Wyjątki | brak — także `/regent:optimize` i projekty z regułami po polsku; jedyny wyjątek przejściowy to dosłowne nagłówki i znaczniki czytane przez skrypty |
| Etap 2 | pełne tłumaczenie skilli, szablonów, agentów i nagłówków razem ze skryptami — `docs/roadmap.md`, „Odłożone decyzje" |

## Taski

- [x] T1: sekcja `## Język` w `context/role.md`
- [x] T2: linia językowa 8 agentów → odwołanie do reguły
- [x] T3: `/regent:wiki` — język treści i nazw plików: angielski
- [x] T3b: `/regent:optimize` — opis commita po angielsku; reguła bez pierwszeństwa projektu
- [x] T4: lint — `require context/role.md '^## Język'`
- [x] T5: wpis w `docs/roadmap.md` (etap 2)
- [x] T6: bramka (`framework-lint.sh`, `claude plugin validate .`) i smoke (wstrzyknięcie `role.md`)
