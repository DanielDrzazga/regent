import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderNoteList, loadNoteList } from '../web/note-list.js';
import { createApiClient } from '../web/api-client.js';

const fakeFetch = (status, body) => async () => ({ ok: status < 400, status, json: async () => body });

test('note list shows notes in the given order', () => {
  const html = renderNoteList({ status: 'ready', notes: [{ id: 2, title: 'Druga' }, { id: 1, title: 'Pierwsza' }] });
  assert.ok(html.indexOf('Druga') < html.indexOf('Pierwsza'));
});

test('note list shows the empty, loading and error states', () => {
  assert.match(renderNoteList({ status: 'ready', notes: [] }), /Brak notatek/);
  assert.match(renderNoteList({ status: 'loading' }), /role="status"/);
  assert.match(renderNoteList({ status: 'error' }), /role="alert"/);
});

test('loading the list from the API gives ready or error state', async () => {
  const ok = await loadNoteList(createApiClient(fakeFetch(200, [{ id: 1, title: 'A' }])));
  assert.equal(ok.status, 'ready');
  const failed = await loadNoteList(createApiClient(fakeFetch(500, { error: 'boom' })));
  assert.equal(failed.status, 'error');
});
