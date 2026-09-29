import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import type { Db } from '../src/db.js';
import { STATES, TRANSITIONS, TransitionError, UsageError } from '../src/model.js';
import { openTaskDb } from '../src/schema.js';
import { TaskStore, type Ctx } from '../src/tasks.js';
import { tempDir } from './helpers.js';

const P = '/projekty/demo';
const ME: Ctx = { actor: 'me', source: 'cli' };
const AGENT: Ctx = { actor: 'agent', source: 'cli' };
const T0 = Date.UTC(2026, 8, 29, 10, 0);
const iso = (ms: number) => new Date(ms).toISOString();

function setup(): { db: Db; store: TaskStore; clock: { now: number } } {
  const db = openTaskDb(join(tempDir(), 'regent.db'));
  const clock = { now: T0 };
  return { db, store: new TaskStore(db, () => clock.now), clock };
}

describe('TaskStore — zakładanie i dwa poziomy', () => {
  it('ręczne zadanie: oczekuje, właściciel, pierwszy wpis w logu', () => {
    const { store } = setup();
    const t = store.add({ project: P, title: '  Przejrzeć PR  ', owner: 'me' }, ME);
    expect(t).toMatchObject({ kind: 'manual', parentId: null, title: 'Przejrzeć PR', owner: 'me', state: 'pending' });
    expect(t.createdAt).toBe(iso(T0));
    expect(store.history(t.id)).toMatchObject([{ state: 'pending', owner: 'me', actor: 'me', source: 'cli', reason: null }]);
  });

  it('zmiana SDD jako rodzic, jej taski jako dzieci', () => {
    const { store } = setup();
    const change = store.add({ project: P, kind: 'change', key: 'sdd:login', title: 'login', owner: 'me', state: 'waiting' }, ME);
    const task = store.add(
      { project: P, kind: 'task', parentId: change.id, key: 'T-01', tag: 'BE', title: 'endpoint', owner: 'agent', refs: { ac: ['AC-1'] } },
      ME,
    );
    expect(task).toMatchObject({ parentId: change.id, key: 'T-01', tag: 'BE', refs: { ac: ['AC-1'] } });
  });

  it('odrzuca trzeci poziom, task bez rodzica, rodzica przy ręcznym i rodzica z innego projektu', () => {
    const { store } = setup();
    const change = store.add({ project: P, kind: 'change', key: 'sdd:a', title: 'a', owner: 'me' }, ME);
    const child = store.add({ project: P, kind: 'task', parentId: change.id, key: 'T-01', title: 't', owner: 'agent' }, ME);
    const manual = store.add({ project: P, title: 'ręczne', owner: 'me' }, ME);
    const cases = [
      { project: P, kind: 'task' as const, parentId: child.id, key: 'T-02', title: 'x', owner: 'agent' as const },
      { project: P, kind: 'task' as const, key: 'T-03', title: 'x', owner: 'agent' as const },
      { project: P, kind: 'task' as const, parentId: manual.id, key: 'T-04', title: 'x', owner: 'agent' as const },
      { project: P, kind: 'manual' as const, parentId: change.id, title: 'x', owner: 'me' as const },
      { project: '/inny', kind: 'task' as const, parentId: change.id, key: 'T-05', title: 'x', owner: 'agent' as const },
      { project: P, kind: 'change' as const, key: 'login', title: 'bez prefiksu', owner: 'me' as const },
      { project: P, kind: 'task' as const, parentId: change.id, key: 'T-01', title: 'duplikat', owner: 'agent' as const },
      { project: P, title: '   ', owner: 'me' as const },
    ];
    for (const input of cases) expect(() => store.add(input, ME), JSON.stringify(input)).toThrow(UsageError);
  });

  it('ten sam klucz w innym projekcie i pod innym rodzicem jest dozwolony', () => {
    const { store } = setup();
    const a = store.add({ project: P, kind: 'change', key: 'sdd:a', title: 'a', owner: 'me' }, ME);
    const b = store.add({ project: P, kind: 'change', key: 'sdd:b', title: 'b', owner: 'me' }, ME);
    store.add({ project: '/inny', kind: 'change', key: 'sdd:a', title: 'a', owner: 'me' }, ME);
    store.add({ project: P, kind: 'task', parentId: a.id, key: 'T-01', title: 't', owner: 'agent' }, ME);
    expect(() => store.add({ project: P, kind: 'task', parentId: b.id, key: 'T-01', title: 't', owner: 'agent' }, ME)).not.toThrow();
  });
});

describe('TaskStore — przejścia', () => {
  it('każda para stanów: dozwolone przechodzi, reszta odrzucona bez śladu w bazie', () => {
    const { store } = setup();
    for (const from of STATES) {
      for (const to of STATES) {
        const reason = 'powód';
        const t = store.add({ project: P, title: `${from}→${to}`, owner: 'agent', state: from, reason }, ME);
        const allowed = TRANSITIONS[from].includes(to);
        if (allowed) {
          expect(store.transition(t.id, to, { ...ME, reason }).state, `${from}→${to}`).toBe(to);
          expect(store.history(t.id).map((x) => x.state)).toEqual([from, to]);
        } else {
          let error: unknown;
          try {
            store.transition(t.id, to, { ...ME, reason });
          } catch (e) {
            error = e;
          }
          expect(error, `${from}→${to}`).toBeInstanceOf(TransitionError);
          expect((error as TransitionError).allowed).toEqual(TRANSITIONS[from]);
          expect(store.get(t.id)?.state).toBe(from);
          expect(store.history(t.id)).toHaveLength(1);
        }
      }
    }
  });

  it('zakończenie i porzucenie wymagają powodu; powód trafia do zadania i logu', () => {
    const { store } = setup();
    const t = store.add({ project: P, title: 'x', owner: 'me' }, ME);
    expect(() => store.done(t.id, '', ME)).toThrow(UsageError);
    expect(() => store.drop(t.id, '  ', ME)).toThrow(UsageError);
    expect(() => store.add({ project: P, title: 'y', owner: 'me', state: 'done' }, ME)).toThrow(UsageError);
    expect(store.get(t.id)?.state).toBe('pending');
    const done = store.done(t.id, 'zrobione ręcznie', ME);
    expect(done).toMatchObject({ state: 'done', closureReason: 'zrobione ręcznie' });
    expect(store.history(t.id).at(-1)).toMatchObject({ state: 'done', reason: 'zrobione ręcznie' });
  });

  it('take: właścicielem zostaje biorący, czas wzięcia z zegara, sesja zapisana', () => {
    const { store, clock } = setup();
    const t = store.add({ project: P, title: 'x', owner: 'me' }, ME);
    clock.now = T0 + 60_000;
    const taken = store.take(t.id, 'agent', AGENT, { sessionId: 's-1' });
    expect(taken).toMatchObject({ state: 'in_progress', owner: 'agent', claimedAt: iso(T0 + 60_000), sessionId: 's-1', transcriptPath: null });
    expect(taken.updatedAt).toBe(iso(T0 + 60_000));
    expect(() => store.take(t.id, 'me', ME)).toThrow(TransitionError);
  });

  it('ponowne wejście w toku zeruje sesję poprzedniego wzięcia', () => {
    const { store } = setup();
    const t = store.add({ project: P, title: 'x', owner: 'me' }, ME);
    store.take(t.id, 'agent', AGENT, { sessionId: 's-1', transcriptPath: '/t/s-1.jsonl' });
    store.handoff(t.id, 'me', AGENT);
    expect(store.take(t.id, 'me', ME)).toMatchObject({ owner: 'me', sessionId: null, transcriptPath: null });
  });

  it('handoff: me → czeka na Ciebie, agent → przekazane; powód opcjonalny, w logu', () => {
    const { store } = setup();
    const t = store.add({ project: P, title: 'x', owner: 'me' }, ME);
    store.take(t.id, 'agent', AGENT);
    expect(store.handoff(t.id, 'me', AGENT, 'decyzja o API')).toMatchObject({ state: 'waiting', owner: 'me' });
    expect(store.handoff(t.id, 'agent', ME)).toMatchObject({ state: 'handed_off', owner: 'agent' });
    expect(store.history(t.id).map((x) => [x.state, x.owner, x.actor, x.reason])).toEqual([
      ['pending', 'me', 'me', null],
      ['in_progress', 'agent', 'agent', null],
      ['waiting', 'me', 'agent', 'decyzja o API'],
      ['handed_off', 'agent', 'me', null],
    ]);
  });

  it('nieznane zadanie — błąd użycia', () => {
    const { store } = setup();
    expect(() => store.take(42, 'me', ME)).toThrow(UsageError);
    expect(store.get(42)).toBeUndefined();
  });
});

describe('log przejść tylko do dopisywania', () => {
  it('UPDATE i DELETE na transitions oraz DELETE zadania są odrzucane przez bazę', () => {
    const { db, store } = setup();
    const t = store.add({ project: P, title: 'x', owner: 'me' }, ME);
    expect(() => db.run('UPDATE transitions SET reason = ? WHERE task_id = ?', 'podmiana', t.id)).toThrow(/tylko do dopisywania/);
    expect(() => db.run('DELETE FROM transitions WHERE task_id = ?', t.id)).toThrow(/tylko do dopisywania/);
    expect(() => db.run('DELETE FROM tasks WHERE id = ?', t.id)).toThrow(/nie ginie/);
    expect(store.history(t.id)).toHaveLength(1);
  });
});

describe('list', () => {
  it('otwarte zadania projektu; --all dokłada zamknięte; dzieci pod rodzicem', () => {
    const { store } = setup();
    const change = store.add({ project: P, kind: 'change', key: 'sdd:a', title: 'a', owner: 'me' }, ME);
    const manual = store.add({ project: P, title: 'ręczne', owner: 'me' }, ME);
    const t1 = store.add({ project: P, kind: 'task', parentId: change.id, key: 'T-01', title: 't1', owner: 'agent' }, ME);
    const t2 = store.add({ project: P, kind: 'task', parentId: change.id, key: 'T-02', title: 't2', owner: 'agent' }, ME);
    store.add({ project: '/inny', title: 'obce', owner: 'me' }, ME);
    store.done(t1.id, 'ok', ME);
    const ids = (all: boolean) => store.list(P, { all }).map((t) => t.id);
    expect(ids(false)).toEqual([change.id, t2.id, manual.id]);
    expect(ids(true)).toEqual([change.id, t1.id, t2.id, manual.id]);
  });

  it('zamknięty rodzic otwartego dziecka zostaje na liście', () => {
    const { store } = setup();
    const change = store.add({ project: P, kind: 'change', key: 'sdd:a', title: 'a', owner: 'me' }, ME);
    const t1 = store.add({ project: P, kind: 'task', parentId: change.id, key: 'T-01', title: 't1', owner: 'agent' }, ME);
    store.drop(change.id, 'porzucona', ME);
    expect(store.list(P, { all: false }).map((t) => t.id)).toEqual([change.id, t1.id]);
  });
});
