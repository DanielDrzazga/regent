// regent-apply-tokens — pierwsza tura i cały subagent apply z transkryptów (docs/plans/task-core-check.md,
// docs/plans/apply-kontynuacje.md): punkt odniesienia i porównanie tygodnia sprawdzenia etapu 1
// (docs/plans/task-core.md). Tylko odczyt, na wyjściu same liczby. Wejście i wyjście przez Io, żeby
// testy wołały main w procesie.

import { readFileSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { firstTurn, type FirstTurn } from './parse/firstturn.js';
import { defaultClaudeDir } from './session.js';
import { fmtTokens } from './units.js';

export interface Io {
  argv: string[];
  env: NodeJS.ProcessEnv;
  cwd: string;
  out: (text: string) => void;
  err: (text: string) => void;
}

const HELP = `regent-apply-tokens — pierwsza tura i cały subagent apply z transkryptów Claude Code (tylko odczyt).

Użycie:
  regent-apply-tokens [--project <katalog>]… [--since RRRR-MM-DD] [--until RRRR-MM-DD] [--json]

Próbka: subagenci backend-dev, frontend-dev i dba (także regent:…) z promptem o ai/changes/,
podzieleni na uruchomienia bez paczki i z paczką (# Paczka: w prompcie albo w wyniku narzędzia
w pierwszej turze — paczka z pliku). Mediany: suma tokenów wejścia pierwszej tury (wejście + zapis
i odczyt cache każdego wywołania API), liczba wywołań, kontekst pierwszego wywołania, przy pierwszej
edycji (także zapis w Bash) i maksymalny, odczyt tasks.md, design.md i specs/ zmiany przez Read
i Bash (bajty / 3,5). Pierwsza tura kończy się też na wiadomości do agenta (SendMessage). Cały agent:
ilu dostało wiadomości po prompcie, ile ich było, mediany sumy wejścia wszystkich tur i największego
kontekstu. Na końcu zgłoszenia BRAK W PACZCE wg pliku i sekcji, z odpowiedzi i raportu.

Opcje:
  --project <katalog>   tylko sesje z cwd w tym katalogu albo niżej (worktree); można powtórzyć
  --since, --until      data (lokalna) pierwszego rekordu subagenta, włącznie
  --json                wynik jako JSON
  -h, --help            ta pomoc

Transkrypty: \${CLAUDE_CONFIG_DIR:-~/.claude}/projects/*/<sesja>/subagents/.
Kody wyjścia: 0 — ok, 2 — błędne użycie.`;

const TYPES = /^(regent:)?(backend-dev|frontend-dev|dba)$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

interface Row {
  type: string;
  packet: boolean;
  date: string;
  turn: FirstTurn;
}

interface Summary {
  n: number;
  byType: Record<string, number>;
  from: string | null;
  to: string | null;
  median: Record<
    'sumFirstTurn' | 'calls' | 'firstCall' | 'atFirstEdit' | 'maxCtx' | 'changeReadTokens' | 'sumAll' | 'maxCtxAll',
    number | null
  >;
  /** Ilu czytało pliki zmiany. */
  readers: number;
  /** Ilu dostało paczkę z pliku (wynik narzędzia), a nie w prompcie. */
  packetFromFile: number;
  /** Ilu dostało wiadomości po prompcie (kontynuacja przez SendMessage). */
  continued: number;
  /** Wiadomości do agentów po prompcie, razem. */
  messages: number;
}

class UsageError extends Error {}

const pad2 = (n: number) => String(n).padStart(2, '0');
const localDate = (ms: number): string => {
  const d = new Date(ms);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
};

const dirs = (path: string): string[] => {
  try {
    return readdirSync(path, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name);
  } catch {
    return [];
  }
};

const files = (path: string, suffix: string): string[] => {
  try {
    return readdirSync(path).filter((name) => name.endsWith(suffix));
  } catch {
    return [];
  }
};

/** Pliki `.meta.json` subagentów: projects/<projekt>/<sesja>/subagents/. */
function metaFiles(claudeDir: string): string[] {
  const projects = join(claudeDir, 'projects');
  return dirs(projects).flatMap((p) =>
    dirs(join(projects, p)).flatMap((s) => {
      const sub = join(projects, p, s, 'subagents');
      return files(sub, '.meta.json').map((f) => join(sub, f));
    }),
  );
}

function readRow(meta: string): Row | undefined {
  let type: string;
  try {
    const parsed = JSON.parse(readFileSync(meta, 'utf8')) as { agentType?: unknown };
    if (typeof parsed.agentType !== 'string' || !TYPES.test(parsed.agentType)) return undefined;
    type = parsed.agentType.replace(/^regent:/, '');
  } catch {
    return undefined;
  }
  let text: string;
  try {
    text = readFileSync(meta.replace(/\.meta\.json$/, '.jsonl'), 'utf8');
  } catch {
    return undefined;
  }
  const turn = firstTurn(text.split('\n'));
  if (!turn || !turn.prompt.includes('ai/changes/') || turn.startedAt === undefined) return undefined;
  return { type, packet: turn.packet !== undefined, date: localDate(turn.startedAt), turn };
}

function median(values: (number | undefined)[]): number | null {
  const v = values.filter((x): x is number => x !== undefined).sort((a, b) => a - b);
  if (!v.length) return null;
  const h = v.length >> 1;
  return v.length % 2 ? v[h]! : Math.round((v[h - 1]! + v[h]!) / 2);
}

function summarize(rows: Row[]): Summary {
  const dates = rows.map((r) => r.date).sort();
  const byType: Record<string, number> = {};
  for (const r of rows) byType[r.type] = (byType[r.type] ?? 0) + 1;
  return {
    n: rows.length,
    byType,
    from: dates[0] ?? null,
    to: dates.at(-1) ?? null,
    median: {
      sumFirstTurn: median(rows.map((r) => r.turn.calls.reduce((a, b) => a + b, 0))),
      calls: median(rows.map((r) => r.turn.calls.length)),
      firstCall: median(rows.map((r) => r.turn.calls[0])),
      atFirstEdit: median(rows.map((r) => r.turn.atFirstEdit)),
      maxCtx: median(rows.map((r) => Math.max(...r.turn.calls))),
      changeReadTokens: median(rows.map((r) => Math.round(r.turn.changeReadBytes / 3.5))),
      sumAll: median(rows.map((r) => r.turn.allCalls.reduce((a, b) => a + b, 0))),
      maxCtxAll: median(rows.map((r) => Math.max(...r.turn.allCalls))),
    },
    readers: rows.filter((r) => r.turn.changeReadBytes > 0).length,
    packetFromFile: rows.filter((r) => r.turn.packet === 'tool').length,
    continued: rows.filter((r) => r.turn.messages > 0).length,
    messages: rows.reduce((a, r) => a + r.turn.messages, 0),
  };
}

const byCount = (counts: Record<string, number>): [string, number][] =>
  Object.entries(counts).sort(([a, x], [b, y]) => y - x || a.localeCompare(b));

function render(plain: Summary, packet: Summary, missing: Record<string, number>, scope: string): string {
  const all = summarize([]);
  for (const s of [plain, packet]) for (const [t, n] of Object.entries(s.byType)) all.byType[t] = (all.byType[t] ?? 0) + n;
  const types = byCount(all.byType).map(([t, n]) => `${t} ${n}`).join(', ');
  const dates = [plain.from, packet.from].filter(Boolean).sort()[0];
  const until = [plain.to, packet.to].filter(Boolean).sort().at(-1);

  const tok = (v: number | null, s: Summary) => (s.n && v !== null ? fmtTokens(v) : '–');
  const num = (v: number | null, s: Summary) => (s.n && v !== null ? String(v) : '–');
  const rows: [string, (s: Summary) => string][] = [
    ['subagenci', (s) => String(s.n)],
    ['suma wejścia pierwszej tury', (s) => tok(s.median.sumFirstTurn, s)],
    ['wywołania API', (s) => num(s.median.calls, s)],
    ['kontekst: pierwsze wywołanie', (s) => tok(s.median.firstCall, s)],
    ['kontekst: pierwsza edycja', (s) => tok(s.median.atFirstEdit, s)],
    ['kontekst: maksymalny', (s) => tok(s.median.maxCtx, s)],
    ['odczyt plików zmiany', (s) => tok(s.median.changeReadTokens, s)],
    ['czytało pliki zmiany', (s) => (s.n ? `${s.readers}/${s.n}` : '–')],
    ['paczka z pliku', (s) => (s.n && s !== plain ? `${s.packetFromFile}/${s.n}` : '–')],
    ['kontynuowani (SendMessage)', (s) => (s.n ? `${s.continued}/${s.n}` : '–')],
    ['wiadomości do agenta', (s) => (s.n ? String(s.messages) : '–')],
    ['suma wejścia całego agenta', (s) => tok(s.median.sumAll, s)],
    ['kontekst: maksymalny (cały agent)', (s) => tok(s.median.maxCtxAll, s)],
  ];
  const w = Math.max(...rows.map(([l]) => l.length));
  const line = (label: string, a: string, b: string) => `  ${label.padEnd(w)}  ${a.padStart(10)}  ${b.padStart(8)}`;

  const reports = byCount(missing);
  const cw = Math.max(1, ...reports.map(([, n]) => String(n).length));
  return [
    'regent-apply-tokens — subagenci apply: pierwsza tura i cały agent, mediany tokenów wejścia',
    `Próbka: ${plain.n + packet.n} subagentów (${types}), ${dates} … ${until}`,
    `Projekty: ${scope}`,
    '',
    line('', 'bez paczki', 'z paczką'),
    ...rows.map(([label, f]) => line(label, f(plain), f(packet))),
    '',
    ...(reports.length ? ['BRAK W PACZCE:', ...reports.map(([k, n]) => `  ${String(n).padStart(cw)}  ${k}`)] : ['BRAK W PACZCE: brak zgłoszeń']),
  ].join('\n');
}

function run(io: Io): number {
  const { values } = parseArgs({
    args: io.argv,
    options: {
      project: { type: 'string', multiple: true },
      since: { type: 'string' },
      until: { type: 'string' },
      json: { type: 'boolean' },
      help: { type: 'boolean', short: 'h' },
    },
    strict: true,
  });
  if (values.help) {
    io.out(HELP);
    return 0;
  }
  for (const key of ['since', 'until'] as const) {
    const v = values[key];
    if (v !== undefined && !(DATE.test(v) && !Number.isNaN(Date.parse(v)))) throw new UsageError(`--${key} wymaga daty RRRR-MM-DD, podano: ${v}`);
  }
  const projects = (values.project ?? []).map((p) => resolve(io.cwd, p.replace(/^~(?=$|\/)/, homedir())));
  const inScope = (cwd: string | undefined) => !projects.length || (cwd !== undefined && projects.some((p) => cwd === p || cwd.startsWith(`${p}/`)));

  const claudeDir = defaultClaudeDir(io.env);
  const rows = metaFiles(claudeDir)
    .flatMap((m) => readRow(m) ?? [])
    .filter((r) => inScope(r.turn.cwd))
    .filter((r) => (values.since === undefined || r.date >= values.since) && (values.until === undefined || r.date <= values.until));

  const scope = projects.length ? projects.join(', ') : `wszystkie w ${join(claudeDir, 'projects')}`;
  const plain = summarize(rows.filter((r) => !r.packet));
  const packet = summarize(rows.filter((r) => r.packet));
  const missing: Record<string, number> = {};
  for (const r of rows) for (const k of r.turn.missing) missing[k] = (missing[k] ?? 0) + 1;

  if (values.json) {
    const filters = { projects: projects.length ? projects : null, since: values.since ?? null, until: values.until ?? null };
    io.out(JSON.stringify({ claudeDir, filters, groups: { plain, packet }, missing }, null, 2));
    return 0;
  }
  if (!rows.length) {
    const dates = [values.since && `od ${values.since}`, values.until && `do ${values.until}`].filter(Boolean).join(' ');
    io.out(`Brak subagentów apply w próbce — projekty: ${scope}${dates ? `, ${dates}` : ''}.`);
    return 0;
  }
  io.out(render(plain, packet, missing, scope));
  return 0;
}

export function main(io: Io): number {
  try {
    return run(io);
  } catch (e) {
    if (e instanceof UsageError || (e as { code?: string }).code?.startsWith('ERR_PARSE_ARGS')) {
      io.err(`regent-apply-tokens: ${(e as Error).message}\nPomoc: regent-apply-tokens --help`);
      return 2;
    }
    throw e;
  }
}
