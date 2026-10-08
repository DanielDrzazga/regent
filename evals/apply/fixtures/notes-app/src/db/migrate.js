// Migracje: moduł z `id`, `up(db)` i `down(db)`. Kolejność wg listy w migrations/index.js.
export function migrateUp(db, migrations) {
  for (const m of migrations) {
    if (db.applied.includes(m.id)) continue;
    m.up(db);
    db.applied.push(m.id);
  }
}

export function migrateDown(db, migrations) {
  for (const m of [...migrations].reverse()) {
    if (!db.applied.includes(m.id)) continue;
    m.down(db);
    db.applied = db.applied.filter((id) => id !== m.id);
  }
}
