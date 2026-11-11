// Magazyn notatek w pamięci. Jedna instancja na test albo na proces.

export class EmptyTitleError extends Error {
  constructor() {
    super('Tytuł notatki nie może być pusty');
    this.name = 'EmptyTitleError';
    this.code = 'EMPTY_TITLE';
  }
}

export function createNoteStore({ now = () => new Date() } = {}) {
  let nextId = 1;
  const notes = [];

  return {
    create({ title, body = '' }) {
      if (!title) throw new EmptyTitleError();
      const note = { id: nextId++, title: title.trim(), body, createdAt: now().toISOString() };
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
