// Lista notatek: stan { status: 'loading' | 'error' | 'ready', notes }.
import { escapeHtml } from './html.js';

export function renderNoteList({ status, notes = [] }) {
  if (status === 'loading') return '<p role="status">Wczytywanie…</p>';
  if (status === 'error') return '<p role="alert">Nie udało się wczytać notatek</p>';
  if (notes.length === 0) return '<p>Brak notatek</p>';
  const items = notes.map((n) => `<li data-id="${n.id}">${n.title}</li>`).join('');
  return `<ul aria-label="Notatki">${items}</ul>`;
}

export async function loadNoteList(api) {
  try {
    return { status: 'ready', notes: await api.listNotes() };
  } catch {
    return { status: 'error', notes: [] };
  }
}
