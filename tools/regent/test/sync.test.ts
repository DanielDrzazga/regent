import { renameSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { metaField, parseStatus, type ChangeStatus } from '../src/sdd.js';
import { openTaskDb } from '../src/schema.js';
import { impliedState, syncProject } from '../src/sync.js';
import { TaskStore } from '../src/tasks.js';
import { cli, edit, gitProject, sddProject, tempDir, write } from './helpers.js';

const json = <T = any>(text: string): T => JSON.parse(text) as T;
const T0 = Date.UTC(2026, 8, 29, 10, 0);
const MIN = 60_000;

type Entry = { state: string; owner: string; actor: string; source: string; reason: string | null };

/** Zadanie zmiany po kluczu i jego historia — przez `list --all` i `show --json`. */
function change(regent: ReturnType<typeof cli>, name: string) {
  const tasks = json(regent('task', 'list', '--all', '--json').out).tasks as { id: number; key: string }[];
  const task = tasks.find((t) => t.key === `sdd:${name}`);
  if (!task) return undefined;
  return json<{ task: any; history: Entry[] }>(regent('task', 'show', String(task.id), '--json').out);
}

const status = (over: Partial<ChangeStatus>): ChangeStatus => ({
  name: 'x',
  status: 'Approved',
  done: 0,
  total: 3,
  verdict: null,
  head: null,
  ...over,
});

describe('mapa SDD → stan zmiany', () => {
  it('Status, taski i werdykt dają stan z planu', () => {
    const cases: [Partial<ChangeStatus>, string][] = [
      [{ status: 'Draft' }, 'waiting'],
      [{ status: 'Rejected' }, 'dropped'],
      [{ status: 'Abandoned' }, 'dropped'],
      [{ status: 'brak' }, 'waiting'],
      [{ done: 0 }, 'pending'],
      [{ done: 0, total: 0 }, 'pending'],
      [{ done: 1 }, 'in_progress'],
      [{ done: 3 }, 'pending'],
      [{ done: 3, verdict: 'BLOCK', head: 'abc' }, 'in_progress'],
      [{ done: 3, verdict: 'FAIL', head: 'abc' }, 'in_progress'],
      [{ done: 3, verdict: 'PASS', head: 'abc' }, 'waiting'],
      [{ done: 3, verdict: 'WARN', head: 'abc' }, 'waiting'],
      [{ done: 3, verdict: '', head: null }, 'pending'],
      [{ done: 2, verdict: 'PASS', head: 'abc' }, 'in_progress'],
    ];
    for (const [over, state] of cases) expect(impliedState(status(over)).state, JSON.stringify(over)).toBe(state);
    expect(impliedState(status({ done: 3 })).reason).toBe('Approved, taski 3/3, do weryfikacji');
    expect(impliedState(status({ done: 3, verdict: 'PASS', head: 'abc1234' })).reason).toBe(
      'Approved, taski 3/3, weryfikacja PASS@abc1234 — do archiwum',
    );
  });

  it('parseStatus czyta linie sdd-check.sh status', () => {
    const out = [
      'INFO  a: Status=Approved tasks=2/5 verification=PASS@abc1234',
      'INFO  b: Status=Draft / Approved / Rejected tasks=- verification=brak',
      'INFO  c: Status=brak tasks=0/0 verification=@',
      'RESULT: OK (errors=0 warnings=0)',
    ].join('\n');
    expect(parseStatus(out)).toEqual([
      { name: 'a', status: 'Approved', done: 2, total: 5, verdict: 'PASS', head: 'abc1234' },
      { name: 'b', status: 'Draft / Approved / Rejected', done: 0, total: 0, verdict: null, head: null },
      { name: 'c', status: 'brak', done: 0, total: 0, verdict: '', head: null },
    ]);
  });

  it('metaField jak meta_field: tabela z formatowaniem, linia, wartość z ukośnikiem', () => {
    expect(metaField('| **Status** | `Abandoned` |\n', 'Status')).toBe('Abandoned');
    expect(metaField('**Status:** Approved (2026-09-01)\r\n', 'Status')).toBe('Approved');
    expect(metaField('| Status | Draft / Approved |', 'Status')).toBe('Draft / Approved');
    expect(metaField('Statusy: x', 'Status')).toBeUndefined();
  });
});

describe('regent task sync — poziom zmiany', () => {
  it('zakłada zmiany z ai/changes/ ze stanem z mapy; archiwum nieznane bazie pomija', () => {
    const regent = cli({ cwd: sddProject() });
    const r = regent('task', 'sync');
    expect(r.code).toBe(0);
    const changes = r.out.split('\n').filter((l) => / sdd:[a-z-]+ /.test(l));
    expect(changes.map((l) => l.trim().replace(/ {2,}/g, ' | '))).toEqual([
      '#1 | sdd:draft-search | nowe: czeka na Ciebie | Status: Draft',
      '#2 | sdd:legacy-export | nowe: w toku | Approved, taski 1/4',
      '#7 | sdd:note-tags | nowe: w toku | Approved, taski 1/6',
    ]);
    expect(change(regent, 'draft-search')!.task).toMatchObject({ kind: 'change', owner: 'me', state: 'waiting', title: 'draft-search' });
    expect(change(regent, 'note-tags')!.history).toMatchObject([{ state: 'in_progress', owner: 'agent', actor: 'sync', source: 'cli' }]);
    expect(change(regent, 'note-titles')).toBeUndefined();
    expect(change(regent, 'cloud-sync')).toBeUndefined();
    expect(regent('task', 'list').out.split('\n')[2]).toMatch(/^ {2}#1 +czeka na Ciebie +me +sdd:draft-search$/);
  });

  it('bez zmian w plikach stanu nie woła skryptu i nic nie zmienia', () => {
    const regent = cli({ cwd: sddProject() });
    regent('task', 'sync');
    const again = json(regent('task', 'sync', '--json').out);
    expect(again).toMatchObject({ sdd: true, checked: false, events: [] });
    expect(regent('task', 'sync').out).toMatch(/: bez zmian stanu\.$/);
  });

  it('cykl Draft → Approved → taski → weryfikacja → archiwum widać w historii', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    const proposal = 'ai/changes/draft-search/proposal.md';
    const tasks = 'ai/changes/draft-search/tasks.md';
    const sync = () => regent('task', 'sync', '--source', 'hook');
    sync();
    edit(project, proposal, (t) => t.replace('| Status | Draft |', '| Status | Approved |'));
    sync();
    edit(project, tasks, (t) => t.replace('- [ ] T-01', '- [x] T-01'));
    sync();
    write(project, 'ai/changes/draft-search/verification.md', 'Verdict: FAIL\nCommit HEAD: 1111111\n');
    sync();
    write(project, 'ai/changes/draft-search/verification.md', 'Verdict: PASS\nCommit HEAD: 2222222\n');
    sync();
    renameSync(join(project, 'ai/changes/draft-search'), join(project, 'ai/changes/archive/2026-09-29-draft-search'));
    sync();

    const { task, history } = change(regent, 'draft-search')!;
    expect(task).toMatchObject({ state: 'done', owner: 'me', closureReason: 'archiwum: 2026-09-29-draft-search' });
    // 0/1 → 1/1 bez weryfikacji to dalej „oczekuje” — bez wpisu, bo stan się nie zmienił.
    expect(history.map((h) => [h.state, h.owner, h.reason])).toEqual([
      ['waiting', 'me', 'Status: Draft'],
      ['pending', 'agent', 'Approved, taski 0/1'],
      ['in_progress', 'agent', 'Approved, taski 1/1, weryfikacja FAIL@1111111'],
      ['waiting', 'me', 'Approved, taski 1/1, weryfikacja PASS@2222222 — do archiwum'],
      ['done', 'me', 'archiwum: 2026-09-29-draft-search'],
    ]);
    expect(history.every((h) => h.actor === 'sync' && h.source === 'hook')).toBe(true);
  });

  it('wszystkie taski bez weryfikacji → oczekuje (do weryfikacji)', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    edit(project, 'ai/changes/legacy-export/tasks.md', (t) =>
      t.replace(/- \[[ ~]\]|- \[\]/g, '- [x]'),
    );
    regent('task', 'sync');
    expect(change(regent, 'legacy-export')!.history.at(-1)).toMatchObject({ state: 'pending', reason: 'Approved, taski 4/4, do weryfikacji' });
  });

  it('Rejected → porzucone; archiwum ze Status: Abandoned → porzucone', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    edit(project, 'ai/changes/draft-search/proposal.md', (t) => t.replace('| Status | Draft |', '| Status | Rejected |'));
    edit(project, 'ai/changes/legacy-export/proposal.md', (t) => t.replace('**Status:** Approved', '**Status:** Abandoned'));
    renameSync(join(project, 'ai/changes/legacy-export'), join(project, 'ai/changes/archive/2026-09-29-legacy-export'));
    regent('task', 'sync');
    expect(change(regent, 'draft-search')!.task).toMatchObject({ state: 'dropped', closureReason: 'Status: Rejected' });
    expect(change(regent, 'legacy-export')!.task).toMatchObject({
      state: 'dropped',
      closureReason: 'archiwum: 2026-09-29-legacy-export, Status: Abandoned',
    });
  });

  it('ręczna zmiana przez CLI zostaje do zmiany plików; rozjazd w Uwadze', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    expect(regent('task', 'take', '1').code).toBe(0);
    regent('task', 'sync');
    expect(change(regent, 'draft-search')!.task.state).toBe('in_progress');
    expect(regent('task', 'list').out).toMatch(/Uwaga:\n {2}#1 {2}rozjazd z artefaktami — wynika z nich „czeka na Ciebie”, zadanie jest „w toku”/);

    edit(project, 'ai/changes/draft-search/proposal.md', (t) => t.replace('| Status | Draft |', '| Status | Approved |'));
    regent('task', 'sync');
    expect(change(regent, 'draft-search')!.task).toMatchObject({ state: 'pending', owner: 'agent' });
    expect(regent('task', 'list').out).not.toMatch(/rozjazd/);
  });

  it('przejście spoza tabeli zostaje niewykonane — stan bez zmian, rozjazd w Uwadze', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    const id = String(change(regent, 'note-tags')!.task.id);
    regent('task', 'handoff', id, 'agent');
    renameSync(join(project, 'ai/changes/note-tags'), join(project, 'ai/changes/archive/2026-09-29-note-tags'));
    regent('task', 'sync');
    expect(change(regent, 'note-tags')!.task.state).toBe('handed_off');
    expect(regent('task', 'list').out).toMatch(new RegExp(`#${id} {2}rozjazd z artefaktami — wynika z nich „zakończone”, zadanie jest „przekazane”`));
  });

  it('zmiana wyjęta z archiwum otwiera się ponownie, z powodem', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    const active = join(project, 'ai/changes/draft-search');
    const archived = join(project, 'ai/changes/archive/2026-09-29-draft-search');
    renameSync(active, archived);
    regent('task', 'sync');
    renameSync(archived, active);
    regent('task', 'sync');
    const { task, history } = change(regent, 'draft-search')!;
    expect(task).toMatchObject({ state: 'waiting', closureReason: null });
    expect(history.map((h) => [h.state, h.reason])).toEqual([
      ['waiting', 'Status: Draft'],
      ['done', 'archiwum: 2026-09-29-draft-search'],
      ['pending', 'ponowne otwarcie — Status: Draft'],
      ['waiting', 'Status: Draft'],
    ]);
  });

  it('katalog zniknął bez archiwum — ostrzeżenie w list, stan bez zgadywania', () => {
    const project = sddProject();
    const regent = cli({ cwd: project });
    regent('task', 'sync');
    rmSync(join(project, 'ai/changes/draft-search'), { recursive: true });
    regent('task', 'sync');
    expect(change(regent, 'draft-search')!.task.state).toBe('waiting');
    expect(regent('task', 'list').out).toMatch(/#1 {2}bez artefaktów — ai\/changes\/draft-search\/ zniknął bez archiwum/);
    expect(json(regent('task', 'list', '--json').out).attention.missing).toEqual([{ id: 1, change: 'draft-search' }]);
  });

  it('list pokazuje czas ostatniego sync, a przed pierwszym — nigdy', () => {
    const project = sddProject();
    const clock = { now: T0 };
    const regent = cli({ cwd: project, now: () => clock.now });
    regent('task', 'add', 'ręczne');
    expect(regent('task', 'list').out).toMatch(/\n\nOstatni sync: nigdy — zadania SDD mogą być nieaktualne \(regent task sync\)$/);
    regent('task', 'sync', '--source', 'hook');
    clock.now = T0 + 5 * MIN;
    expect(regent('task', 'list').out).toMatch(/\n\nOstatni sync: \d{4}-\d\d-\d\d \d\d:\d\d \(hook\)$/);
    expect(json(regent('task', 'list', '--json').out).attention.lastSync).toEqual({ at: new Date(T0).toISOString(), source: 'hook' });
    expect(cli()('task', 'list').out).not.toMatch(/sync/);
  });

  it('zmiana w toku z sync nie jest utknięta; task zmiany wzięty w sesji — tak', () => {
    const project = sddProject();
    const clock = { now: T0 };
    const regent = cli({ cwd: project, now: () => clock.now });
    regent('task', 'sync');
    clock.now = T0 + 120 * MIN;
    expect(regent('task', 'list').out).not.toMatch(/utknięte/);
  });

  it('--session-id z --transcript-path dopina transkrypt do zadań w toku tej sesji', () => {
    const project = gitProject();
    const agent = cli({ cwd: project, env: { CLAUDECODE: '1', CLAUDE_CODE_SESSION_ID: 'sesja-7' } });
    const hook = cli({ cwd: project, env: { REGENT_DB: agent.db } });
    agent('task', 'add', 'x');
    agent('task', 'take', '1');
    const r = hook('task', 'sync', '--session-id', 'sesja-7', '--transcript-path', '/t/sesja-7.jsonl');
    expect(r.out).toMatch(/^Brak ai\/changes\/ w .+ — nic do synchronizacji\.$/);
    expect(json(hook('task', 'show', '1', '--json').out).task).toMatchObject({ sessionId: 'sesja-7', transcriptPath: '/t/sesja-7.jsonl' });
    expect(hook('task', 'sync', '--transcript-path', '/t/x.jsonl').code).toBe(2);
    expect(hook('task', 'sync', 'coś').code).toBe(2);
  });

  it('błąd sdd-check.sh przerywa sync bez zapisu', () => {
    const project = sddProject();
    const db = openTaskDb(join(tempDir(), 'regent.db'));
    const store = new TaskStore(db, () => T0);
    expect(() => syncProject(store, project, { ctx: { actor: 'sync', source: 'test' }, script: join(project, 'brak.sh') })).toThrow(
      /sdd-check\.sh status: kod 127/,
    );
    expect(store.changes(project)).toEqual([]);
    expect(store.lastSync(project)).toBeUndefined();
    db.close();
  });
});
