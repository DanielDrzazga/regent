// Tekstowe widoki zadań dla CLI. Kolumny dopasowane do treści, czas lokalny.

import type { Attention } from './attention.js';
import { CLOSED, STATE_LABEL, type Kind } from './model.js';
import type { Stuck } from './stuck.js';
import type { SyncReport } from './sync.js';
import type { Task, Transition } from './tasks.js';

const KIND_LABEL: Readonly<Record<Kind, string>> = { change: 'zmiana SDD', task: 'task zmiany', manual: 'ręczne' };

const pad2 = (n: number) => String(n).padStart(2, '0');

/** `RRRR-MM-DD GG:MM` w strefie lokalnej. */
export function fmtTime(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** Klucz starszego formatu `#<n>` jako `<n>.` — żeby nie mylił się z id zadania. */
const shownKey = (key: string | null): string | null => (key?.startsWith('#') ? `${key.slice(1)}.` : key);

/** Klucz, tag i tytuł: `T-03 [BE] endpoint`; zmiana SDD — sam klucz `sdd:<zmiana>`, tytuł to jej nazwa. */
export const label = (t: Task): string =>
  t.kind === 'change' && t.key === `sdd:${t.title}`
    ? t.key
    : [shownKey(t.key), t.tag && `[${t.tag}]`, t.title].filter(Boolean).join(' ');

/** Jedna linia po zmianie stanu: `#3 T-03 [BE] endpoint — w toku (agent)`. */
export const taskLine = (t: Task): string => `#${t.id} ${label(t)} — ${STATE_LABEL[t.state]} (${t.owner})`;

/** Wiersze z kolumnami wyrównanymi do najdłuższej wartości; ostatnia kolumna bez dopełnienia. */
export function columns(rows: string[][], indent = '  '): string[] {
  const widths = rows.reduce<number[]>((w, row) => row.map((cell, i) => Math.max(w[i] ?? 0, cell.length)), []);
  return rows.map((row) => indent + row.map((cell, i) => (i === row.length - 1 ? cell : cell.padEnd(widths[i]!))).join('  '));
}

/** `45 min`, `2 godz. 30 min`. */
export function fmtDuration(ms: number): string {
  const minutes = Math.floor(ms / 60_000);
  if (minutes < 60) return `${minutes} min`;
  const rest = minutes % 60;
  return `${Math.floor(minutes / 60)} godz.${rest ? ` ${rest} min` : ''}`;
}

const shortSession = (id: string) => id.slice(0, 8);

export function describeStuck(s: Stuck, t: Task): string {
  const since = fmtDuration(s.idleMs);
  const session = t.sessionId ? ` ${shortSession(t.sessionId)}` : '';
  switch (s.why) {
    case 'idle':
      return `transkrypt sesji${session} bez zmian od ${since}`;
    case 'no-transcript':
      return `brak transkryptu sesji${session} (${t.transcriptPath}), w toku od ${since}`;
    case 'no-session':
      return t.sessionId ? `w toku bez transkryptu sesji${session} od ${since}` : `w toku bez sesji od ${since}`;
  }
}

function syncLine(a: Attention): string[] {
  if (a.lastSync) return [`Ostatni sync: ${fmtTime(a.lastSync.at)} (${a.lastSync.source})`];
  return a.sdd ? ['Ostatni sync: nigdy — zadania SDD mogą być nieaktualne (regent task sync)'] : [];
}

const quote = (text: string) => `„${text}”`;

export function renderList(project: string, tasks: Task[], all: boolean, a: Attention): string {
  const footer = syncLine(a);
  if (tasks.length === 0) return [`Brak ${all ? '' : 'otwartych '}zadań w ${project}.`, ...footer].join('\n');
  const rows = tasks.map((t) => [
    `${t.parentId === null ? '' : '  '}#${t.id}`,
    STATE_LABEL[t.state],
    t.owner,
    CLOSED.includes(t.state) && t.closureReason ? `${label(t)} — ${t.closureReason}` : label(t),
  ]);
  const lines = [`${project} — ${all ? 'wszystkie' : 'otwarte'}: ${tasks.length}`, '', ...columns(rows)];
  const byId = new Map(tasks.map((t) => [t.id, t]));
  const attention = [
    ...a.stuck.map((s) => [`#${s.taskId}`, `utknięte — ${describeStuck(s, byId.get(s.taskId)!)}`]),
    ...a.missing.map((m) => [`#${m.taskId}`, `bez artefaktów — ai/changes/${m.change}/ zniknął bez archiwum`]),
    ...a.mismatch.map((m) => [
      `#${m.taskId}`,
      `rozjazd z artefaktami — wynika z nich ${quote(STATE_LABEL[m.implied])}, zadanie jest ${quote(STATE_LABEL[m.state])}`,
    ]),
  ];
  if (attention.length) lines.push('', 'Uwaga:', ...columns(attention));
  if (footer.length) lines.push('', ...footer);
  return lines.join('\n');
}

export function renderSync(r: SyncReport): string {
  if (!r.sdd) return `Brak ai/changes/ w ${r.project} — nic do synchronizacji.`;
  if (!r.events.length) return `Sync ${r.project}: bez zmian stanu.`;
  const rows = r.events.map((e) => [
    `#${e.id}`,
    e.key,
    e.from === null ? `nowe: ${STATE_LABEL[e.to]}` : `${STATE_LABEL[e.from]} → ${STATE_LABEL[e.to]}`,
    e.reason,
  ]);
  return [`Sync ${r.project}:`, ...columns(rows)].join('\n');
}

export function renderShow(task: Task, history: Transition[], parent: Task | undefined): string {
  const fields: [string, string | null | undefined][] = [
    ['stan', `${STATE_LABEL[task.state]} (${task.owner})`],
    ['powód', task.closureReason],
    ['rodzaj', KIND_LABEL[task.kind]],
    ['rodzic', parent && `#${parent.id} ${label(parent)}`],
    ['projekt', task.project],
    ['sesja', task.sessionId && (task.transcriptPath ? `${task.sessionId} (${task.transcriptPath})` : task.sessionId)],
    ['refs', Object.keys(task.refs).length ? JSON.stringify(task.refs) : null],
    ['wzięte', task.claimedAt && fmtTime(task.claimedAt)],
    ['utworzone', fmtTime(task.createdAt)],
    ['zmienione', fmtTime(task.updatedAt)],
  ];
  const head = columns(fields.filter((f): f is [string, string] => Boolean(f[1])).map(([k, v]) => [`${k}:`, v]));
  const log = columns(
    history.map((h) => [fmtTime(h.at), STATE_LABEL[h.state], h.owner, `${h.actor}/${h.source}${h.reason ? ` — ${h.reason}` : ''}`]),
  );
  return [`#${task.id} ${label(task)}`, ...head, '', 'Historia:', ...log].join('\n');
}
