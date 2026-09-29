import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { activeChanges, sddStatus } from '../src/sdd.js';
import { countTasks, parseReqRefs, parseTaskLines, parseTasks } from '../src/tasksmd.js';
import { FIXTURES, sddProject, write } from './helpers.js';

/** Przypadki brzegowe TASK_AWK: bloki kodu obu rodzajów, CRLF, tabulator, wcięcia, [X], [~], [], [✓], NOBOX. */
const TRICKY = [
  '# Tasks: tricky',
  '',
  '- [ ] T-01: przed pierwszą grupą',
  '## Setup',
  '- [X] T-02: duże X\r',
  '\t- [ ] T-03: wcięte tabulatorem',
  '    - [~] T-04: w trakcie',
  '### Podgrupa (nie zmienia grupy)',
  '- [] T-05: puste pole',
  '```',
  '- [ ] T-90: w bloku kodu',
  '~~~',
  '- [ ] T-91: poza blokiem — awk przełącza na ``` i ~~~ bez rozróżnienia',
  '```text',
  '- [ ] T-92: w bloku z językiem',
  '```',
  '- [x] T-06: po bloku',
  '## Implementation',
  '* T-07 bez checkboxa',
  '- T-08 też bez checkboxa',
  '- [✓] T-09 znak spoza ASCII',
  '- [ ]T-10 bez spacji po polu',
  '  ~~~text',
  '- [ ] T-93: w bloku tyldowym z wcięciem',
  '  ~~~',
  '- [x] zwykła linia bez ID',
  '',
].join('\n');

describe('parser tasks.md — semantyka TASK_AWK', () => {
  it('stany, grupy, bloki kodu i linie jak w awk', () => {
    const lines = parseTaskLines(TRICKY);
    expect(lines.map((l) => [l.id, l.box, l.group])).toEqual([
      ['T-01', 'TODO', ''],
      ['T-02', 'DONE', 'Setup'],
      ['T-03', 'TODO', 'Setup'],
      ['T-04', 'BADBOX', 'Setup'],
      ['T-05', 'BADBOX', 'Setup'],
      ['T-91', 'TODO', 'Setup'],
      ['T-06', 'DONE', 'Setup'],
      ['T-07', 'NOBOX', 'Implementation'],
      ['T-08', 'NOBOX', 'Implementation'],
      ['T-10', 'TODO', 'Implementation'],
      ['', 'DONE', 'Implementation'],
    ]);
    expect(lines[1]).toMatchObject({ line: 5, text: '- [X] T-02: duże X' });
    expect(countTasks(lines)).toEqual({ done: 3, total: 9 });
  });

  it('liczniki zgodne z sdd-check.sh status na fixture’ach i przypadkach brzegowych', () => {
    const project = sddProject();
    write(project, 'ai/changes/tricky/proposal.md', '| Status | Approved |\n');
    write(project, 'ai/changes/tricky/tasks.md', TRICKY);
    const script = sddStatus(project);
    expect(script.map((s) => s.name)).toEqual(activeChanges(project));
    for (const s of script) {
      const text = readFileSync(join(project, 'ai/changes', s.name, 'tasks.md'), 'utf8');
      expect(countTasks(parseTaskLines(text)), s.name).toEqual({ done: s.done, total: s.total });
    }
    expect(script.find((s) => s.name === 'tricky')).toMatchObject({ done: 3, total: 9 });
  });
});

describe('rozbiór linii taska', () => {
  it('nowy format: klucz, tag, tytuł, REQ/AC, pliki, weryfikacja, zależności, design, ślad', () => {
    const tasks = parseTasks(readFileSync(join(FIXTURES, 'ai/changes/note-tags/tasks.md'), 'utf8'));
    expect(tasks.map((t) => [t.key, t.tag, t.title, t.done])).toEqual([
      ['T-01', 'DB', 'Migracja: tabela note_tags', true],
      ['T-02', 'BE', 'Serwis tagów', false],
      ['T-03', 'BE', 'Filtr GET /notes?tag', false],
      ['T-04', 'FE', 'Tagi na liście notatek', false],
      ['T-05', null, 'Indeks tagów', false],
      ['T-06', 'BE', 'E2E tagów', false],
    ]);
    expect(tasks[0]!.refs).toMatchObject({
      group: 'Setup',
      reqs: [{ req: 'REQ-004', ac: null }],
      files: 'migrations/004_note_tags.sql',
      verify: 'migracja up/down/up',
      commit: '1a2b3c4',
      tests: 'REQ-004 → test/migrations.test.ts › note_tags up/down',
    });
    expect(tasks[1]!.refs).toMatchObject({
      group: 'Implementation',
      reqs: [{ req: 'REQ-004', ac: ['AC-1', 'AC-2', 'AC-3'] }],
      verify: 'testy REQ-004/AC-1..3 zielone',
      after: ['T-01'],
      commit: null,
    });
    expect(tasks[3]!.refs).toMatchObject({
      reqs: [
        { req: 'REQ-002', ac: ['AC-2'] },
        { req: 'REQ-005', ac: ['AC-2'] },
      ],
      design: ['Observability'],
    });
    expect(tasks[5]!.refs).toMatchObject({ group: 'Integracja / E2E', after: ['T-03', 'T-04'], reqs: [{ req: 'REQ-004', ac: null }, { req: 'REQ-005', ac: null }] });
  });

  it('starszy format bez T-NN: klucz #<n> wg kolejności; powtórzone ID też dostaje #<n>', () => {
    const legacy = parseTasks(readFileSync(join(FIXTURES, 'ai/changes/legacy-export/tasks.md'), 'utf8'));
    expect(legacy.map((t) => [t.key, t.title, t.done])).toEqual([
      ['#1', 'Eksport notatek do CSV', true],
      ['#2', 'Eksport do Markdown', false],
      ['#3', 'Przycisk eksportu w UI', false],
      ['#4', 'Opis eksportu w pomocy', false],
    ]);
    const dup = parseTasks('- [ ] T-01: a\n- [ ] T-01: b\n- [ ] c\n');
    expect(dup.map((t) => t.key)).toEqual(['T-01', '#2', '#3']);
  });

  it('REQ/AC jak w sdd-check: lista, zakres, sam REQ wygrywa z listą', () => {
    expect(parseReqRefs('REQ-001/AC-1, AC-3 i REQ-002/AC-1..3')).toEqual([
      { req: 'REQ-001', ac: ['AC-1', 'AC-3'] },
      { req: 'REQ-002', ac: ['AC-1', 'AC-2', 'AC-3'] },
    ]);
    expect(parseReqRefs('REQ-001/AC-2 — REQ-001 — REQ-001/AC-3')).toEqual([{ req: 'REQ-001', ac: null }]);
    expect(parseReqRefs('bez REQ: konfiguracja')).toEqual([]);
  });
});
