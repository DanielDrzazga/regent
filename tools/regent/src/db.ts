// Warstwa bazy — jedyny plik z node:sqlite. Silnik jest eksperymentalny w Node 24, więc reszta kodu
// widzi tylko interfejs Db: podmiana (np. na better-sqlite3) dotyka wyłącznie tego pliku.

import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import type { DatabaseSync } from 'node:sqlite';

/** Równoległe hooki kilku sesji piszą do jednej bazy — czekamy na blokadę zamiast od razu padać. */
export const BUSY_TIMEOUT_MS = 5000;

/** Jedna migracja = jeden krok schematu; numer wersji to pozycja w tablicy + 1 (`user_version`). */
export type Migration = string;
export type Param = string | number | null;
export type Row = Record<string, unknown>;

export interface Db {
  readonly path: string;
  run(sql: string, ...params: Param[]): { changes: number; lastInsertRowid: number };
  get<T = Row>(sql: string, ...params: Param[]): T | undefined;
  all<T = Row>(sql: string, ...params: Param[]): T[];
  /**
   * Zapis z blokadą od początku (BEGIN IMMEDIATE); wyjątek wycofuje całość. Zagnieżdżona
   * transakcja to punkt zapisu (SAVEPOINT) — sync składa wiele przejść w jedną transakcję.
   */
  transaction<T>(fn: () => T): T;
  close(): void;
}

/** `REGENT_DB` (testy, izolacja) albo `${XDG_STATE_HOME:-~/.local/state}/regent/regent.db`. */
export function defaultDbPath(env: NodeJS.ProcessEnv = process.env, home: string = homedir()): string {
  if (env.REGENT_DB) return env.REGENT_DB;
  return join(env.XDG_STATE_HOME || join(home, '.local', 'state'), 'regent', 'regent.db');
}

let sqlite: typeof import('node:sqlite') | undefined;

/** Ładuje node:sqlite z wyciszonym ExperimentalWarning tylko dla SQLite — inne ostrzeżenia zostają. */
function loadSqlite(): typeof import('node:sqlite') {
  if (sqlite) return sqlite;
  const original = process.emitWarning;
  process.emitWarning = function (this: unknown, warning: string | Error, ...rest: unknown[]) {
    const opt = rest[0];
    const type = typeof opt === 'string' ? opt : (opt as { type?: string } | undefined)?.type;
    const message = typeof warning === 'string' ? warning : warning.message;
    if (type === 'ExperimentalWarning' && message.includes('SQLite')) return;
    return (original as (...args: unknown[]) => void).call(process, warning, ...rest);
  } as typeof process.emitWarning;
  try {
    sqlite = createRequire(import.meta.url)('node:sqlite') as typeof import('node:sqlite');
  } finally {
    process.emitWarning = original;
  }
  return sqlite;
}

export function openDb(path: string, migrations: readonly Migration[]): Db {
  mkdirSync(dirname(path), { recursive: true });
  const raw = new (loadSqlite().DatabaseSync)(path, { enableForeignKeyConstraints: true });
  try {
    raw.exec(`PRAGMA busy_timeout = ${BUSY_TIMEOUT_MS}`);
    raw.exec('PRAGMA journal_mode = WAL');
    raw.exec('PRAGMA synchronous = NORMAL');
    migrate(raw, migrations);
  } catch (e) {
    raw.close();
    throw e;
  }
  return wrap(raw, path);
}

function userVersion(raw: DatabaseSync): number {
  return Number((raw.prepare('PRAGMA user_version').get() as { user_version: number }).user_version);
}

function migrate(raw: DatabaseSync, migrations: readonly Migration[]): void {
  if (userVersion(raw) === migrations.length) return;
  inTransaction(raw, () => {
    // Wersję czytamy ponownie pod blokadą — inny proces mógł właśnie zmigrować.
    const current = userVersion(raw);
    if (current > migrations.length) {
      throw new Error(`baza w nowszej wersji schematu (${current}), a ten regent zna ${migrations.length} — zaktualizuj regent`);
    }
    for (let v = current; v < migrations.length; v++) raw.exec(migrations[v]!);
    raw.exec(`PRAGMA user_version = ${migrations.length}`);
  });
}

function inTransaction<T>(raw: DatabaseSync, fn: () => T): T {
  raw.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    raw.exec('COMMIT');
    return result;
  } catch (e) {
    raw.exec('ROLLBACK');
    throw e;
  }
}

function inSavepoint<T>(raw: DatabaseSync, name: string, fn: () => T): T {
  raw.exec(`SAVEPOINT ${name}`);
  try {
    const result = fn();
    raw.exec(`RELEASE ${name}`);
    return result;
  } catch (e) {
    raw.exec(`ROLLBACK TO ${name}`);
    raw.exec(`RELEASE ${name}`);
    throw e;
  }
}

function wrap(raw: DatabaseSync, path: string): Db {
  let depth = 0;
  return {
    path,
    run: (sql, ...params) => {
      const r = raw.prepare(sql).run(...params);
      return { changes: Number(r.changes), lastInsertRowid: Number(r.lastInsertRowid) };
    },
    get: <T>(sql: string, ...params: Param[]) => {
      const row = raw.prepare(sql).get(...params);
      return row === undefined ? undefined : ({ ...row } as T);
    },
    all: <T>(sql: string, ...params: Param[]) => raw.prepare(sql).all(...params).map((row) => ({ ...row }) as T),
    transaction: (fn) => {
      depth++;
      try {
        return depth === 1 ? inTransaction(raw, fn) : inSavepoint(raw, `sp${depth}`, fn);
      } finally {
        depth--;
      }
    },
    close: () => raw.close(),
  };
}
