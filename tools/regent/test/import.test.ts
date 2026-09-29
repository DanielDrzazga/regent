import { renameSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { cli, edit, sddProject } from './helpers.js';

const json = <T = any>(text: string): T => JSON.parse(text) as T;

interface Row {
  id: number;
  key: string;
  parentId: number | null;
  tag: string | null;
  title: string;
  owner: string;
  state: string;
  closureReason: string | null;
  refs: Record<string, any>;
}

function setup() {
  const project = sddProject();
  const regent = cli({ cwd: project });
  const all = (): Row[] => json(regent('task', 'list', '--all', '--json').out).tasks;
  const change = (name: string) => all().find((t) => t.key === `sdd:${name}`)!;
  /** Taski zmiany po kluczu: `task('note-tags', 'T-02')`. */
  const task = (name: string, key: string) => {
    const parent = change(name);
    return all().find((t) => t.parentId === parent.id && t.key === key)!;
  };
  const history = (id: number) => json(regent('task', 'show', String(id), '--json').out).history as { state: string; reason: string }[];
  const tasksFile = (name: string) => `ai/changes/${name}/tasks.md`;
  return { project, regent, all, change, task, history, tasksFile };
}

describe('import tasków z tasks.md', () => {
  it('przy Approved: dzieci zmiany z kluczem, tagiem, refs i stanem z checkboxa; szkic bez importu', () => {
    const { regent, all, change, task } = setup();
    regent('task', 'sync');
    const noteTags = change('note-tags');
    const children = all().filter((t) => t.parentId === noteTags.id);
    expect(children.map((t) => [t.key, t.tag, t.state, t.owner])).toEqual([
      ['T-01', 'DB', 'done', 'agent'],
      ['T-02', 'BE', 'pending', 'agent'],
      ['T-03', 'BE', 'pending', 'agent'],
      ['T-04', 'FE', 'pending', 'agent'],
      ['T-05', null, 'pending', 'agent'],
      ['T-06', 'BE', 'pending', 'agent'],
    ]);
    expect(task('note-tags', 'T-01').closureReason).toBe('odhaczone w tasks.md (commit: 1a2b3c4)');
    expect(task('note-tags', 'T-04').refs).toMatchObject({ after: ['T-01'], design: ['Observability'], files: 'web/NoteList.tsx' });
    expect(all().filter((t) => t.parentId === change('legacy-export').id).map((t) => [t.key, t.state])).toEqual([
      ['#1', 'done'],
      ['#2', 'pending'],
      ['#3', 'pending'],
      ['#4', 'pending'],
    ]);
    expect(all().filter((t) => t.parentId === change('draft-search').id)).toEqual([]);
    const list = regent('task', 'list').out;
    expect(list).toMatch(/\n {4}#9 +oczekuje +agent +T-02 \[BE\] Serwis tagów\n/);
    expect(list).toMatch(/\n {4}#4 +oczekuje +agent +2\. Eksport do Markdown\n/);
  });

  it('Draft → Approved zakłada taski; bez zmiany pliku drugi sync niczego nie importuje', () => {
    const { project, regent, all, change } = setup();
    regent('task', 'sync');
    edit(project, 'ai/changes/draft-search/proposal.md', (t) => t.replace('| Status | Draft |', '| Status | Approved |'));
    regent('task', 'sync');
    expect(all().filter((t) => t.parentId === change('draft-search').id).map((t) => [t.key, t.title, t.state])).toEqual([
      ['T-01', 'Indeks pełnotekstowy', 'pending'],
    ]);
    expect(json(regent('task', 'sync', '--json').out)).toMatchObject({ checked: false, events: [] });
  });

  it('ponowny import po zmianie pliku: nowa linia, nowa treść; linia bez zmian — decyduje baza', () => {
    const { project, regent, task, tasksFile } = setup();
    regent('task', 'sync');
    const t02 = task('note-tags', 'T-02');
    expect(regent('task', 'take', String(t02.id)).code).toBe(0);
    edit(project, tasksFile('note-tags'), (t) =>
      t
        .replace('Filtr GET /notes?tag', 'Filtr GET /notes?tag=x')
        .replace('## Integracja / E2E', '- [ ] T-07: [BE] Limit tagów — REQ-004/AC-3 — pliki: src/tags/limit.ts — weryfikacja: test limitu (po T-02)\n\n## Integracja / E2E'),
    );
    regent('task', 'sync');
    expect(task('note-tags', 'T-02').state).toBe('in_progress');
    expect(task('note-tags', 'T-03')).toMatchObject({ title: 'Filtr GET /notes?tag=x', state: 'pending' });
    expect(task('note-tags', 'T-07')).toMatchObject({ tag: 'BE', state: 'pending', refs: { after: ['T-02'], group: 'Implementation' } });
  });

  it('ręczna zmiana linii wygrywa: [x] kończy, odznaczenie otwiera ponownie', () => {
    const { project, regent, task, history, tasksFile } = setup();
    regent('task', 'sync');
    regent('task', 'take', String(task('note-tags', 'T-02').id));
    edit(project, tasksFile('note-tags'), (t) => t.replace('- [ ] T-02', '- [x] T-02').replace('- [x] T-01', '- [ ] T-01'));
    regent('task', 'sync');
    const t02 = task('note-tags', 'T-02');
    expect(t02).toMatchObject({ state: 'done', closureReason: 'odhaczone w tasks.md' });
    expect(history(t02.id).map((h) => h.state)).toEqual(['pending', 'in_progress', 'done']);
    const t01 = task('note-tags', 'T-01');
    expect(t01).toMatchObject({ state: 'pending', closureReason: null });
    expect(history(t01.id).map((h) => [h.state, h.reason])).toEqual([
      ['done', 'odhaczone w tasks.md (commit: 1a2b3c4)'],
      ['pending', 'odznaczone w tasks.md'],
    ]);
  });

  it('task usunięty z pliku → porzucone z powodem; gdy wróci — ponowne otwarcie', () => {
    const { project, regent, task, history, tasksFile } = setup();
    regent('task', 'sync');
    let removed = '';
    edit(project, tasksFile('note-tags'), (t) => {
      removed = t.split('\n').find((l) => l.startsWith('- [ ] T-05'))!;
      return t.replace(`${removed}\n`, '');
    });
    regent('task', 'sync');
    expect(task('note-tags', 'T-05')).toMatchObject({ state: 'dropped', closureReason: 'usunięty z tasks.md' });
    edit(project, tasksFile('note-tags'), (t) => t.replace('## Integracja / E2E', `${removed}\n\n## Integracja / E2E`));
    regent('task', 'sync');
    const t05 = task('note-tags', 'T-05');
    expect(t05.state).toBe('pending');
    expect(history(t05.id).map((h) => [h.state, h.reason])).toEqual([
      ['pending', 'z tasks.md'],
      ['dropped', 'usunięty z tasks.md'],
      ['pending', 'wrócił do tasks.md'],
    ]);
  });

  it('[x] przy tasku przekazanym — tabela nie pozwala, stan zostaje, rozjazd w Uwadze', () => {
    const { project, regent, task, tasksFile } = setup();
    regent('task', 'sync');
    const t03 = task('note-tags', 'T-03');
    regent('task', 'handoff', String(t03.id), 'agent');
    edit(project, tasksFile('note-tags'), (t) => t.replace('- [ ] T-03', '- [x] T-03'));
    regent('task', 'sync');
    expect(task('note-tags', 'T-03').state).toBe('handed_off');
    expect(regent('task', 'list').out).toMatch(new RegExp(`#${t03.id} +rozjazd z artefaktami — wynika z nich „zakończone”, zadanie jest „przekazane”`));
  });

  it('zamknięcie zmiany: ostatni import z archiwum, otwarte taski porzucone z powodem', () => {
    const { project, regent, task, change, tasksFile } = setup();
    regent('task', 'sync');
    edit(project, tasksFile('note-tags'), (t) => t.replace('- [ ] T-02', '- [x] T-02'));
    renameSync(join(project, 'ai/changes/note-tags'), join(project, 'ai/changes/archive/2026-09-29-note-tags'));
    edit(project, 'ai/changes/legacy-export/proposal.md', (t) => t.replace('**Status:** Approved', '**Status:** Rejected'));
    regent('task', 'sync');

    expect(change('note-tags').state).toBe('done');
    expect(task('note-tags', 'T-02')).toMatchObject({ state: 'done', closureReason: 'odhaczone w tasks.md' });
    expect(task('note-tags', 'T-03')).toMatchObject({
      state: 'dropped',
      closureReason: 'zmiana zakończona bez tego taska (archiwum: 2026-09-29-note-tags)',
    });
    expect(change('legacy-export').state).toBe('dropped');
    expect(task('legacy-export', '#2')).toMatchObject({ state: 'dropped', closureReason: 'zmiana porzucona (Status: Rejected)' });
    expect(task('legacy-export', '#1').state).toBe('done');
    expect(json(regent('task', 'list', '--json').out).tasks).toEqual(
      expect.not.arrayContaining([expect.objectContaining({ key: 'sdd:note-tags' })]),
    );
  });
});
