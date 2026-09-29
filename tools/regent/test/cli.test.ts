import { existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { cli, gitProject, tempDir } from './helpers.js';

const json = <T = any>(text: string): T => JSON.parse(text) as T;

describe('regent — użycie', () => {
  it('--help na stdout, kod 0; pomoc grupy task', () => {
    const r = cli()('--help');
    expect(r.code).toBe(0);
    expect(r.out).toMatch(/^regent — /);
    expect(cli()('task', '--help').out).toMatch(/regent task add/);
  });

  it('bez polecenia albo z nieznanym — pomoc na stderr, kod 2', () => {
    expect(cli()().code).toBe(2);
    const r = cli()('foo');
    expect(r.code).toBe(2);
    expect(r.err).toMatch(/nieznane polecenie: foo/);
    expect(cli()('task', 'foo').code).toBe(2);
  });

  it('błędne użycie — kod 2 i komunikat', () => {
    const regent = cli();
    const cases: [string[], RegExp][] = [
      [['task', 'add'], /tytuł/],
      [['task', 'add', 'x', '--owner', 'szef'], /nieznany właściciel/],
      [['task', 'take'], /id zadania/],
      [['task', 'take', 'abc'], /id zadania/],
      [['task', 'take', '7'], /nie ma zadania #7/],
      [['task', 'take', '1', '--reason', 'x'], /reason/],
      [['task', 'handoff', '1'], /właściciel/],
      [['task', 'done', '1'], /--reason/],
      [['task', 'drop', '1', '--reason', '  '], /--reason/],
      [['task', 'show', '1', '2'], /jedno id/],
    ];
    for (const [argv, message] of cases) {
      const r = regent(...argv);
      expect(r.code, argv.join(' ')).toBe(2);
      expect(r.err, argv.join(' ')).toMatch(message);
    }
  });

  it('baza nie do otwarcia — kod 4, jedna linia bez stosu', () => {
    const r = cli({ env: { REGENT_DB: tempDir() } })('task', 'add', 'x');
    expect(r.code).toBe(4);
    expect(r.err).toMatch(/^regent: błąd: [^\n]+$/);
  });
});

describe('regent task — scenariusz', () => {
  it('add → take → handoff me → done --reason, historia w show', () => {
    const regent = cli();
    const add = regent('task', 'add', 'Przejrzeć', 'PR');
    expect(add).toMatchObject({ code: 0, err: '' });
    expect(add.out).toBe('#1 Przejrzeć PR — oczekuje (me)');
    expect(regent('task', 'take', '1').out).toBe('#1 Przejrzeć PR — w toku (me)');
    expect(regent('task', 'handoff', '#1', 'me', '--reason', 'decyzja o API').out).toBe('#1 Przejrzeć PR — czeka na Ciebie (me)');
    expect(regent('task', 'done', '1', '--reason', 'scalone').out).toBe('#1 Przejrzeć PR — zakończone (me)');

    const show = regent('task', 'show', '1');
    expect(show.code).toBe(0);
    expect(show.out).toMatch(/^#1 Przejrzeć PR\n/);
    expect(show.out).toMatch(/stan: +zakończone \(me\)/);
    expect(show.out).toMatch(/powód: +scalone/);
    const history = show.out.split('Historia:\n')[1]!.split('\n');
    expect(history).toHaveLength(4);
    expect(history.map((l) => l.replace(/^ +\S+ \S+ +/, ''))).toEqual([
      'oczekuje         me  me/cli',
      'w toku           me  me/cli',
      'czeka na Ciebie  me  me/cli — decyzja o API',
      'zakończone       me  me/cli — scalone',
    ]);
  });

  it('niedozwolone przejście — kod 1 z listą możliwych, stan bez zmian', () => {
    const regent = cli();
    regent('task', 'add', 'x');
    regent('task', 'take', '1');
    const again = regent('task', 'take', '1');
    expect(again.code).toBe(1);
    expect(again.err).toBe(
      'regent: #1 jest „w toku” — take niedozwolone. Możliwe: handoff me (czeka na Ciebie), handoff agent (przekazane), done (zakończone), drop (porzucone).',
    );
    regent('task', 'drop', '1', '--reason', 'nieaktualne');
    const closed = regent('task', 'handoff', '1', 'agent');
    expect(closed.code).toBe(1);
    expect(closed.err).toMatch(/„porzucone” — handoff agent niedozwolone\. Możliwe: nic — stan końcowy\./);
    expect(regent('task', 'show', '1', '--json').code).toBe(0);
    expect(json(regent('task', 'show', '1', '--json').out).task.state).toBe('dropped');
  });

  it('handoff agent → przekazane; zakończyć można dopiero po wzięciu', () => {
    const project = gitProject();
    const regent = cli({ cwd: project });
    const agent = cli({ cwd: project, env: { REGENT_DB: regent.db, CLAUDECODE: '1' } });
    regent('task', 'add', 'x');
    expect(regent('task', 'handoff', '1', 'agent').out).toBe('#1 x — przekazane (agent)');
    expect(agent('task', 'done', '1', '--reason', 'r').code).toBe(1);
    expect(agent('task', 'take', '1').out).toBe('#1 x — w toku (agent)');
    expect(agent('task', 'done', '1', '--reason', 'r').out).toBe('#1 x — zakończone (agent)');
  });
});

describe('regent task — kto i gdzie', () => {
  it('w sesji Claude Code aktorem jest agent, a take zapisuje sesję z CLAUDE_CODE_SESSION_ID', () => {
    const project = gitProject();
    const me = cli({ cwd: project });
    const agent = cli({ cwd: project, env: { REGENT_DB: me.db, CLAUDECODE: '1', CLAUDE_CODE_SESSION_ID: 'sesja-1' } });
    agent('task', 'add', 'x');
    const taken = json(agent('task', 'take', '1', '--json').out);
    expect(taken).toMatchObject({ owner: 'agent', state: 'in_progress', sessionId: 'sesja-1' });
    expect(json(me('task', 'show', '1', '--json').out).history.map((t: { actor: string }) => t.actor)).toEqual(['agent', 'agent']);
    expect(json(me('task', 'add', 'y', '--owner', 'agent', '--json').out)).toMatchObject({ owner: 'agent' });
  });

  it('projekt to korzeń gita — z podkatalogu ten sam, z innego repo osobny', () => {
    const project = gitProject();
    const sub = join(project, 'src', 'deep');
    mkdirSync(sub, { recursive: true });
    const root = cli({ cwd: project });
    const fromSub = cli({ cwd: sub, env: { REGENT_DB: root.db } });
    const other = cli({ cwd: gitProject(), env: { REGENT_DB: root.db } });
    root('task', 'add', 'x');
    expect(json(fromSub('task', 'list', '--json').out)).toMatchObject({ project, tasks: [{ id: 1 }] });
    expect(json(other('task', 'list', '--json').out).tasks).toEqual([]);
    expect(other('task', 'list').out).toMatch(/^Brak otwartych zadań w /);
  });
});

describe('regent task list i show', () => {
  it('list: otwarte, --all dokłada zamknięte z powodem; --json', () => {
    const regent = cli();
    regent('task', 'add', 'pierwsze');
    regent('task', 'add', 'drugie');
    regent('task', 'take', '2');
    regent('task', 'add', 'trzecie');
    regent('task', 'done', '3', '--reason', 'zrobione ręcznie');

    const open = regent('task', 'list');
    expect(open.code).toBe(0);
    const lines = open.out.split('\n');
    expect(lines[0]).toMatch(/ — otwarte: 2$/);
    expect(lines.slice(2)).toEqual(['  #1  oczekuje  me  pierwsze', '  #2  w toku    me  drugie']);

    const all = regent('task', 'list', '--all').out.split('\n');
    expect(all[0]).toMatch(/ — wszystkie: 3$/);
    expect(all.at(-1)).toBe('  #3  zakończone  me  trzecie — zrobione ręcznie');

    const data = json(regent('task', 'list', '--all', '--json').out);
    expect(data.tasks.map((t: { id: number; state: string }) => [t.id, t.state])).toEqual([
      [1, 'pending'],
      [2, 'in_progress'],
      [3, 'done'],
    ]);
  });

  it('brak bazy to komunikat, nie pusta lista — i odczyt nie zakłada bazy', () => {
    const regent = cli();
    const list = regent('task', 'list');
    expect(list.code).toBe(0);
    expect(list.out).toMatch(/^Brak bazy zadań \(.+regent\.db\) — nic jeszcze nie zapisano\.$/);
    expect(json(regent('task', 'list', '--json').out)).toMatchObject({ tasks: [], db: null });
    expect(regent('task', 'show', '1').code).toBe(2);
    expect(existsSync(regent.db)).toBe(false);
  });

  it('show --json: zadanie i historia', () => {
    const regent = cli();
    regent('task', 'add', 'x');
    const data = json(regent('task', 'show', '1', '--json').out);
    expect(data.task).toMatchObject({ id: 1, title: 'x', kind: 'manual' });
    expect(data.history).toMatchObject([{ state: 'pending', actor: 'me', source: 'cli' }]);
  });
});
