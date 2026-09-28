// Skok do panelu tmux agenta (klawisz t). Zmienia tylko fokus tmux — dane dalej tylko do odczytu.

import { execFileSync } from 'node:child_process';

/** Uruchamia tmux z argumentami i zwraca stdout; do testów podmieniany. */
export type TmuxRun = (args: string[]) => string;

export const runTmux: TmuxRun = (args) => execFileSync('tmux', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });

export const inTmux = (): boolean => Boolean(process.env.TMUX);

/**
 * Panel leada: w oknie, w którym są panele członków zespołu, ten panel, który nie jest członkiem
 * ani samym widokiem. Bez członków lead nie ma panelu, który dałoby się wskazać.
 */
export function findLeadPane(memberPanes: string[], selfPane: string | undefined, run: TmuxRun = runTmux): string | undefined {
  const first = memberPanes[0];
  if (!first) return undefined;
  try {
    const window = run(['display-message', '-p', '-t', first, '#{window_id}']).trim();
    const panes = run(['list-panes', '-t', window, '-F', '#{pane_id}'])
      .split('\n')
      .map((p) => p.trim())
      .filter(Boolean);
    return panes.find((p) => !memberPanes.includes(p) && p !== selfPane);
  } catch {
    return undefined;
  }
}

/** Przełącza okno i panel tmux; zwraca komunikat do stopki. */
export function jumpToPane(pane: string, run: TmuxRun = runTmux): { ok: boolean; message: string } {
  try {
    run(['select-window', '-t', pane]);
    run(['select-pane', '-t', pane]);
    return { ok: true, message: `tmux: panel ${pane}` };
  } catch {
    return { ok: false, message: `tmux: nie ma panelu ${pane} (zamknięty?)` };
  }
}
