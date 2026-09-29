import { describe, expect, it } from 'vitest';
import { firstTurn } from '../src/parse/firstturn.js';

// Syntetyczny transkrypt subagenta w kształcie rekordów Claude Code (jak fixture'y z spike'a).
const at = (s: number) => `2026-09-20T10:00:${String(s).padStart(2, '0')}.000Z`;
const usage = (input: number, write: number, read: number) => ({
  input_tokens: input,
  cache_creation_input_tokens: write,
  cache_read_input_tokens: read,
  output_tokens: 50,
});
const user = (s: number, content: unknown) => ({ type: 'user', timestamp: at(s), cwd: '/tmp/demo', isSidechain: true, message: { role: 'user', content } });
const assistant = (s: number, id: string, content: unknown[], u: object, stop: string | null = 'tool_use') => ({
  type: 'assistant',
  timestamp: at(s),
  isSidechain: true,
  message: { id, role: 'assistant', model: 'claude-sonnet-5', content, usage: u, stop_reason: stop },
});
const tool = (id: string, name: string, input: object) => ({ type: 'tool_use', id, name, input });
const result = (id: string, content: unknown) => ({ type: 'tool_result', tool_use_id: id, content });

const PROMPT = 'Zaimplementuj T-02 ze zmiany ai/changes/note-tags/. Najpierw przeczytaj tasks.md i design.md.';

const lines = (recs: object[]) => recs.map((r) => JSON.stringify(r));

const TRANSCRIPT = lines([
  user(0, PROMPT),
  // jedna odpowiedź w dwóch liniach (tekst + narzędzie) — usage liczone raz
  assistant(1, 'msg_1', [{ type: 'text', text: 'Czytam artefakty.' }], usage(10, 1000, 0)),
  assistant(1, 'msg_1', [tool('t1', 'Read', { file_path: '/tmp/demo/ai/changes/note-tags/design.md' })], usage(10, 1000, 0)),
  user(2, [result('t1', 'x'.repeat(700))]),
  assistant(3, 'msg_2', [tool('t2', 'Read', { file_path: '/tmp/demo/src/tags/service.ts' })], usage(5, 200, 1010)),
  user(4, [result('t2', 'y'.repeat(5000))]),
  assistant(5, 'msg_3', [tool('t3', 'Read', { file_path: '/tmp/demo/ai/changes/note-tags/specs/notes.md' })], usage(5, 1500, 1210)),
  user(6, [result('t3', [{ type: 'text', text: 'z'.repeat(350) }])]),
  assistant(7, 'msg_4', [tool('t4', 'Edit', { file_path: '/tmp/demo/src/tags/service.ts' })], usage(5, 300, 2710)),
  user(8, [result('t4', 'ok')]),
  assistant(
    9,
    'msg_5',
    [{ type: 'text', text: 'Gotowe.\n- `BRAK W PACZCE: design.md › Error Handling — kody błędów`\nBRAK W PACZCE: <plik> › <sekcja> — <po co>' }],
    usage(5, 100, 3010),
    'end_turn',
  ),
  { type: 'system', subtype: 'turn_duration', timestamp: at(10), durationMs: 9000 },
  // wznowienie (SendMessage) — druga tura nie wchodzi do metryki, raport z niej tak
  user(20, 'Popraw nazwę testu.'),
  assistant(21, 'msg_6', [{ type: 'text', text: 'BRAK W PACZCE: design.md › Testing Strategy — nazwy testów' }], usage(5, 100, 9000), 'end_turn'),
]);

describe('firstTurn — pierwsza tura subagenta', () => {
  const t = firstTurn(TRANSCRIPT)!;

  it('prompt, cwd i start z pierwszego rekordu', () => {
    expect(t.prompt).toBe(PROMPT);
    expect(t.cwd).toBe('/tmp/demo');
    expect(t.startedAt).toBe(Date.parse(at(0)));
  });

  it('wejście każdego wywołania API = input + zapis i odczyt cache, deduplikacja po message.id, do końca tury', () => {
    expect(t.calls).toEqual([1010, 1215, 2715, 3015, 3115]);
  });

  it('kontekst przy pierwszej edycji i bajty wyników Read plików zmiany', () => {
    expect(t.atFirstEdit).toBe(3015);
    expect(t.changeReadBytes).toBe(1050);
  });

  it('BRAK W PACZCE z odpowiedzi całego transkryptu, bez wzorca z promptu, bez formatowania', () => {
    expect(t.missing).toEqual(['design.md › Error Handling', 'design.md › Testing Strategy']);
  });

  it('bez promptu albo bez wywołań API — brak tury', () => {
    expect(firstTurn([])).toBeUndefined();
    expect(firstTurn(lines([user(0, PROMPT)]))).toBeUndefined();
    expect(firstTurn(['nie json', ...TRANSCRIPT.slice(0, 3)])?.calls).toEqual([1010]);
  });
});
