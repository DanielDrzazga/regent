import { describe, expect, it } from 'vitest';
import { applyLines, applyRecord, createState, parseTranscript } from '../src/parse/transcript.js';
import { ALPHA, BETA, LEAD, TEAM, readFixture } from './helpers.js';

describe('transkrypt leada', () => {
  const s = parseTranscript(readFixture(LEAD));

  it('deduplikuje usage po message.id (ta sama odpowiedź w dwóch liniach)', () => {
    const u = s.usage.get('claude-haiku-4-5-20251001|standard');
    expect(u).toEqual({ input: 15, cacheWrite5m: 0, cacheWrite1h: 1370, cacheRead: 4900, output: 150 });
    expect(s.seenMessages.size).toBe(5);
  });

  it('buduje oś zdarzeń: prompt, spawny, wiadomość, koniec tury', () => {
    expect(s.events.map((e) => [e.kind, e.text])).toEqual([
      ['prompt', 'Utwórz zespół: alpha i beta'],
      ['spawn', 'alpha (haiku)'],
      ['spawn', 'beta (haiku)'],
      ['message', '→ beta: Prośba o zamknięcie'],
      ['turn-end', 'koniec tury (23 s)'],
    ]);
  });

  it('pomija nieznane rekordy i liczy uszkodzone linie', () => {
    expect(s.invalidLines).toBe(1);
    expect(s.sessionId).toBe(LEAD);
    expect(s.agentName).toBeUndefined();
  });

  it('po końcu tury nie ma otwartych narzędzi', () => {
    expect(s.turnOpen).toBe(false);
    expect(s.pending.size).toBe(0);
    expect(s.closed).toBe(false);
  });
});

describe('transkrypt członka zespołu', () => {
  it('alpha: tożsamość, błąd narzędzia i Bash w toku', () => {
    const s = parseTranscript(readFixture(ALPHA));
    expect([s.agentName, s.teamName]).toEqual(['alpha', TEAM]);
    expect(s.problems).toEqual([{ ts: Date.parse('2026-01-01T10:00:08.000Z'), kind: 'tool', tool: 'Read', text: 'File does not exist.' }]);
    expect([...s.pending.values()].map((c) => `${c.name} ${c.summary}`)).toEqual(['Bash Uruchom testy']);
    expect(s.turnOpen).toBe(true);
    expect(s.events.find((e) => e.kind === 'tool')?.text).toBe('Read missing.txt');
  });

  it('beta: blokada hooka, koszt wg Claude Code, sesja zamknięta', () => {
    const s = parseTranscript(readFixture(BETA));
    expect(s.problems).toHaveLength(1);
    expect(s.problems[0]).toMatchObject({ kind: 'hook', hook: 'git-guard.sh', tool: 'Bash' });
    expect(s.problems[0]?.text).toMatch(/^SDD git-guard: git add całości/);
    expect(s.events.filter((e) => e.kind === 'error').map((e) => e.problem)).toEqual(['hook']);
    expect(s.costUSD).toBe(0.0123);
    expect(s.closed).toBe(true);
  });
});

describe('czytanie przyrostowe', () => {
  it('dwie porcje dają ten sam stan co całość', () => {
    const lines = readFixture(LEAD).split('\n');
    const whole = parseTranscript(lines.join('\n'));
    const inc = createState();
    applyLines(inc, lines.slice(0, 5));
    applyLines(inc, lines.slice(5));
    expect(inc.events).toEqual(whole.events);
    expect(inc.usage).toEqual(whole.usage);
  });

  it('wznowienie po cost-state otwiera sesję z powrotem', () => {
    const s = parseTranscript(readFixture(BETA));
    applyRecord(s, { type: 'user', timestamp: '2026-01-01T11:00:00.000Z', message: { role: 'user', content: 'Dalej' } });
    expect(s.closed).toBe(false);
    expect(s.turnOpen).toBe(true);
    expect(s.events.at(-1)).toMatchObject({ kind: 'prompt', text: 'Dalej' });
  });

  it('błąd API z rekordu <synthetic> trafia do problemów i zamyka turę', () => {
    const s = createState();
    applyRecord(s, {
      type: 'assistant',
      timestamp: '2026-01-01T10:00:00.000Z',
      isApiErrorMessage: true,
      error: 'rate_limit',
      message: { id: 'x', model: '<synthetic>', content: [{ type: 'text', text: 'API Error: Rate limit reached' }] },
    });
    expect(s.problems).toEqual([{ ts: Date.parse('2026-01-01T10:00:00.000Z'), kind: 'api', tool: 'API', text: 'API Error: Rate limit reached' }]);
    expect(s.usage.size).toBe(0);
    expect(s.turnOpen).toBe(false);
  });

  it('komenda z ukośnikiem jako prompt, wstawki systemowe pominięte', () => {
    const s = createState();
    applyRecord(s, { type: 'user', message: { content: '<command-name>/regent:status</command-name>' } });
    applyRecord(s, { type: 'user', message: { content: '<system-reminder>x</system-reminder>' } });
    applyRecord(s, { type: 'user', isMeta: true, message: { content: 'meta' } });
    expect(s.events.map((e) => e.text)).toEqual(['/regent:status']);
  });
});
