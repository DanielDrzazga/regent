import { describe, expect, it } from 'vitest';
import { contextWindow } from '../src/parse/pricing.js';
import { applyRecord, createState, parseTranscript } from '../src/parse/transcript.js';
import { SessionStore } from '../src/store.js';
import { CTX_CRIT, CTX_WARN, STUCK_MS, healthOf } from '../src/view.js';
import { LEAD, claudeDirCopy, projectFile } from './helpers.js';

const NOW = Date.parse('2026-01-01T10:00:39.000Z');

const view = () => {
  const dir = claudeDirCopy();
  const s = new SessionStore({ claudeDir: dir, leadFile: projectFile(dir, LEAD), discoveryMs: 0 });
  s.refresh(NOW);
  return s.view(NOW);
};

const withContext = (tokens: number) => {
  const s = createState();
  applyRecord(s, {
    type: 'assistant',
    timestamp: '2026-01-01T10:00:00.000Z',
    message: { id: 'm', model: 'claude-opus-5-5', stop_reason: 'end_turn', usage: { input_tokens: 0, cache_read_input_tokens: tokens, output_tokens: 1 } },
  });
  return s;
};

describe('kontekst', () => {
  it('okno wg modelu: Haiku 200k, pozostałe 1M, nieznany — brak', () => {
    expect(contextWindow('claude-haiku-4-5-20251001')).toBe(200_000);
    expect(contextWindow('claude-opus-5-5')).toBe(1_000_000);
    expect(contextWindow('gpt-x')).toBeUndefined();
  });

  it('kontekst to wejście + zapis i odczyt cache ostatniego wywołania', () => {
    const s = parseTranscript(
      [
        { type: 'assistant', message: { id: 'a', model: 'claude-haiku-4-5', stop_reason: 'tool_use', usage: { input_tokens: 5, cache_creation_input_tokens: 100, cache_read_input_tokens: 0, output_tokens: 9 } } },
        { type: 'assistant', message: { id: 'b', model: 'claude-haiku-4-5', stop_reason: 'end_turn', usage: { input_tokens: 2, cache_creation_input_tokens: 10, cache_read_input_tokens: 105, output_tokens: 3 } } },
      ]
        .map((r) => JSON.stringify(r))
        .join('\n'),
    );
    expect(s.context).toBe(117);
  });
});

describe('healthOf', () => {
  it('progi kontekstu jak statusline', () => {
    expect(healthOf(withContext(CTX_WARN - 1), 'czeka', 1_000_000, NOW).level).toBe('ok');
    expect(healthOf(withContext(CTX_WARN), 'czeka', 1_000_000, NOW)).toEqual({ level: 'uwaga', issues: [{ level: 'uwaga', text: 'kontekst 150k — obserwuj' }] });
    expect(healthOf(withContext(CTX_CRIT), 'czeka', 1_000_000, NOW).issues[0]?.text).toBe('kontekst 250k — czas na /clear');
    expect(healthOf(withContext(185_000), 'czeka', 200_000, NOW).level).toBe('problem'); // 92% okna Haiku
  });

  it('zamknięty agent nie ma problemów zdrowia', () => {
    expect(healthOf(withContext(CTX_CRIT), 'zamknięty', 1_000_000, NOW)).toEqual({ level: 'ok', issues: [] });
  });

  it('narzędzie bez wyniku dłużej niż 10 min', () => {
    const s = createState();
    applyRecord(s, {
      type: 'assistant',
      timestamp: '2026-01-01T10:00:00.000Z',
      message: { id: 'm', model: 'claude-haiku-4-5', stop_reason: 'tool_use', content: [{ type: 'tool_use', id: 't', name: 'Bash', input: { command: 'make test' } }] },
    });
    const start = Date.parse('2026-01-01T10:00:00.000Z');
    expect(healthOf(s, 'pracuje', 200_000, start + STUCK_MS - 1).level).toBe('ok');
    expect(healthOf(s, 'pracuje', 200_000, start + 12 * 60_000).issues).toEqual([{ level: 'uwaga', text: 'Bash trwa 12 min' }]);
  });

  it('świeże blokady hooka, błędy API i ponowienia', () => {
    const s = createState();
    applyRecord(s, {
      type: 'user',
      timestamp: '2026-01-01T10:00:00.000Z',
      message: { content: [{ type: 'tool_result', tool_use_id: 'x', is_error: true, content: 'PreToolUse:Bash hook error: [bash /h/git-guard.sh]: nie' }] },
    });
    applyRecord(s, { type: 'system', subtype: 'api_error', retryAttempt: 1, maxRetries: 10, timestamp: '2026-01-01T10:00:01.000Z' });
    applyRecord(s, {
      type: 'assistant',
      isApiErrorMessage: true,
      timestamp: '2026-01-01T10:00:02.000Z',
      message: { id: 'e', model: '<synthetic>', content: [{ type: 'text', text: 'API Error' }] },
    });
    const h = healthOf(s, 'czeka', 200_000, NOW);
    expect(h.level).toBe('problem');
    expect(h.issues.map((i) => i.text)).toEqual(['błąd API ×1', 'blokada hooka git-guard.sh ×1', 'ponowienia API ×1']);
    expect(healthOf(s, 'czeka', 200_000, NOW + 31 * 60_000).level).toBe('ok'); // po 30 min problemy wygasają
  });
});

describe('buildView — rozszerzenia', () => {
  it('kolor i panel członka z wyniku spawnu, także po zniknięciu z config.json', () => {
    const v = view();
    const beta = v.rows.find((r) => r.name === 'beta');
    expect(beta).toMatchObject({ color: 'green', paneId: '%2', status: 'zamknięty', exactCost: 0.0123 });
    expect(v.rows.find((r) => r.name === 'alpha')).toMatchObject({ color: 'blue', paneId: '%1', contextWindow: 200_000 });
  });

  it('krawędzie grafu: spawn z wiadomościami, subagent; wiadomości między członkami osobno', () => {
    const v = view();
    const key = (name: string) => v.rows.find((r) => r.name === name)?.key;
    expect(v.edges).toEqual([
      { from: key('lead'), to: key('alpha'), kind: 'spawn', down: 0, up: 0 },
      { from: key('lead'), to: key('beta'), kind: 'spawn', down: 1, up: 1 },
      { from: key('lead'), to: key('lead›Explore'), kind: 'subagent', down: 0, up: 0 },
    ]);
    expect(v.sideMessages).toEqual([{ from: 'alpha', to: 'beta', count: 1 }]);
  });

  it('przegląd: statusy, modele, narzędzia, wiadomości, problemy', () => {
    const o = view().overview;
    expect(o.statusCounts).toEqual({ pracuje: 1, myśli: 0, czeka: 1, zakończony: 1, zamknięty: 1 });
    expect(o.byModel.map((m) => m.model)).toEqual(['haiku-4-5', 'sonnet-5']);
    expect(o.tools.slice(0, 3)).toEqual([
      { name: 'SendMessage', calls: 3, errors: 0 },
      { name: 'Agent', calls: 2, errors: 0 },
      { name: 'Bash', calls: 2, errors: 1 },
    ]);
    expect([o.messages, o.spawns]).toEqual([3, 2]);
    expect(o.problemsByKind).toEqual({ hook: 1, permission: 0, tool: 1, api: 0 });
    expect(o.start).toBe(Date.parse('2026-01-01T10:00:00.000Z'));
  });
});
