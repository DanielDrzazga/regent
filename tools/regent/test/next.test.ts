import { spawnSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';
import { SDD_CHECK } from '../src/sdd.js';
import { cli, edit, read, sddProject } from './helpers.js';

const json = <T = any>(text: string): T => JSON.parse(text) as T;
const TASKS = 'ai/changes/note-tags/tasks.md';

function setup(env: NodeJS.ProcessEnv = {}) {
  const project = sddProject();
  const regent = cli({ cwd: project, env });
  const all = (): any[] => json(regent('task', 'list', '--all', '--json').out).tasks;
  const id = (key: string, change = 'note-tags') => {
    const parent = all().find((t) => t.key === `sdd:${change}`);
    return String(all().find((t) => t.parentId === parent.id && t.key === key).id);
  };
  const next = (...args: string[]) => json(regent('task', 'next', 'note-tags', ...args, '--json').out);
  const keys = (list: { key: string }[]) => list.map((t) => t.key);
  return { project, regent, id, next, keys };
}

describe('regent task next', () => {
  it('gotowe: niezrobione z zamkniętymi zależnościami; sync robi sam', () => {
    const { regent, next, keys } = setup();
    const r = next();
    expect(keys(r.ready)).toEqual(['T-02', 'T-04', 'T-05']);
    expect(r.blocked).toEqual([
      expect.objectContaining({ key: 'T-03', after: ['T-02'] }),
      expect.objectContaining({ key: 'T-06', after: ['T-03', 'T-04'] }),
    ]);
    expect(r.ready[0].packet).toMatch(/^# Paczka: note-tags — T-02\n/);
    const text = regent('task', 'next', 'note-tags').out;
    expect(text).toMatch(/^sdd:note-tags — gotowe: 3\n/);
    expect(text).toMatch(/Czekają na zależności:\n.*T-03 \[BE\] Filtr GET \/notes\?tag +po T-02\n/);
    expect(text).toMatch(/\n\nPaczka: regent task packet note-tags T-02 T-04 T-05$/);
  });

  it('--layer: brak tagu to BE; warstwa bez gotowych — komunikat', () => {
    const { regent, next, keys } = setup();
    expect(keys(next('--layer', 'BE').ready)).toEqual(['T-02', 'T-05']);
    expect(keys(next('--layer', 'fe').ready)).toEqual(['T-04']);
    expect(next('--layer', 'DB')).toMatchObject({ ready: [], blocked: [], open: 0 });
    expect(regent('task', 'next', 'note-tags', '--layer', 'DB').out).toBe(
      'sdd:note-tags (warstwa DB): brak otwartych tasków gotowych do pracy (otwarte: 0).',
    );
    expect(regent('task', 'next', 'note-tags', '--layer', 'QA').code).toBe(2);
  });

  it('zamknięcie zależności odblokowuje; czeka na Ciebie nie jest gotowe; przerwane w toku — jest', () => {
    const { regent, id, next, keys } = setup();
    regent('task', 'sync');
    regent('task', 'take', id('T-02'));
    regent('task', 'handoff', id('T-05'), 'me');
    expect(keys(next().ready)).toEqual(['T-02', 'T-04']);
    expect(next().ready[0].state).toBe('in_progress');
    regent('task', 'done', id('T-02'), '--commit', 'abc1234');
    expect(keys(next().ready)).toEqual(['T-03', 'T-04']);
  });

  it('zależność, której nie ma w tasks.md, blokuje — bez zgadywania', () => {
    const { project, next } = setup();
    edit(project, TASKS, (t) => t.replace('test indeksu (po T-01)', 'test indeksu (po T-42)'));
    expect(next().blocked).toEqual(expect.arrayContaining([expect.objectContaining({ key: 'T-05', after: ['T-42'] })]));
  });

  it('nieznana zmiana albo brak nazwy — kod 2', () => {
    const { regent } = setup();
    expect(regent('task', 'next', 'nie-ma').err).toMatch(/nie ma zmiany sdd:nie-ma/);
    expect(regent('task', 'next').code).toBe(2);
  });
});

describe('regent task done --commit --tests — lustro tasks.md', () => {
  it('przepisuje wyłącznie linię taska w formacie z apply 4c; sync potem nic nie zmienia', () => {
    const { project, regent, id } = setup();
    regent('task', 'sync');
    const before = read(project, TASKS).split('\n');
    const r = regent('task', 'done', id('T-02'), '--commit', 'abc1234', '--tests', 'AC-1 → test/tags.test.ts › lowercases; AC-2..3 → … › rejects');
    expect(r).toMatchObject({ code: 0, err: '' });
    expect(r.out).toMatch(/ T-02 \[BE\] Serwis tagów — zakończone \(agent\)$/);
    const after = read(project, TASKS).split('\n');
    const at = before.findIndex((l) => l.startsWith('- [ ] T-02'));
    expect(after[at]).toBe(
      '- [x] T-02: [BE] Serwis tagów — REQ-004/AC-1..3 — pliki: src/tags/service.ts — weryfikacja: testy REQ-004/AC-1..3 zielone (po T-01) ✅ (commit: abc1234 · testy: AC-1 → test/tags.test.ts › lowercases; AC-2..3 → … › rejects)',
    );
    expect(after.filter((_, i) => i !== at)).toEqual(before.filter((_, i) => i !== at));

    const t02 = json(regent('task', 'show', id('T-02'), '--json').out).task;
    expect(t02).toMatchObject({ state: 'done', closureReason: 'commit: abc1234', refs: { commit: 'abc1234', box: 'DONE' } });
    const sync = json(regent('task', 'sync', '--json').out);
    expect(sync).toMatchObject({ checked: true, events: [] });

    // Ślad spełnia reguły sdd-check.sh change: bez „odhaczony bez śladu” i bez „bez mapowania testy:”.
    const check = spawnSync('bash', [SDD_CHECK, 'change', 'note-tags'], { cwd: project, encoding: 'utf8' });
    expect(check.stdout).toMatch(/tasks\.md: 2\/6 zrobione/);
    expect(check.stdout).not.toMatch(/T-02 odhaczony/);
  });

  it('nowy ślad zastępuje stary; bez --commit zmienia się tylko pole; CRLF zostaje', () => {
    const { project, regent, id } = setup();
    regent('task', 'sync');
    edit(project, TASKS, (t) => t.replace('- [x] T-01', '- [ ] T-01').replace(/\n/g, '\r\n'));
    regent('task', 'sync');
    regent('task', 'done', id('T-01'), '--commit', '9f9f9f9');
    regent('task', 'done', id('T-05'), '--reason', 'zrobione ręcznie');
    const lines = read(project, TASKS).split('\r\n');
    expect(lines.find((l) => l.includes('T-01:'))).toMatch(/^- \[x\] T-01: .*up\/down\/up ✅ \(commit: 9f9f9f9\)$/);
    expect(lines.find((l) => l.includes('T-05:'))).toBe(
      '- [x] T-05: Indeks tagów — REQ-005/AC-1 — pliki: src/tags/index.ts — weryfikacja: test indeksu (po T-01)',
    );
    expect(read(project, TASKS).split('\n').every((l, i, a) => i === a.length - 1 || l.endsWith('\r'))).toBe(true);
  });

  it('niedozwolone przejście — kod 1, plik bez zmian; --commit poza taskiem zmiany — kod 2', () => {
    const { project, regent, id } = setup();
    regent('task', 'sync');
    regent('task', 'handoff', id('T-03'), 'agent');
    const before = read(project, TASKS);
    const r = regent('task', 'done', id('T-03'), '--commit', 'abc1234');
    expect(r.code).toBe(1);
    expect(r.err).toMatch(/„przekazane” — done niedozwolone/);
    expect(read(project, TASKS)).toBe(before);

    regent('task', 'add', 'ręczne');
    const manual = String(json(regent('task', 'list', '--json').out).tasks.find((t: any) => t.kind === 'manual').id);
    expect(regent('task', 'done', manual, '--commit', 'abc1234').err).toMatch(/tylko dla taska zmiany SDD/);
    expect(regent('task', 'done', id('T-04'), '--commit', 'nie-hash').err).toMatch(/--commit wymaga hasha/);
    expect(regent('task', 'done', id('T-04')).err).toMatch(/--reason/);
  });

  it('linii nie ma już w pliku — zamyka w bazie i mówi o tym na stderr', () => {
    const { project, regent, id } = setup();
    regent('task', 'sync');
    const t06 = id('T-06');
    edit(project, TASKS, (t) => t.replace(/- \[ \] T-06.*\n/, ''));
    const r = regent('task', 'done', t06, '--commit', 'abc1234');
    expect(r.code).toBe(0);
    expect(r.err).toMatch(/^regent: T-06 nie ma w .+tasks\.md — plik bez zmian$/);
    expect(json(regent('task', 'show', t06, '--json').out).task.state).toBe('done');
  });
});
