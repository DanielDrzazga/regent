// `regent task next` — gotowe taski zmiany: niezrobione (także przerwane w toku), nie czekają na
// Ciebie ani na blokadę, a każda zależność `(po T-XX)` jest zamknięta. Kolejność jak w tasks.md.

import { CLOSED, UsageError, type State } from './model.js';
import { changeKey } from './sync.js';
import { layerOf } from './tasksmd.js';
import type { Task, TaskStore } from './tasks.js';

export const LAYERS = ['BE', 'FE', 'DB'] as const;

const READY_STATES: readonly State[] = ['pending', 'handed_off', 'in_progress'];

export interface Blocked {
  task: Task;
  /** Zależności jeszcze otwarte albo nieistniejące w tasks.md. */
  after: string[];
}

export interface Next {
  change: Task;
  ready: Task[];
  blocked: Blocked[];
  /** Otwarte taski zmiany (w tej warstwie) — do komunikatu, gdy nic nie jest gotowe. */
  open: number;
}

const lineOf = (t: Task): number => (typeof t.refs.line === 'number' ? t.refs.line : Number.MAX_SAFE_INTEGER);
const afterOf = (t: Task): string[] => (Array.isArray(t.refs.after) ? t.refs.after.filter((k): k is string => typeof k === 'string') : []);

export function nextTasks(store: TaskStore, project: string, name: string, layer?: string): Next {
  const change = store.findByKey(project, null, changeKey(name));
  if (!change) throw new UsageError(`nie ma zmiany sdd:${name} w bazie — sprawdź nazwę w ai/changes/`);
  const children = store.children(change.id).sort((a, b) => lineOf(a) - lineOf(b) || a.id - b.id);
  const byKey = new Map(children.map((t) => [t.key, t]));
  const inLayer = children.filter((t) => !layer || layerOf(t.tag) === layer);
  const result: Next = { change, ready: [], blocked: [], open: inLayer.filter((t) => !CLOSED.includes(t.state)).length };
  for (const t of inLayer) {
    if (!READY_STATES.includes(t.state)) continue;
    const after = afterOf(t).filter((key) => {
      const dep = byKey.get(key);
      return !dep || !CLOSED.includes(dep.state);
    });
    if (after.length) result.blocked.push({ task: t, after });
    else result.ready.push(t);
  }
  return result;
}
