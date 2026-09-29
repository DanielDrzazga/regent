// Sekcja Uwaga w `list`, liczona przy odczycie: utknięte (stuck.ts), zmiany SDD bez artefaktów,
// rozjazd stanu z artefaktami i czas ostatniego sync.

import { existsSync } from 'node:fs';
import { CLOSED, isState, type State } from './model.js';
import { activeChanges, archivedChanges, changesDir } from './sdd.js';
import type { Stuck } from './stuck.js';
import { changeName } from './sync.js';
import type { SyncMark, Task } from './tasks.js';

/** Otwarta zmiana, której katalog zniknął z `ai/changes/`, a w archiwum jej nie ma. */
export interface Missing {
  taskId: number;
  change: string;
}

/** Stan zadania inny niż wynikający z artefaktów — sync nie mógł go przestawić albo zmieniono go ręcznie. */
export interface Mismatch {
  taskId: number;
  state: State;
  implied: State;
}

export interface Attention {
  stuck: Stuck[];
  missing: Missing[];
  mismatch: Mismatch[];
  /** Projekt ma `ai/changes/` — wtedy `list` pokazuje czas ostatniego sync, także „nigdy”. */
  sdd: boolean;
  lastSync: SyncMark | null;
}

export function findMissing(root: string, tasks: Task[]): Missing[] {
  const open = tasks.filter((t) => t.kind === 'change' && !CLOSED.includes(t.state));
  if (!open.length) return [];
  const active = new Set(activeChanges(root));
  const archived = archivedChanges(root);
  return open.flatMap((t) => {
    const change = changeName(t);
    return active.has(change) || archived.has(change) ? [] : [{ taskId: t.id, change }];
  });
}

/** Stan wynikający z plików: zmiana — `refs.implied` z mapy SDD; task — checkbox jego linii w tasks.md. */
function impliedOf(t: Task): State | undefined {
  if (t.kind === 'change') return typeof t.refs.implied === 'string' && isState(t.refs.implied) ? t.refs.implied : undefined;
  if (t.kind !== 'task' || t.refs.removed === true || typeof t.refs.box !== 'string') return undefined;
  if (t.refs.box === 'DONE') return t.state === 'done' ? undefined : 'done';
  return t.state === 'done' ? 'pending' : undefined;
}

export function findMismatch(tasks: Task[]): Mismatch[] {
  return tasks.flatMap((t) => {
    const implied = impliedOf(t);
    return implied === undefined || implied === t.state ? [] : [{ taskId: t.id, state: t.state, implied }];
  });
}

export const hasSdd = (root: string): boolean => existsSync(changesDir(root));

export const attentionJson = (a: Attention) => ({
  stuck: a.stuck.map((s) => ({ id: s.taskId, why: s.why, idleMinutes: Math.floor(s.idleMs / 60_000), since: s.since })),
  missing: a.missing.map((m) => ({ id: m.taskId, change: m.change })),
  mismatch: a.mismatch.map((m) => ({ id: m.taskId, state: m.state, artifacts: m.implied })),
  lastSync: a.lastSync,
});
