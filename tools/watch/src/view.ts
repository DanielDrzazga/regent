// Stan agentów → model widoku: wiersze tabeli, oś czasu, błędy i sumy. Czysta funkcja,
// więc całość da się przetestować bez terminala; czas trwania liczy UI z pola since.

import { type Usage, addUsage, costOf, emptyUsage, shortModel, totalTokens } from './parse/pricing.js';
import type { TeamConfig } from './parse/team.js';
import type { Problem, TimelineEvent, TranscriptState } from './parse/transcript.js';

export type AgentKind = 'lead' | 'teammate' | 'subagent';

export interface AgentSource {
  key: string;
  kind: AgentKind;
  /** Nazwa w tabeli: „lead", nazwa członka zespołu albo „<rodzic>›<typ>" dla subagenta. */
  name: string;
  state: TranscriptState;
  /** Dla subagenta — klucz agenta, który go uruchomił. */
  parent?: string;
}

export type AgentStatus = 'pracuje' | 'myśli' | 'czeka' | 'zakończony' | 'zamknięty';

export interface AgentRow {
  key: string;
  kind: AgentKind;
  name: string;
  color?: string;
  model?: string;
  status: AgentStatus;
  action: string;
  /** Początek bieżącego stanu (ms) — do kolumny „czas". */
  since?: number;
  tokens: number;
  /** Szacunek z cennika; undefined, gdy któryś model jest spoza cennika. */
  cost?: number;
  problems: number;
}

export interface ViewModel {
  rows: AgentRow[];
  totals: { tokens: number; cost?: number; exactCost?: number };
  timeline: Array<TimelineEvent & { agent: string; color?: string }>;
  problems: Array<Problem & { agent: string; color?: string }>;
}

export interface ViewInput {
  agents: AgentSource[];
  /** Bieżący config.json zespołu; undefined, gdy katalog zespołu nie istnieje (sesja zamknięta). */
  team?: TeamConfig;
}

function agentCost(s: TranscriptState): { tokens: number; cost?: number } {
  let usage: Usage = emptyUsage();
  let cost: number | undefined = 0;
  for (const [key, u] of s.usage) {
    usage = addUsage(usage, u);
    const [model = '', speed] = key.split('|');
    const c = costOf(model, u, speed === 'fast');
    cost = c === undefined || cost === undefined ? undefined : cost + c;
  }
  return { tokens: totalTokens(usage), ...(cost === undefined ? {} : { cost }) };
}

function statusOf(a: AgentSource, team: TeamConfig | undefined, leadDone: boolean): Pick<AgentRow, 'status' | 'action' | 'since'> {
  const s = a.state;
  const gone =
    (a.kind === 'lead' && s.closed) ||
    (a.kind === 'teammate' && (!team || !team.members.some((m) => m.name === a.name))) ||
    (a.kind === 'subagent' && leadDone && !s.turnOpen);
  const pending = [...s.pending.values()].sort((x, y) => y.start - x.start)[0];
  if (gone && !pending) return { status: 'zamknięty', action: '' };
  if (pending) return { status: 'pracuje', action: pending.summary ? `${pending.name} ${pending.summary}` : pending.name, since: pending.start };
  if (s.turnOpen) return { status: 'myśli', action: '', ...(s.lastTs ? { since: s.lastTs } : {}) };
  if (a.kind === 'subagent') return { status: 'zakończony', action: '' };
  return { status: 'czeka', action: '', ...(s.lastTurnEnd ? { since: s.lastTurnEnd } : {}) };
}

export function buildView({ agents, team }: ViewInput): ViewModel {
  const lead = agents.find((a) => a.kind === 'lead');
  const leadDone = lead?.state.closed ?? false;
  const colorOf = (a: AgentSource): string | undefined =>
    a.kind === 'teammate' ? team?.members.find((m) => m.name === a.name)?.color : undefined;

  const rows: AgentRow[] = agents.map((a) => {
    const { tokens, cost } = agentCost(a.state);
    const color = colorOf(a);
    const model = a.state.model ? shortModel(a.state.model) : undefined;
    return {
      key: a.key,
      kind: a.kind,
      name: a.name,
      ...(color ? { color } : {}),
      ...(model ? { model } : {}),
      ...statusOf(a, team, leadDone),
      tokens,
      ...(cost === undefined ? {} : { cost }),
      problems: a.state.problems.length,
    };
  });

  const tokens = rows.reduce((t, r) => t + r.tokens, 0);
  const cost = rows.every((r) => r.cost !== undefined) ? rows.reduce((t, r) => t + (r.cost ?? 0), 0) : undefined;
  // Koszt wg Claude Code, gdy każda sesja (lead i członkowie) zapisała cost-state; subagenci
  // biegną w procesie rodzica, więc są w jego koszcie.
  const sessions = agents.filter((a) => a.kind !== 'subagent');
  const exactCost =
    sessions.length > 0 && sessions.every((a) => a.state.costUSD !== undefined)
      ? sessions.reduce((t, a) => t + (a.state.costUSD ?? 0), 0)
      : undefined;

  const timeline = agents
    .flatMap((a) => {
      const color = colorOf(a);
      return a.state.events.map((e) => ({ ...e, agent: a.name, ...(color ? { color } : {}) }));
    })
    .sort((x, y) => x.ts - y.ts);
  const problems = agents
    .flatMap((a) => {
      const color = colorOf(a);
      return a.state.problems.map((p) => ({ ...p, agent: a.name, ...(color ? { color } : {}) }));
    })
    .sort((x, y) => x.ts - y.ts);

  return {
    rows,
    totals: { tokens, ...(cost === undefined ? {} : { cost }), ...(exactCost === undefined ? {} : { exactCost }) },
    timeline,
    problems,
  };
}
