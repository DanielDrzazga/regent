# Plan: kolizje-numerow-req

> Lekka ścieżka na gałęzi `chore/usun-regent-watch` (decyzja użytkownika 2026-11-04: poprawka
> idzie razem z trybem współdzielonego `ai/`, który jeszcze nie jest na `main`).

## Problem

`next-req` liczy max numer REQ z drzewa roboczego (`ai/specs/`, aktywne zmiany, archiwum) + 1.
W trybie współdzielonym `ai/` dwie gałęzie odbite od tego samego `main` dostają ten sam numer.
`preflight` też patrzy tylko na drzewo robocze, więc kolizji nie widzi. Merge do `main` daje
konflikt tekstowy (ta sama domena, łatwo „rozwiązać” zostawiając oba bloki) albo cichy duplikat
(różne domeny). Na `main` nic nie sprawdza unikalności REQ między main specs.

Numery REQ nie trafiają do kodu (`spec-template.md`), więc przenumerowanie zmiany dotyka tylko
plików w `ai/changes/{nazwa}/`. To pozwala uznać numer z `/regent:propose` za roboczy, a ostatecznie
zatwierdzić go dopiero przy `/regent:archive`.

## Decyzje (2026-11-04)

| Decyzja | Wartość |
|---|---|
| Format ID | bez zmian (`REQ-NNN`) — ID z hashem/nazwą zmiany psują czytelność odwołań i parsery |
| `next-req` | dolicza numery z gałęzi lokalnych i zdalnych (`git grep` po refach, bez sieci); w trybie osobistym `ai/` nie jest w gicie, więc nic nie zmienia |
| `preflight` | ERROR: ADDED zajęty w `ai/specs/` gałęzi domyślnej (`origin/HEAD` → `main`); ERROR: duplikat REQ między main specs; WARN: ten sam numer ADDED w delcie innej gałęzi (przenumerowuje ten, kto archiwizuje drugi) |
| Przenumerowanie | nowy tryb `renumber <nazwa> <REQ-stary> [REQ-nowy]` — jedyny tryb, który zapisuje; podmienia numer w plikach zmiany, domyślnie na `next-req` |
| Sieć | skrypt nie robi `git fetch`; skille (`propose` Krok 2, `archive` Krok 0) robią go w trybie współdzielonym |
| Spec-writer | numer z promptu jest roboczy; ręczne liczenie Grepem usunięte (druga ścieżka liczenia = rozjazd) |

## Taski

- [x] T1: `sdd-check.sh` — `next-req` z refów, `preflight` wobec gałęzi domyślnej i innych gałęzi + duplikaty w main specs, tryb `renumber`
- [x] T2: testy w `scripts/tests/sdd-check.test.sh` (kolizja z `main`, z inną gałęzią, duplikat, renumber, next-req z refów)
- [x] T3: `agents/spec-writer.md`, `skills/propose/SKILL.md`, `skills/archive/SKILL.md`, `templates/spec-template.md`, `docs/sdd-check.md`
- [x] T4: bramka `bash scripts/framework-lint.sh` + `claude plugin validate .`

## Przebieg

- 2026-11-04: T1–T4 zrobione. Testy `sdd-check`: 147/147 (bash z PATH i `/bin/bash` 3.2), lint OK,
  `claude plugin validate .` — tylko ostrzeżenie o `version`.
- Smoke: dwa klony ze wspólnym `origin`. B po `git fetch` dostał numer o 1 wyższy od wypchniętej
  delty A (`next-req` z refów). Zmiana A niewypchnięta → ten sam numer (ograniczenie znane,
  nieusuwalne bez centralnego licznika). Po merge A do `main` `preflight` w B zgłosił
  `ERROR … jest już w origin/main:ai/specs/auth.md`, `renumber` przeniósł deltę i tasks na wolny
  numer, a ponowny preflight dał OK.
