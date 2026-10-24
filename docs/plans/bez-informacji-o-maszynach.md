# Plan: bez-informacji-o-maszynach

> Lekka ścieżka: gałąź `docs/bez-informacji-o-maszynach`, ten plan, bramka.

## Cel

Optymalizacja Regenta idzie na wielu komputerach, systemach i w chmurze. Reguły i plany nie
wskazują więc konkretnej maszyny, na której pracuje sesja, i nie każą agentowi tego zapisywać.

## Taski

- [x] T1: `.claude/rules/project.md` — wizja „nie w każdym środowisku”, ładowanie pluginu zależne
  od środowiska (odnośnik do checklisty), zakaz zakładania i zapisywania konkretnej maszyny.
- [x] T2: `.claude/rules/privacy.md` — prywatne serwery i sprzęt firmowy bez nazw urządzeń.
- [x] T3: plany w `docs/plans/` — nazwy maszyn zastąpione opisem („maszyna mieszana”,
  „pozostałe maszyny”, „lokalnie”).
- [x] T4: bramka: `bash scripts/framework-lint.sh` + `claude plugin validate .`.

## Poza zakresem

Uwagi o zgodności (bash 3.2 na macOS, awk na różnych dystrybucjach, Windows Terminal,
`bubblewrap` na Linuksie) zostają — to wymagania przenośności, nie opis maszyny sesji.
