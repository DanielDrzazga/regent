import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabase } from '../src/db/database.js';
import { migrateUp, migrateDown } from '../src/db/migrate.js';
import { migrations } from '../migrations/index.js';

test('migrations go up, down and up again', () => {
  const db = createDatabase();
  migrateUp(db, migrations);
  assert.deepEqual(db.tables.notes, []);
  migrateDown(db, migrations);
  assert.equal(db.tables.notes, undefined);
  assert.deepEqual(db.applied, []);
  migrateUp(db, migrations);
  assert.deepEqual(db.applied, migrations.map((m) => m.id));
});
