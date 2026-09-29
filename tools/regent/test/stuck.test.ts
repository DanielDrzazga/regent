import { utimesSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { openTaskDb } from '../src/schema.js';
import { findStuck, type Mtime } from '../src/stuck.js';
import { TaskStore, type Ctx, type Task } from '../src/tasks.js';
import { cli, gitProject, tempDir } from './helpers.js';

const T0 = Date.UTC(2026, 8, 29, 10, 0);
const MIN = 60_000;
const ME: Ctx = { actor: 'me', source: 'cli' };
const json = <T = any>(text: string): T => JSON.parse(text) as T;

function task(over: Partial<Task>): Task {
  return {
    id: 1,
    project: '/p',
    parentId: null,
    key: null,
    kind: 'manual',
    tag: null,
    title: 'x',
    owner: 'agent',
    state: 'in_progress',
    refs: {},
    closureReason: null,
    sessionId: null,
    transcriptPath: null,
    fileSig: null,
    claimedAt: new Date(T0).toISOString(),
    createdAt: new Date(T0).toISOString(),
    updatedAt: new Date(T0).toISOString(),
    ...over,
  };
}

const mtimes =
  (files: Record<string, number>): Mtime =>
  (path) =>
    files[path];

describe('findStuck — utknięcie liczone przy odczycie', () => {
  const opts = (now: number, mtime: Mtime = () => undefined) => ({ now, thresholdMs: 30 * MIN, mtime });

  it('tylko zadania w toku', () => {
    const tasks = (['pending', 'waiting', 'handed_off', 'blocked', 'done', 'dropped'] as const).map((state, i) => task({ id: i + 1, state }));
    expect(findStuck(tasks, opts(T0 + 600 * MIN))).toEqual([]);
  });

  it('sesja z transkryptem: utknięte, gdy transkrypt stoi od progu', () => {
    const t = task({ sessionId: 's-1', transcriptPath: '/t/s-1.jsonl' });
    const files = mtimes({ '/t/s-1.jsonl': T0 + 10 * MIN });
    expect(findStuck([t], opts(T0 + 39 * MIN, files))).toEqual([]);
    expect(findStuck([t], opts(T0 + 40 * MIN, files))).toEqual([{ taskId: 1, why: 'idle', idleMs: 30 * MIN, since: new Date(T0 + 10 * MIN).toISOString() }]);
  });

  it('transkrypt starszy niż wzięcie — liczy się od wzięcia', () => {
    const t = task({ sessionId: 's-1', transcriptPath: '/t/s-1.jsonl', claimedAt: new Date(T0 + 60 * MIN).toISOString() });
    const files = mtimes({ '/t/s-1.jsonl': T0 });
    expect(findStuck([t], opts(T0 + 80 * MIN, files))).toEqual([]);
    expect(findStuck([t], opts(T0 + 95 * MIN, files))).toMatchObject([{ why: 'idle', idleMs: 35 * MIN }]);
  });

  it('transkrypt nie istnieje — liczy się od wzięcia', () => {
    const t = task({ sessionId: 's-1', transcriptPath: '/t/brak.jsonl' });
    expect(findStuck([t], opts(T0 + 29 * MIN))).toEqual([]);
    expect(findStuck([t], opts(T0 + 31 * MIN))).toMatchObject([{ why: 'no-transcript', idleMs: 31 * MIN }]);
  });

  it('bez sesji — po progu od wzięcia', () => {
    const t = task({});
    expect(findStuck([t], opts(T0 + 29 * MIN))).toEqual([]);
    expect(findStuck([t], opts(T0 + 30 * MIN))).toMatchObject([{ why: 'no-session', idleMs: 30 * MIN }]);
    expect(findStuck([task({ sessionId: 's-1' })], opts(T0 + 30 * MIN))).toMatchObject([{ why: 'no-session' }]);
  });

  it('próg z opcji', () => {
    expect(findStuck([task({})], { now: T0 + 6 * MIN, thresholdMs: 5 * MIN, mtime: () => undefined })).toHaveLength(1);
  });
});

describe('regent task list — sekcja Uwaga', () => {
  it('zadanie w toku bez sesji trafia do Uwagi po progu; --stuck zmienia próg', () => {
    const project = gitProject();
    const clock = { now: T0 };
    const regent = cli({ cwd: project, now: () => clock.now });
    regent('task', 'add', 'parser');
    regent('task', 'add', 'recenzja');
    regent('task', 'take', '1');

    clock.now = T0 + 10 * MIN;
    expect(regent('task', 'list').out).not.toMatch(/Uwaga/);

    clock.now = T0 + 45 * MIN;
    const list = regent('task', 'list').out.split('\n');
    expect(list.slice(-3)).toEqual(['', 'Uwaga:', '  #1  utknięte — w toku bez sesji od 45 min']);
    expect(regent('task', 'list', '--stuck', '60').out).not.toMatch(/Uwaga/);
    expect(json(regent('task', 'list', '--json').out).attention).toEqual({
      stuck: [{ id: 1, why: 'no-session', idleMinutes: 45, since: new Date(T0).toISOString() }],
      missing: [],
      mismatch: [],
      lastSync: null,
    });

    clock.now = T0 + 150 * MIN;
    expect(regent('task', 'list').out).toMatch(/#1 {2}utknięte — w toku bez sesji od 2 godz\. 30 min$/);
  });

  it('transkrypt sesji stoi od progu — Uwaga z sesją; świeży zapis ją zdejmuje', () => {
    const project = gitProject();
    const clock = { now: T0 };
    const regent = cli({ cwd: project, now: () => clock.now });
    const transcript = join(tempDir(), 'sesja-1.jsonl');
    writeFileSync(transcript, '{}\n');
    const db = openTaskDb(regent.db);
    const store = new TaskStore(db, () => clock.now);
    const t = store.add({ project, title: 'endpoint', owner: 'agent' }, ME);
    store.take(t.id, 'agent', { actor: 'agent', source: 'cli' }, { sessionId: '0123456789abcdef', transcriptPath: transcript });
    db.close();

    utimesSync(transcript, (T0 + 5 * MIN) / 1000, (T0 + 5 * MIN) / 1000);
    clock.now = T0 + 40 * MIN;
    expect(regent('task', 'list').out).toMatch(/\n\nUwaga:\n {2}#1 {2}utknięte — transkrypt sesji 01234567 bez zmian od 35 min$/);

    utimesSync(transcript, (T0 + 38 * MIN) / 1000, (T0 + 38 * MIN) / 1000);
    expect(regent('task', 'list').out).not.toMatch(/Uwaga/);
  });

  it('błędny próg — kod 2', () => {
    const regent = cli();
    for (const value of ['0', '-5', 'abc']) expect(regent('task', 'list', '--stuck', value).code, value).toBe(2);
  });
});
