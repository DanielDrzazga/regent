// Magazyn notatek w pamięci. Jedna instancja na test albo na proces.

export const MAX_TITLE_LENGTH = 80;

export class EmptyTitleError extends Error {
  constructor() {
    super('Tytuł notatki nie może być pusty');
    this.name = 'EmptyTitleError';
    this.code = 'EMPTY_TITLE';
  }
}

export class TitleTooLongError extends Error {
  constructor() {
    super(`Tytuł notatki może mieć najwyżej ${MAX_TITLE_LENGTH} znaków`);
    this.name = 'TitleTooLongError';
    this.code = 'TITLE_TOO_LONG';
  }
}

export function createNoteStore({ now = () => new Date() } = {}) {
  let nextId = 1;
  const notes = [];

  return {
    create({ title, body = '' }) {
      const trimmed = (title ?? '').trim();
      if (!trimmed) throw new EmptyTitleError();
      if (trimmed.length > MAX_TITLE_LENGTH) throw new TitleTooLongError();
      const note = { id: nextId++, title: trimmed, body, createdAt: now().toISOString() };
      notes.push(note);
      return { ...note };
    },

    get(id) {
      const note = notes.find((n) => n.id === id);
      return note ? { ...note } : null;
    },

    // Od najnowszej (REQ-002).
    list() {
      return notes.map((n) => ({ ...n })).reverse();
    },
  };
}
