// Wspólny wygląd: symbole statusu, kolory, pasek kontekstu, animacja pracy.

import { CTX_CRIT, CTX_WARN, type AgentRow, type AgentStatus, type HealthLevel } from '../view.js';
import { type Seg, seg } from './lines.js';

export const THEME = { frame: 'blue', title: 'cyan', accent: 'magenta' } as const;

const SPINNER = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
export const spinner = (frame: number): string => SPINNER[frame % SPINNER.length] ?? '·';

export const STATUS_COLOR: Record<AgentStatus, string> = {
  pracuje: 'green',
  myśli: 'cyan',
  czeka: 'gray',
  zakończony: 'gray',
  zamknięty: 'gray',
};

export const HEALTH_COLOR: Record<HealthLevel, string | undefined> = { ok: undefined, uwaga: 'yellow', problem: 'red' };
export const HEALTH_MARK: Record<HealthLevel, string> = { ok: '●', uwaga: '▲', problem: '✗' };

export const isBusy = (s: AgentStatus): boolean => s === 'pracuje' || s === 'myśli';

/** Kropka statusu jak w OpenRig: animacja przy pracy, ● czeka, ○ zakończony/zamknięty. */
export function statusDot(status: AgentStatus, frame: number): Seg {
  if (isBusy(status)) return seg(spinner(frame), { color: STATUS_COLOR[status] });
  if (status === 'czeka') return seg('●', { color: 'gray' });
  return seg('○', { dim: true });
}

// Kolory członków zespołu z config.json → nazwy kolorów Ink; nieznane zostają domyślne.
const INK_COLORS = new Set(['red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white', 'gray']);
const ALIASES: Record<string, string> = { purple: 'magenta', pink: 'magenta', orange: 'yellow' };
export function inkColor(c: string | undefined): string | undefined {
  const name = c ? (ALIASES[c] ?? c) : undefined;
  return name && INK_COLORS.has(name) ? name : undefined;
}

/** Kolor kontekstu: progi w tokenach jak statusline, plus 75% / 90% okna. */
export function contextColor(r: Pick<AgentRow, 'context' | 'contextWindow'>): string | undefined {
  const ctx = r.context ?? 0;
  const pct = r.contextWindow ? ctx / r.contextWindow : 0;
  if (ctx >= CTX_CRIT || pct >= 0.9) return 'red';
  if (ctx >= CTX_WARN || pct >= 0.75) return 'yellow';
  return undefined;
}

export const contextPct = (r: Pick<AgentRow, 'context' | 'contextWindow'>): number | undefined =>
  r.context !== undefined && r.contextWindow ? Math.round((r.context / r.contextWindow) * 100) : undefined;

/** Mały pasek kontekstu: ▪▪▫▫▫. */
export function meter(r: Pick<AgentRow, 'context' | 'contextWindow'>, cells = 5): Seg[] {
  const pct = contextPct(r);
  if (pct === undefined) return [seg('▫'.repeat(cells), { dim: true })];
  const filled = Math.min(cells, Math.round((pct / 100) * cells));
  const color = contextColor(r);
  return [seg('▪'.repeat(filled), color ? { color } : {}), seg('▫'.repeat(cells - filled), { dim: true })];
}

/** Duży pasek kontekstu do szczegółów agenta. */
export function bar(r: Pick<AgentRow, 'context' | 'contextWindow'>, width: number): Seg[] {
  const pct = contextPct(r) ?? 0;
  const filled = Math.min(width, Math.round((pct / 100) * width));
  const color = contextColor(r) ?? 'white';
  return [seg('█'.repeat(filled), { color }), seg('░'.repeat(width - filled), { dim: true })];
}
