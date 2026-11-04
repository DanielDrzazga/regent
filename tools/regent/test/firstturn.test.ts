import { describe, expect, it } from 'vitest';
import { bashWrites, firstTurn, missingKeys } from '../src/parse/firstturn.js';

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

  it('cały agent: wywołania wszystkich tur i wiadomość po prompcie', () => {
    expect(t.allCalls).toEqual([1010, 1215, 2715, 3015, 3115, 9105]);
    expect(t.messages).toBe(1);
  });

  it('bez nagłówka paczki — bez paczki; nagłówek w prompcie — paczka z promptu', () => {
    expect(t.packet).toBeUndefined();
    const inPrompt = firstTurn([JSON.stringify(user(0, `${PROMPT}\n\n# Paczka: note-tags — T-02`)), ...TRANSCRIPT.slice(1, 3)]);
    expect(inPrompt?.packet).toBe('prompt');
  });
});

// Paczka z pliku, odczyt i zapis przez Bash, raport przez SubagentHandback — jak w tygodniu sprawdzenia.
const PACKET_FILE = '/tmp/scratch/packet-t02.md';
const HANDBACK = 'SubagentHandback';
const VIA_TOOLS = lines([
  user(0, `Implementujesz T-02 zmiany ai/changes/note-tags/. Przeczytaj paczkę: ${PACKET_FILE}`),
  assistant(1, 'msg_1', [tool('t1', 'Read', { file_path: PACKET_FILE })], usage(10, 1000, 0)),
  user(2, [result('t1', '1\t# Paczka: note-tags — T-02\n2\t\n3\tŹródło: ai/changes/note-tags/')]),
  assistant(3, 'msg_2', [tool('t2', 'Bash', { command: "cd /tmp/demo/ai/changes/note-tags && grep -n '^#' design.md | head -40" })], usage(5, 200, 1010)),
  user(4, [result('t2', 'd'.repeat(140))]),
  assistant(5, 'msg_3', [tool('t3', 'Bash', { command: 'sed -n 1,40p src/tags/service.ts 2>&1 | head' })], usage(5, 300, 1210)),
  user(6, [result('t3', 'e'.repeat(900))]),
  assistant(7, 'msg_4', [tool('t4', 'Bash', { command: "mkdir -p src/tags && cat > src/tags/tag.ts <<'EOF'\nexport const a = 1 > 0;\nEOF" })], usage(5, 400, 1510)),
  user(8, [result('t4', '')]),
  assistant(9, 'msg_5', [tool('t5', 'Edit', { file_path: '/tmp/demo/src/tags/service.ts' })], usage(5, 100, 1910)),
  user(10, [result('t5', 'ok')]),
  assistant(
    11,
    'msg_6',
    [tool('t6', HANDBACK, { message: '## Pliki\n- src/tags/tag.ts\n\n## BRAK W PACZCE\n- `design.md › Struktura modułów` — układ katalogów\n- Brak innych.\n\n## OPEN QUESTIONS\n- design.md › nie dotyczy' })],
    usage(5, 100, 2010),
    'end_turn',
  ),
]);

describe('firstTurn — paczka z pliku, Bash i raport przez SubagentHandback', () => {
  const t = firstTurn(VIA_TOOLS)!;

  it('paczka z wyniku narzędzia (Read z numerami linii)', () => {
    expect(t.packet).toBe('tool');
  });

  it('odczyt pliku zmiany przez Bash liczony, inne polecenia nie', () => {
    expect(t.changeReadBytes).toBe(140);
  });

  it('pierwsza edycja: zapis heredokiem w Bash', () => {
    expect(t.atFirstEdit).toBe(1915);
  });

  it('BRAK W PACZCE spod nagłówka w SubagentHandback, bez „Brak” i bez innych sekcji', () => {
    expect(t.missing).toEqual(['design.md › Struktura modułów']);
  });
});

// Agent prowadzony przez SendMessage: raport przez SubagentHandback bez end_turn, kolejne taski jako
// meta-rekordy „The coordinator sent a message…”, po drodze meta-rekordy, które wiadomościami nie są.
const meta = (s: number, text: string) => ({ ...user(s, text), isMeta: true });
const CONTINUED = lines([
  user(0, PROMPT),
  meta(0, '<system-reminder> Your final report is delivered through SubagentHandback.</system-reminder>'),
  assistant(1, 'msg_1', [tool('t1', 'Read', { file_path: '/tmp/demo/ai/changes/note-tags/tasks.md' })], usage(10, 1000, 0)),
  user(2, [result('t1', 'x'.repeat(70))]),
  meta(2, '[Image: original 1440x2400, displayed at 1200x2000.]'),
  assistant(3, 'msg_2', [tool('t2', 'Write', { file_path: '/tmp/demo/src/tags/tag.ts' })], usage(5, 500, 1010)),
  user(4, [result('t2', 'ok')]),
  assistant(5, 'msg_3', [tool('t3', HANDBACK, { message: 'T-02 gotowe.' })], usage(5, 100, 1515), null),
  user(6, [result('t3', 'Raport przekazany.')]),
  meta(30, 'The coordinator sent a message while you were working: T-02 przyjęty — kontynuuj taskiem T-03.'),
  assistant(31, 'msg_4', [tool('t4', 'Read', { file_path: '/tmp/demo/ai/changes/note-tags/design.md' })], usage(5, 3000, 0)),
  user(32, [result('t4', 'y'.repeat(700))]),
  meta(33, 'Your response above was cut off mid-stream and has been discarded.'),
  assistant(34, 'msg_5', [tool('t5', HANDBACK, { message: 'T-03 gotowe.\nBRAK W PACZCE: design.md › Testing Strategy — nazwy' })], usage(5, 200, 3005), null),
  meta(60, 'The coordinator sent a message while you were working: T-03 przyjęty — kontynuuj taskiem T-04.'),
  assistant(61, 'msg_6', [{ type: 'text', text: 'Gotowe.' }], usage(5, 300, 3210), 'end_turn'),
]);

describe('firstTurn — agent kontynuowany przez SendMessage', () => {
  const t = firstTurn(CONTINUED)!;

  it('wiadomość koordynatora kończy pierwszą turę, choć raport nie skończył jej end_turn', () => {
    expect(t.calls).toEqual([1010, 1515, 1620]);
    expect(t.atFirstEdit).toBe(1515);
    expect(t.changeReadBytes).toBe(70);
  });

  it('cały agent: wszystkie wywołania i wiadomości — bez przypomnień, obrazów i uciętej odpowiedzi', () => {
    expect(t.allCalls).toEqual([1010, 1515, 1620, 3005, 3210, 3515]);
    expect(t.messages).toBe(2);
  });

  it('BRAK W PACZCE także z raportu kontynuacji', () => {
    expect(t.missing).toEqual(['design.md › Testing Strategy']);
  });

  it('meta-rekord przed pierwszym wywołaniem i przerwanie przez użytkownika nie są wiadomościami', () => {
    const interrupted = firstTurn([
      ...CONTINUED.slice(0, 4),
      JSON.stringify(user(5, [{ type: 'text', text: '[Request interrupted by user]' }])),
      ...CONTINUED.slice(5, 7),
    ])!;
    expect(interrupted.messages).toBe(0);
    expect(interrupted.calls).toEqual([1010, 1515]);
  });
});

describe('bashWrites — zapis pliku w poleceniu Bash', () => {
  it.each([
    ["cat > www/package.json <<'EOF'\n{}\nEOF", true],
    ['cd www && cat >> test/a.test.mjs <<EOF\nx\nEOF', true],
    ['node build.mjs | tee build.log', true],
    ["sed -i '' 's/a/b/' src/a.ts", true],
    ['sed -Ei "s/a/b/" src/a.ts', true],
    ["perl -pi -e 's/a/b/' src/a.ts", true],
    ['echo x >out.txt', true],
  ])('zapis: %s', (command, expected) => {
    expect(bashWrites(command)).toBe(expected);
  });

  it.each([
    ['npm test 2>&1 | tail -20', false],
    ['node --test test/a.mjs >/dev/null 2>&1', false],
    ['git status > /dev/null', false],
    ['echo błąd >&2', false],
    ["grep -c '<script>' dist/index.html", false],
    ['grep -n "a -> b" src/a.ts', false],
    ["sed -n 28,86p ai/changes/x/design.md | grep -i kontrakt", false],
    ["python3 - <<'EOF'\nopen(p, 'w').write(s) > 0\nEOF", false],
  ])('bez zapisu: %s', (command, expected) => {
    expect(bashWrites(command)).toBe(expected);
  });
});

describe('missingKeys — zgłoszenia BRAK W PACZCE', () => {
  it('linia z szablonu, punkty pod nagłówkiem, bez wzorca i bez „brak”', () => {
    const text = [
      'BRAK W PACZCE: design.md › Error Handling — kody błędów',
      'BRAK W PACZCE: <plik> › <sekcja> — <po co>',
      'BRAK W PACZCE: brak',
      '### BRAK W PACZCE',
      '',
      '1. design.md › Dev loop — port podglądu',
      '- Nic więcej.',
      '## Dalej',
      '- design.md › poza sekcją',
    ].join('\n');
    expect(missingKeys(text)).toEqual(['design.md › Error Handling', 'design.md › Dev loop']);
  });
});
