// Stan agentów jednej sesji → model widoku: wiersze, zdrowie, oś czasu, błędy, graf i przegląd.
// Czyste funkcje (czas „teraz" przychodzi z zewnątrz), więc całość da się przetestować bez terminala.

import { type Usage, addUsage, contextWindow, costOf, emptyUsage, shortModel, totalTokens } from './parse/pricing.js';
import type { TeamConfig } from './parse/team.js';
import type { ProblemKind } from './parse/tools.js';
import type { Problem, TimelineEvent, TranscriptState } from './parse/transcript.js';
import { fmtDuration, fmtTokens } from './units.js';

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
export type HealthLevel = 'ok' | 'uwaga' | 'problem';

export interface HealthIssue {
  level: Exclude<HealthLevel, 'ok'>;
  text: string;
}

export interface Health {
  level: HealthLevel;
  issues: HealthIssue[];
}

export interface AgentRow {
  key: string;
  kind: AgentKind;
  name: string;
  parent?: string;
  color?: string;
  model?: string;
  status: AgentStatus;
  action: string;
  /** Początek bieżącego stanu (ms) — do kolumny „czas". */
  since?: number;
  /** Ostatni rekord agenta (ms). */
  lastTs?: number;
  usage: Usage;
  tokens: number;
  /** Szacunek z cennika; undefined, gdy któryś model jest spoza cennika. */
  cost?: number;
  /** Koszt wg Claude Code — tylko sesja zamknięta (lead, członek). */
  exactCost?: number;
  /** Kontekst po ostatnim wywołaniu i okno modelu (szacunek). */
  context?: number;
  contextWindow?: number;
  /** Panel tmux członka zespołu. */
  paneId?: string;
  sessionId?: string;
  problems: number;
  health: Health;
}

export interface GraphEdge {
  from: string;
  to: string;
  kind: 'spawn' | 'subagent';
  /** Wiadomości rodzic → dziecko i dziecko → rodzic. */
  down: number;
  up: number;
}

export interface SideMessage {
  from: string;
  to: string;
  count: number;
}

export interface Overview {
  start?: number;
  end?: number;
  statusCounts: Record<AgentStatus, number>;
  usage: Usage;
  byModel: Array<{ model: string; tokens: number; cost?: number }>;
  tools: Array<{ name: string; calls: number; errors: number }>;
  messages: number;
  spawns: number;
  problemsByKind: Record<ProblemKind, number>;
}

export interface ViewModel {
  rows: AgentRow[];
  totals: { tokens: number; cost?: number; exactCost?: number };
  timeline: Array<TimelineEvent & { agent: string; agentKey: string; color?: string }>;
  problems: Array<Problem & { agent: string; agentKey: string; color?: string }>;
  edges: GraphEdge[];
  sideMessages: SideMessage[];
  overview: Overview;
}

export interface ViewInput {
  agents: AgentSource[];
  /** Bieżący config.json zespołu; undefined, gdy katalog zespołu nie istnieje (sesja zamknięta). */
  team?: TeamConfig;
  now: number;
}

// Progi kontekstu jak w scripts/statusline.sh: 150k — obserwuj, 250k — czas na /clear.
export const CTX_WARN = 150_000;
export const CTX_CRIT = 250_000;
/** Problemy starsze niż 30 min nie obniżają zdrowia. */
export const RECENT_MS = 30 * 60_000;
/** Narzędzie albo tura bez nowych rekordów dłużej niż 10 min — agent mógł utknąć. */
export const STUCK_MS = 10 * 60_000;

const LEAD_ALIASES = new Set(['team-lead', 'lead']);

function agentCost(s: TranscriptState): { usage: Usage; cost?: number } {
  let usage: Usage = emptyUsage();
  let cost: number | undefined = 0;
  for (const [key, u] of s.usage) {
    usage = addUsage(usage, u);
    const [model = '', speed] = key.split('|');
    const c = costOf(model, u, speed === 'fast');
    cost = c === undefined || cost === undefined ? undefined : cost + c;
  }
  return { usage, ...(cost === undefined ? {} : { cost }) };
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

const countBy = <T>(items: T[], key: (t: T) => string): Map<string, number> => {
  const m = new Map<string, number>();
  for (const i of items) m.set(key(i), (m.get(key(i)) ?? 0) + 1);
  return m;
};

/** Zdrowie agenta: kontekst, świeże blokady i błędy, ponowienia API, narzędzie albo tura bez postępu. */
export function healthOf(s: TranscriptState, status: AgentStatus, window: number | undefined, now: number): Health {
  const issues: HealthIssue[] = [];
  if (status === 'zamknięty' || status === 'zakończony') return { level: 'ok', issues };

  const ctx = s.context ?? 0;
  const pct = window ? ctx / window : 0;
  if (ctx >= CTX_CRIT || pct >= 0.9) issues.push({ level: 'problem', text: `kontekst ${fmtTokens(ctx)} — czas na /clear` });
  else if (ctx >= CTX_WARN || pct >= 0.75) issues.push({ level: 'uwaga', text: `kontekst ${fmtTokens(ctx)} — obserwuj` });

  const recent = s.problems.filter((p) => p.ts >= now - RECENT_MS);
  const byKind = countBy(recent, (p) => p.kind);
  const api = byKind.get('api') ?? 0;
  if (api > 0) issues.push({ level: 'problem', text: `błąd API ×${api}` });
  for (const [hook, n] of countBy(recent.filter((p) => p.kind === 'hook'), (p) => p.hook ?? 'hook')) {
    issues.push({ level: 'uwaga', text: `blokada hooka ${hook} ×${n}` });
  }
  const denied = byKind.get('permission') ?? 0;
  if (denied > 0) issues.push({ level: 'uwaga', text: `odmowa uprawnień ×${denied}` });
  const toolErrors = byKind.get('tool') ?? 0;
  if (toolErrors >= 3) issues.push({ level: 'uwaga', text: `błędy narzędzi ×${toolErrors}` });
  const retries = s.events.filter((e) => e.kind === 'retry' && e.ts >= now - RECENT_MS).length;
  if (retries > 0) issues.push({ level: 'uwaga', text: `ponowienia API ×${retries}` });

  const pending = [...s.pending.values()].sort((x, y) => x.start - y.start)[0];
  if (pending && now - pending.start >= STUCK_MS) {
    issues.push({ level: 'uwaga', text: `${pending.name} trwa ${fmtDuration(now - pending.start)}` });
  } else if (!pending && s.turnOpen && s.lastTs !== undefined && now - s.lastTs >= STUCK_MS) {
    issues.push({ level: 'uwaga', text: `brak aktywności ${fmtDuration(now - s.lastTs)}` });
  }

  const level: HealthLevel = issues.some((i) => i.level === 'problem') ? 'problem' : issues.length > 0 ? 'uwaga' : 'ok';
  return { level, issues };
}

export function buildView({ agents, team, now }: ViewInput): ViewModel {
  const lead = agents.find((a) => a.kind === 'lead');
  const leadDone = lead?.state.closed ?? false;
  const spawned = lead?.state.spawned;
  const member = (a: AgentSource) => (a.kind === 'teammate' ? team?.members.find((m) => m.name === a.name) : undefined);
  const colorOf = (a: AgentSource): string | undefined =>
    a.kind === 'teammate' ? (member(a)?.color ?? spawned?.get(a.name)?.color) : undefined;

  const rows: AgentRow[] = agents.map((a) => {
    const { usage, cost } = agentCost(a.state);
    const color = colorOf(a);
    const model = a.state.model ? shortModel(a.state.model) : undefined;
    const window = contextWindow(a.state.model);
    const paneId = a.kind === 'teammate' ? (member(a)?.tmuxPaneId ?? spawned?.get(a.name)?.paneId) : undefined;
    const st = statusOf(a, team, leadDone);
    const exact = a.kind !== 'subagent' && a.state.closed ? a.state.costUSD : undefined;
    return {
      key: a.key,
      kind: a.kind,
      name: a.name,
      ...(a.parent ? { parent: a.parent } : {}),
      ...(color ? { color } : {}),
      ...(model ? { model } : {}),
      ...st,
      ...(a.state.lastTs !== undefined ? { lastTs: a.state.lastTs } : {}),
      usage,
      tokens: totalTokens(usage),
      ...(cost === undefined ? {} : { cost }),
      ...(exact === undefined ? {} : { exactCost: exact }),
      ...(a.state.context !== undefined ? { context: a.state.context } : {}),
      ...(window ? { contextWindow: window } : {}),
      ...(paneId ? { paneId } : {}),
      ...(a.state.sessionId ? { sessionId: a.state.sessionId } : {}),
      problems: a.state.problems.length,
      health: healthOf(a.state, st.status, window, now),
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
      return a.state.events.map((e) => ({ ...e, agent: a.name, agentKey: a.key, ...(color ? { color } : {}) }));
    })
    .sort((x, y) => x.ts - y.ts);
  const problems = agents
    .flatMap((a) => {
      const color = colorOf(a);
      return a.state.problems.map((p) => ({ ...p, agent: a.name, agentKey: a.key, ...(color ? { color } : {}) }));
    })
    .sort((x, y) => x.ts - y.ts);

  // Graf: lead → członkowie (spawn, wiadomości w obie strony), rodzic → subagent.
  const teammates = agents.filter((a) => a.kind === 'teammate');
  const edges: GraphEdge[] = [];
  if (lead) {
    for (const t of teammates) {
      const up = [...t.state.sent].filter(([to]) => LEAD_ALIASES.has(to)).reduce((n, [, c]) => n + c, 0);
      edges.push({ from: lead.key, to: t.key, kind: 'spawn', down: lead.state.sent.get(t.name) ?? 0, up });
    }
  }
  for (const a of agents) {
    if (a.kind === 'subagent' && a.parent) edges.push({ from: a.parent, to: a.key, kind: 'subagent', down: 0, up: 0 });
  }
  const names = new Set(teammates.map((t) => t.name));
  const sideMessages: SideMessage[] = teammates.flatMap((t) =>
    [...t.state.sent].filter(([to]) => names.has(to) && to !== t.name).map(([to, count]) => ({ from: t.name, to, count })),
  );

  const statusCounts: Record<AgentStatus, number> = { pracuje: 0, myśli: 0, czeka: 0, zakończony: 0, zamknięty: 0 };
  for (const r of rows) statusCounts[r.status]++;
  const byModelMap = new Map<string, { tokens: number; cost?: number }>();
  const toolMap = new Map<string, { calls: number; errors: number }>();
  for (const a of agents) {
    for (const [key, u] of a.state.usage) {
      const [model = '', speed] = key.split('|');
      const name = shortModel(model);
      const prev = byModelMap.get(name) ?? { tokens: 0, cost: 0 };
      const c = costOf(model, u, speed === 'fast');
      byModelMap.set(name, {
        tokens: prev.tokens + totalTokens(u),
        ...(c === undefined || prev.cost === undefined ? {} : { cost: prev.cost + c }),
      });
    }
    for (const [name, c] of a.state.toolCounts) {
      const prev = toolMap.get(name) ?? { calls: 0, errors: 0 };
      toolMap.set(name, { calls: prev.calls + c.calls, errors: prev.errors + c.errors });
    }
  }
  const starts = agents.flatMap((a) => (a.state.firstTs !== undefined ? [a.state.firstTs] : []));
  const ends = agents.flatMap((a) => (a.state.lastTs !== undefined ? [a.state.lastTs] : []));
  const problemsByKind: Record<ProblemKind, number> = { hook: 0, permission: 0, tool: 0, api: 0 };
  for (const p of problems) problemsByKind[p.kind]++;
  const overview: Overview = {
    ...(starts.length ? { start: Math.min(...starts) } : {}),
    ...(ends.length ? { end: Math.max(...ends) } : {}),
    statusCounts,
    usage: rows.reduce((u, r) => addUsage(u, r.usage), emptyUsage()),
    byModel: [...byModelMap].map(([model, v]) => ({ model, ...v })).sort((x, y) => y.tokens - x.tokens),
    tools: [...toolMap].map(([name, v]) => ({ name, ...v })).sort((x, y) => y.calls - x.calls || x.name.localeCompare(y.name)),
    messages: timeline.filter((e) => e.kind === 'message').length,
    spawns: timeline.filter((e) => e.kind === 'spawn').length,
    problemsByKind,
  };

  return {
    rows,
    totals: { tokens, ...(cost === undefined ? {} : { cost }), ...(exactCost === undefined ? {} : { exactCost }) },
    timeline,
    problems,
    edges,
    sideMessages,
    overview,
  };
}
