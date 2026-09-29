// Utknięcie liczone przy odczycie, bez procesu w tle: zadanie w toku, którego sesja nie zmieniła
// transkryptu od progu, albo zadanie w toku bez transkryptu sesji dłużej niż próg od wzięcia.

import { statSync } from 'node:fs';
import type { Task } from './tasks.js';

export const DEFAULT_STUCK_MIN = 30;

/** idle — transkrypt stoi; no-transcript — pliku nie ma; no-session — zadanie bez transkryptu sesji. */
export type StuckWhy = 'idle' | 'no-transcript' | 'no-session';

export interface Stuck {
  taskId: number;
  why: StuckWhy;
  idleMs: number;
  /** Ostatni ślad pracy: zapis transkryptu albo wzięcie, jeśli późniejsze. */
  since: string;
}

/** Czas ostatniej zmiany pliku w ms albo undefined, gdy pliku nie ma. */
export type Mtime = (path: string) => number | undefined;

export const fileMtime: Mtime = (path) => {
  try {
    return statSync(path).mtimeMs;
  } catch {
    return undefined;
  }
};

export interface StuckOptions {
  now: number;
  thresholdMs: number;
  mtime?: Mtime;
}

export function findStuck(tasks: Task[], { now, thresholdMs, mtime = fileMtime }: StuckOptions): Stuck[] {
  return tasks.flatMap((t) => {
    if (t.state !== 'in_progress') return [];
    const claimed = Date.parse(t.claimedAt ?? t.updatedAt);
    const modified = t.transcriptPath ? mtime(t.transcriptPath) : undefined;
    const why: StuckWhy = !t.transcriptPath ? 'no-session' : modified === undefined ? 'no-transcript' : 'idle';
    // Świeżo wzięte zadanie nie jest utknięte tylko dlatego, że przypięty transkrypt jest stary.
    const last = Math.max(claimed, modified ?? claimed);
    const idleMs = now - last;
    return idleMs >= thresholdMs ? [{ taskId: t.id, why, idleMs, since: new Date(last).toISOString() }] : [];
  });
}
