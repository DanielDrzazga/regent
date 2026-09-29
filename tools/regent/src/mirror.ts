// Lustro tasks.md: zamknięcie taska zmiany przez CLI przepisuje wyłącznie jego linię — `[x]` i ślad
// w formacie z `apply` Krok 4c. Najpierw plik, potem baza: gdy zapis do bazy padnie, zmieniona linia
// wygra przy najbliższym sync, więc stan i tak się zejdzie.

import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { TransitionError, UsageError, canTransition } from './model.js';
import { resolveChange } from './packet.js';
import { readText } from './sdd.js';
import { changeName } from './sync.js';
import { rewriteTask, type Closure } from './tasksmd.js';
import type { Ctx, Task, TaskStore } from './tasks.js';

export interface Closed {
  task: Task;
  /** Pełna ścieżka tasks.md zmiany; null — katalogu zmiany już nie ma. */
  file: string | null;
  /** Linia taska przepisana w pliku. */
  mirrored: boolean;
}

function tasksFile(store: TaskStore, task: Task): string | null {
  const parent = task.parentId === null ? undefined : store.get(task.parentId);
  if (!parent) return null;
  try {
    return join(resolveChange(task.project, changeName(parent)), 'tasks.md');
  } catch (e) {
    if (e instanceof UsageError) return null; // katalog zmiany zniknął — zamykamy tylko w bazie
    throw e;
  }
}

export function closeTask(store: TaskStore, task: Task, closure: Closure, reason: string, ctx: Ctx): Closed {
  if (!canTransition(task.state, 'done')) throw new TransitionError(task.id, task.state, 'done');
  const file = tasksFile(store, task);
  const text = file === null ? undefined : readText(file);
  const rewritten = text === undefined || task.key === null ? undefined : rewriteTask(text, task.key, closure);
  if (file && rewritten) writeFileSync(file, rewritten.text);
  const done = store.batch(() => {
    const closed = store.transition(task.id, 'done', { ...ctx, reason });
    return rewritten ? store.revise(closed.id, { refs: { ...rewritten.task.refs }, fileSig: rewritten.task.sig }) : closed;
  });
  return { task: done, file, mirrored: Boolean(rewritten) };
}
