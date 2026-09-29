# Spec: notes — Delta dla note-tags

<!--
  Instrukcja z szablonu — nie jest treścią i nie trafia do paczki.
-->

## ADDED

### REQ-004: Tagi notatki

**Given** zalogowany użytkownik z notatką
**When** dodaje do niej tag
**Then** notatka ma ten tag, bez duplikatów

**Acceptance Criteria:**
- [ ] AC-1: tag zapisuje się małymi literami
- [ ] AC-2: ten sam tag drugi raz nie tworzy duplikatu
- [ ] AC-3: pusty tag → 400

**Notes:** tagi są osobne dla każdego użytkownika.

---

### REQ-005: Filtr po tagu

**Given** notatki z tagami
**When** użytkownik pyta o notatki z tagiem
**Then** dostaje tylko notatki z tym tagiem

**Acceptance Criteria:**
- [ ] AC-1: `GET /notes?tag=x` zwraca tylko notatki z tagiem x
- [ ] AC-2: kliknięcie tagu na liście filtruje listę

---

## MODIFIED

### REQ-002: Lista notatek

**Given** użytkownik z notatkami
**When** otwiera listę
**Then** widzi notatki od najnowszej, każdą z tagami

**Acceptance Criteria:**
- [ ] AC-1: lista jest posortowana od najnowszej (bez zmian)
- [ ] AC-2: każda notatka pokazuje swoje tagi

**Było:** lista bez tagów.
**Powód:** tagi muszą być widoczne tam, gdzie się po nich filtruje.

---

## INVARIANTS

- **INV-1:** notatki bez tagów czytają się i zapisują jak dotąd

---

## Notes

- Limit tagów na notatkę — poza zakresem.
