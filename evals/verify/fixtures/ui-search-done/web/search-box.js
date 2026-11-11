// Pole wyszukiwania (REQ-050): render i reducer frazy.
import { escapeHtml } from './html.js';

export function renderSearchBox({ query = '' }) {
  return `<form role="search"><label for="q">Szukaj</label><input id="q" name="q" type="search" value="${escapeHtml(query)}"></form>`;
}

export function searchReducer(state, action) {
  switch (action.type) {
    case 'input':
      return { ...state, query: action.value };
    case 'clear':
      return { ...state, query: '' };
    default:
      return state;
  }
}
