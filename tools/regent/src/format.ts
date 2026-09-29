// Tekstowe widoki zadań dla CLI. Kolumny dopasowane do treści, czas lokalny.

import { CLOSED, STATE_LABEL, type Kind } from './model.js';
import type { Task, Transition } from './tasks.js';

const KIND_LABEL: Readonly<Record<Kind, string>> = { change: 'zmiana SDD', task: 'task zmiany', manual: 'ręczne' };

const pad2 = (n: number) => String(n).padStart(2, '0');

/** `RRRR-MM-DD GG:MM` w strefie lokalnej. */
export function fmtTime(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** Klucz, tag i tytuł: `T-03 [BE] endpoint`. */
export const label = (t: Task): string => [t.key, t.tag && `[${t.tag}]`, t.title].filter(Boolean).join(' ');

/** Jedna linia po zmianie stanu: `#3 T-03 [BE] endpoint — w toku (agent)`. */
export const taskLine = (t: Task): string => `#${t.id} ${label(t)} — ${STATE_LABEL[t.state]} (${t.owner})`;

/** Wiersze z kolumnami wyrównanymi do najdłuższej wartości; ostatnia kolumna bez dopełnienia. */
export function columns(rows: string[][], indent = '  '): string[] {
  const widths = rows.reduce<number[]>((w, row) => row.map((cell, i) => Math.max(w[i] ?? 0, cell.length)), []);
  return rows.map((row) => indent + row.map((cell, i) => (i === row.length - 1 ? cell : cell.padEnd(widths[i]!))).join('  '));
}

export function renderList(project: string, tasks: Task[], all: boolean): string {
  if (tasks.length === 0) return `Brak ${all ? '' : 'otwartych '}zadań w ${project}.`;
  const rows = tasks.map((t) => [
    `${t.parentId === null ? '' : '  '}#${t.id}`,
    STATE_LABEL[t.state],
    t.owner,
    CLOSED.includes(t.state) && t.closureReason ? `${label(t)} — ${t.closureReason}` : label(t),
  ]);
  return [`${project} — ${all ? 'wszystkie' : 'otwarte'}: ${tasks.length}`, '', ...columns(rows)].join('\n');
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
