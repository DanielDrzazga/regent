// Formatowanie liczb, czasu i kolumn widoku — czyste funkcje.

import type { ProblemKind } from '../parse/tools.js';
import type { EventKind } from '../parse/transcript.js';
import type { AgentStatus } from '../view.js';

/** Tokeny jak w session-tokens.sh: 950, 12k, 1.2M. */
export function fmtTokens(n: number): string {
  if (n >= 1_000_000) return `${(Math.floor(n / 100_000) / 10).toFixed(1)}M`;
  if (n >= 1000) return `${Math.round(n / 1000)}k`;
  return String(n);
}

export const fmtCost = (usd: number | undefined): string => (usd === undefined ? '?' : `$${usd.toFixed(2)}`);

export function fmtDuration(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min`;
  return `${Math.floor(m / 60)} h ${m % 60} min`;
}

export function fmtClock(ts: number): string {
  const d = new Date(ts);
  const two = (n: number) => String(n).padStart(2, '0');
  return `${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
}

/** Tekst przycięty do szerokości w (z „…") i dopełniony spacjami. */
export function fit(text: string, w: number, align: 'left' | 'right' = 'left'): string {
  if (w <= 0) return '';
  const chars = [...text];
  const s = chars.length > w ? `${chars.slice(0, w - 1).join('')}…` : text;
  const pad = ' '.repeat(Math.max(0, w - [...s].length));
  return align === 'left' ? s + pad : pad + s;
}

export const EVENT_MARK: Record<EventKind, string> = {
  prompt: '>',
  tool: '·',
  message: '@',
  spawn: '+',
  error: '✗',
  retry: '↻',
  'turn-end': '─',
};

export const PROBLEM_LABEL: Record<ProblemKind, string> = {
  hook: 'blokada hooka',
  permission: 'odmowa',
  tool: 'błąd narzędzia',
  api: 'błąd API',
};

export const STATUS_COLOR: Record<AgentStatus, string> = {
  pracuje: 'green',
  myśli: 'cyan',
  czeka: 'yellow',
  zakończony: 'gray',
  zamknięty: 'gray',
};

// Kolory członków zespołu z config.json → nazwy kolorów Ink; nieznane zostają domyślne.
const INK_COLORS = new Set(['red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white', 'gray']);
const ALIASES: Record<string, string> = { purple: 'magenta', pink: 'magenta', orange: 'yellow' };
export function inkColor(c: string | undefined): string | undefined {
  const name = c ? (ALIASES[c] ?? c) : undefined;
  return name && INK_COLORS.has(name) ? name : undefined;
}
