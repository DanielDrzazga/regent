# Spec: notes

## Requirements

### REQ-001: Tworzenie notatki

**Given** użytkownik z tytułem i treścią
**When** tworzy notatkę
**Then** notatka zapisuje się z przyciętym tytułem

**Acceptance Criteria:**
- [x] AC-1: tytuł jest przycinany z białych znaków na początku i końcu
- [x] AC-2: tytuł pusty po przycięciu → `EmptyTitleError`

---

### REQ-002: Lista notatek

**Given** użytkownik z notatkami
**When** otwiera listę
**Then** widzi notatki od najnowszej

**Acceptance Criteria:**
- [x] AC-1: lista jest posortowana od najnowszej
