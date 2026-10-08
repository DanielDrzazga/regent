export const id = '001_create_notes';

export function up(db) {
  db.tables.notes = [];
}

export function down(db) {
  delete db.tables.notes;
}
