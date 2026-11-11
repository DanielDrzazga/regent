import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderResultCount } from '../web/result-count.js';

const text = (n) => renderResultCount(n).replace(/<[^>]+>/g, '');

test('result count is announced as status', () => {
  assert.match(renderResultCount(3), /^<p role="status">/);
});

test('result count uses Polish plural forms', () => {
  assert.equal(text(0), 'Brak wyników');
  assert.equal(text(1), '1 notatka');
  assert.equal(text(2), '2 notatki');
  assert.equal(text(5), '5 notatek');
  assert.equal(text(12), '12 notatek');
  assert.equal(text(22), '22 notatki');
});
