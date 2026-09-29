import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { BUSY_TIMEOUT_MS, defaultDbPath, openDb, type Migration } from '../src/db.js';
import { tempDir } from './helpers.js';

const DB_SRC = fileURLToPath(new URL('../src/db.ts', import.meta.url));

const M1: Migration = 'CREATE TABLE a (id INTEGER PRIMARY KEY, v TEXT)';
const M2: Migration = 'ALTER TABLE a ADD COLUMN w TEXT';

describe('defaultDbPath — jedna baza na maszynę', () => {
  it('REGENT_DB wygrywa (testy, izolacja)', () => {
    expect(defaultDbPath({ REGENT_DB: '/x/r.db', XDG_STATE_HOME: '/s' }, '/home/u')).toBe('/x/r.db');
  });

  it('XDG_STATE_HOME, a gdy puste — ~/.local/state', () => {
    expect(defaultDbPath({ XDG_STATE_HOME: '/s' }, '/home/u')).toBe('/s/regent/regent.db');
    expect(defaultDbPath({ XDG_STATE_HOME: '' }, '/home/u')).toBe('/home/u/.local/state/regent/regent.db');
    expect(defaultDbPath({}, '/home/u')).toBe('/home/u/.local/state/regent/regent.db');
  });
});

describe('openDb', () => {
  it('zakłada katalogi, włącza WAL, busy_timeout i klucze obce', () => {
    const path = join(tempDir(), 'a', 'b', 'regent.db');
    const db = openDb(path, []);
    expect(existsSync(path)).toBe(true);
    expect(db.get<{ journal_mode: string }>('PRAGMA journal_mode')?.journal_mode).toBe('wal');
    expect(db.get<{ timeout: number }>('PRAGMA busy_timeout')?.timeout).toBe(BUSY_TIMEOUT_MS);
    expect(db.get<{ foreign_keys: number }>('PRAGMA foreign_keys')?.foreign_keys).toBe(1);
    db.close();
  });

  it('migracje po kolei, wersja w user_version, ponowne otwarcie niczego nie powtarza', () => {
    const path = join(tempDir(), 'regent.db');
    const first = openDb(path, [M1]);
    expect(first.get<{ user_version: number }>('PRAGMA user_version')?.user_version).toBe(1);
    first.run('INSERT INTO a (v) VALUES (?)', 'x');
    first.close();

    const second = openDb(path, [M1, M2]);
    expect(second.get<{ user_version: number }>('PRAGMA user_version')?.user_version).toBe(2);
    expect(second.all('SELECT v, w FROM a')).toEqual([{ v: 'x', w: null }]);
    second.close();
  });

  it('nieudana migracja wycofuje się w całości', () => {
    const path = join(tempDir(), 'regent.db');
    openDb(path, [M1]).close();
    expect(() => openDb(path, [M1, 'ALTER TABLE a ADD COLUMN w TEXT; SELECT * FROM nie_ma'])).toThrow();
    const db = openDb(path, [M1, M2]);
    expect(db.get<{ user_version: number }>('PRAGMA user_version')?.user_version).toBe(2);
    db.close();
  });

  it('baza w nowszej wersji schematu niż zna CLI — błąd zamiast cichej pracy', () => {
    const path = join(tempDir(), 'regent.db');
    openDb(path, [M1, M2]).close();
    expect(() => openDb(path, [M1])).toThrow(/nowszej wersji schematu \(2\).*zna 1/);
  });

  it('transaction wycofuje zmiany po wyjątku', () => {
    const db = openDb(join(tempDir(), 'regent.db'), [M1]);
    expect(() =>
      db.transaction(() => {
        db.run('INSERT INTO a (v) VALUES (?)', 'x');
        throw new Error('stop');
      }),
    ).toThrow('stop');
    expect(db.all('SELECT * FROM a')).toEqual([]);
    expect(db.transaction(() => db.run('INSERT INTO a (v) VALUES (?)', 'y').lastInsertRowid)).toBe(1);
    db.close();
  });

  it('zagnieżdżona transaction to punkt zapisu: wycofuje tylko siebie, całość dopiero zewnętrzna', () => {
    const db = openDb(join(tempDir(), 'regent.db'), [M1]);
    db.transaction(() => {
      db.run('INSERT INTO a (v) VALUES (?)', 'zewnętrzne');
      expect(() =>
        db.transaction(() => {
          db.run('INSERT INTO a (v) VALUES (?)', 'wewnętrzne');
          throw new Error('stop');
        }),
      ).toThrow('stop');
      db.transaction(() => db.run('INSERT INTO a (v) VALUES (?)', 'drugie'));
    });
    expect(db.all('SELECT v FROM a ORDER BY id')).toEqual([{ v: 'zewnętrzne' }, { v: 'drugie' }]);
    expect(() =>
      db.transaction(() => {
        db.transaction(() => db.run('INSERT INTO a (v) VALUES (?)', 'x'));
        throw new Error('całość');
      }),
    ).toThrow('całość');
    expect(db.all('SELECT v FROM a ORDER BY id')).toHaveLength(2);
    db.close();
  });

  it('ExperimentalWarning z node:sqlite wyciszone, inne ostrzeżenia zostają', () => {
    const path = join(tempDir(), 'regent.db');
    const script = `const { openDb } = await import(${JSON.stringify(DB_SRC)});
openDb(${JSON.stringify(path)}, []).close();
process.emitWarning('inne ostrzeżenie', 'ExperimentalWarning');`;
    const { status, stderr } = spawnSync(process.execPath, ['--input-type=module', '-e', script], { encoding: 'utf8' });
    expect(status).toBe(0);
    expect(stderr).not.toMatch(/SQLite/);
    expect(stderr).toMatch(/inne ostrzeżenie/);
  });
});
