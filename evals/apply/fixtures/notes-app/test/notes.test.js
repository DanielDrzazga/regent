import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createNoteStore, EmptyTitleError } from '../src/notes.js';

const fixedClock = () => new Date('2026-10-01T10:00:00Z');

test('create trims the title', () => {
  const store = createNoteStore({ now: fixedClock });
  const note = store.create({ title: '  Zakupy  ' });
  assert.equal(note.title, 'Zakupy');
});

test('create rejects an empty title', () => {
  const store = createNoteStore({ now: fixedClock });
  assert.throws(() => store.create({ title: '' }), EmptyTitleError);
});

test('list returns notes from the newest', () => {
  const store = createNoteStore({ now: fixedClock });
  store.create({ title: 'Pierwsza' });
  store.create({ title: 'Druga' });
  assert.deepEqual(store.list().map((n) => n.title), ['Druga', 'Pierwsza']);
});

test('get returns null for a missing note', () => {
  const store = createNoteStore({ now: fixedClock });
  assert.equal(store.get(42), null);
});
