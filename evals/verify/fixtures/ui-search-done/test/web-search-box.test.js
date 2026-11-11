import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderSearchBox, searchReducer } from '../web/search-box.js';

test('search box is a labelled search form with the current query', () => {
  const html = renderSearchBox({ query: 'zakupy' });
  assert.match(html, /<form role="search">/);
  assert.match(html, /<label for="q">Szukaj<\/label>/);
  assert.match(html, /id="q"[^>]*value="zakupy"/);
});

test('search box escapes the query', () => {
  assert.match(renderSearchBox({ query: '"><b>' }), /value="&quot;&gt;&lt;b&gt;"/);
});

test('typing sets the query and clearing empties it', () => {
  const typed = searchReducer({ query: '' }, { type: 'input', value: 'mleko' });
  assert.equal(typed.query, 'mleko');
  assert.equal(searchReducer(typed, { type: 'clear' }).query, '');
});
