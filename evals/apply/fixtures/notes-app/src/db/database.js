// Baza w pamięci: tabele to tablice rekordów, `applied` to identyfikatory wykonanych migracji.
export function createDatabase() {
  return { tables: {}, applied: [] };
}
