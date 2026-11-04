// Transkrypt Claude Code (JSONL) → stan agenta: zdarzenia, bieżąca akcja, tokeny, błędy.
// Reduktor czyta rekord po rekordzie, więc nadaje się do przyrostowego czytania pliku.
// Nieznane typy rekordów i pola są pomijane — format jest wewnętrzny i może się zmieniać.

import { type Usage, addUsage, emptyUsage, usageFromRecord } from './pricing.js';
import { type ProblemKind, classifyError, resultText, summarizeTool } from './tools.js';

export type EventKind = 'prompt' | 'tool' | 'message' | 'spawn' | 'error' | 'retry' | 'turn-end';

export interface TimelineEvent {
  ts: number;
  kind: EventKind;
  text: string;
  problem?: ProblemKind;
}

export interface Problem {
  ts: number;
  kind: ProblemKind;
  tool: string;
  text: string;
  hook?: string;
}

export interface ToolCall {
  id: string;
  name: string;
  summary: string;
  start: number;
  end?: number;
  error?: boolean;
}

export interface SpawnedMember {
  color?: string;
  model?: string;
  paneId?: string;
}

export interface ToolCount {
  calls: number;
  errors: number;
}

export interface TranscriptState {
  sessionId?: string;
  /** Członek zespołu: nazwa i zespół (pola agentName/teamName w każdym rekordzie). */
  agentName?: string;
  teamName?: string;
  /** Subagent: agentId z rekordów isSidechain. */
  agentId?: string;
  cwd?: string;
  firstTs?: number;
  lastTs?: number;
  /** Ostatni model, który odpowiedział (bez <synthetic>). */
  model?: string;
  turnOpen: boolean;
  lastTurnEnd?: number;
  pending: Map<string, ToolCall>;
  lastTool?: ToolCall;
  events: TimelineEvent[];
  problems: Problem[];
  /** Tokeny per „model|speed" — koszt liczony osobno dla każdego modelu i trybu. */
  usage: Map<string, Usage>;
  seenMessages: Set<string>;
  seenToolUses: Set<string>;
  /** Rozmiar kontekstu po ostatnim wywołaniu API: wejście + zapis i odczyt cache. */
  context?: number;
  /** Wysłane wiadomości (SendMessage) per adresat. */
  sent: Map<string, number>;
  /** Wywołania i błędy per narzędzie. */
  toolCounts: Map<string, ToolCount>;
  /** Członkowie zespołu uruchomieni przez tę sesję (toolUseResult teammate_spawned). */
  spawned: Map<string, SpawnedMember>;
  /** Koszt wg Claude Code (rekord cost-state, zapisywany przy zamknięciu sesji). */
  costUSD?: number;
  /** Sesja zamknięta: ostatni był cost-state; wznowienie dopisuje nowe rekordy i kasuje flagę. */
  closed: boolean;
  invalidLines: number;
}

export function createState(): TranscriptState {
  return {
    turnOpen: false,
    closed: false,
    pending: new Map(),
    events: [],
    problems: [],
    usage: new Map(),
    sent: new Map(),
    toolCounts: new Map(),
    spawned: new Map(),
    seenMessages: new Set(),
    seenToolUses: new Set(),
    invalidLines: 0,
  };
}

type Rec = Record<string, unknown>;
const isObj = (v: unknown): v is Rec => typeof v === 'object' && v !== null && !Array.isArray(v);
const str = (v: unknown): string | undefined => (typeof v === 'string' && v !== '' ? v : undefined);

const clip = (s: string, n: number): string => {
  const line = s.replace(/\s+/g, ' ').trim();
  return line.length > n ? `${line.slice(0, n - 1)}…` : line;
};

export const TURN_END: ReadonlySet<string> = new Set(['end_turn', 'stop_sequence', 'max_tokens', 'refusal']);

function onAssistant(s: TranscriptState, rec: Rec, ts: number): void {
  const msg = rec.message;
  if (!isObj(msg)) return;

  if (rec.isApiErrorMessage === true) {
    const text = clip(resultText(msg.content) || str(rec.error) || 'błąd API', 300);
    s.problems.push({ ts, kind: 'api', tool: 'API', text });
    s.events.push({ ts, kind: 'error', problem: 'api', text: `API: ${text}` });
    s.turnOpen = false;
    s.lastTurnEnd = ts;
    return;
  }

  const id = str(msg.id);
  const model = str(msg.model);
  if (id && !s.seenMessages.has(id)) {
    s.seenMessages.add(id);
    if (model && model !== '<synthetic>' && isObj(msg.usage)) {
      const key = `${model}|${msg.usage.speed === 'fast' ? 'fast' : 'standard'}`;
      const u = usageFromRecord(msg.usage);
      s.usage.set(key, addUsage(s.usage.get(key) ?? emptyUsage(), u));
      s.context = u.input + u.cacheWrite5m + u.cacheWrite1h + u.cacheRead;
    }
  }
  if (model && model !== '<synthetic>') s.model = model;

  for (const block of Array.isArray(msg.content) ? msg.content : []) {
    if (!isObj(block) || block.type !== 'tool_use') continue;
    const toolId = str(block.id);
    const name = str(block.name) ?? '?';
    if (!toolId || s.seenToolUses.has(toolId)) continue;
    s.seenToolUses.add(toolId);
    const call: ToolCall = { id: toolId, name, summary: summarizeTool(name, block.input, s.cwd), start: ts };
    s.pending.set(toolId, call);
    s.lastTool = call;
    const count = s.toolCounts.get(name) ?? { calls: 0, errors: 0 };
    count.calls++;
    s.toolCounts.set(name, count);
    const input = isObj(block.input) ? block.input : {};
    if (name === 'SendMessage') {
      const to = str(input.to);
      if (to) s.sent.set(to, (s.sent.get(to) ?? 0) + 1);
      s.events.push({ ts, kind: 'message', text: call.summary });
    } else if ((name === 'Agent' || name === 'Task') && str(input.name)) {
      const m = str(input.model);
      s.events.push({ ts, kind: 'spawn', text: `${str(input.name)}${m ? ` (${m})` : ''}` });
    } else {
      s.events.push({ ts, kind: 'tool', text: call.summary ? `${name} ${call.summary}` : name });
    }
  }

  const stop = str(msg.stop_reason);
  if (stop && TURN_END.has(stop)) {
    s.turnOpen = false;
    s.lastTurnEnd = ts;
    s.pending.clear();
  } else {
    s.turnOpen = true;
  }
}

function promptText(content: unknown): string | undefined {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    const t = content.find((b) => isObj(b) && b.type === 'text');
    return isObj(t) ? str(t.text) : undefined;
  }
  return undefined;
}

function onUser(s: TranscriptState, rec: Rec, ts: number): void {
  const msg = rec.message;
  if (!isObj(msg)) return;
  const content = msg.content;

  const results = Array.isArray(content) ? content.filter((b) => isObj(b) && b.type === 'tool_result') : [];
  if (results.length > 0) {
    s.turnOpen = true;
    for (const r of results as Rec[]) {
      const toolId = str(r.tool_use_id) ?? '';
      const call = s.pending.get(toolId) ?? (s.lastTool?.id === toolId ? s.lastTool : undefined);
      s.pending.delete(toolId);
      if (call) call.end = ts;
      const spawn = rec.toolUseResult;
      if (isObj(spawn) && spawn.status === 'teammate_spawned' && str(spawn.name)) {
        const m: SpawnedMember = {};
        if (str(spawn.color)) m.color = str(spawn.color);
        if (str(spawn.model)) m.model = str(spawn.model);
        if (str(spawn.tmux_pane_id)) m.paneId = str(spawn.tmux_pane_id);
        s.spawned.set(str(spawn.name) as string, m);
      }
      if (r.is_error !== true) continue;
      const counted = call ? s.toolCounts.get(call.name) : undefined;
      if (counted) counted.errors++;
      const raw = resultText(r.content) || (typeof rec.toolUseResult === 'string' ? rec.toolUseResult : '');
      const err = classifyError(raw);
      const tool = call?.name ?? '?';
      if (call) call.error = true;
      s.problems.push({ ts, kind: err.kind, tool, text: err.text, ...(err.hook ? { hook: err.hook } : {}) });
      s.events.push({ ts, kind: 'error', problem: err.kind, text: `${tool}: ${err.text}` });
    }
    return;
  }

  if (rec.isMeta === true) return;
  const text = promptText(content);
  if (!text) return;
  s.turnOpen = true;
  // Wiadomość od innego agenta — nadawcę widać po jego SendMessage, więc tu jej nie dublujemy.
  if (text.slice(0, 300).includes('<teammate-message')) return;
  const cmd = /^<command-name>(.*?)<\/command-name>/.exec(text);
  if (cmd) {
    s.events.push({ ts, kind: 'prompt', text: cmd[1] ?? '' });
    return;
  }
  if (text.startsWith('<')) return; // system-reminder, task-notification, wyjście komend lokalnych
  s.events.push({ ts, kind: 'prompt', text: clip(text, 160) });
}

function onSystem(s: TranscriptState, rec: Rec, ts: number): void {
  if (rec.subtype === 'turn_duration') {
    s.turnOpen = false;
    s.lastTurnEnd = ts;
    s.pending.clear();
    const ms = typeof rec.durationMs === 'number' ? rec.durationMs : undefined;
    s.events.push({ ts, kind: 'turn-end', text: ms === undefined ? 'koniec tury' : `koniec tury (${Math.round(ms / 1000)} s)` });
  } else if (rec.subtype === 'api_error') {
    const n = typeof rec.retryAttempt === 'number' ? rec.retryAttempt : '?';
    const max = typeof rec.maxRetries === 'number' ? rec.maxRetries : '?';
    s.events.push({ ts, kind: 'retry', text: `błąd API, ponowienie ${n}/${max}` });
  }
}

export function applyRecord(s: TranscriptState, rec: unknown): void {
  if (!isObj(rec)) return;
  s.sessionId ??= str(rec.sessionId);
  s.agentName ??= str(rec.agentName);
  s.teamName ??= str(rec.teamName);
  if (rec.isSidechain === true) s.agentId ??= str(rec.agentId);
  s.cwd ??= str(rec.cwd);

  const parsed = typeof rec.timestamp === 'string' ? Date.parse(rec.timestamp) : Number.NaN;
  const ts = Number.isNaN(parsed) ? (s.lastTs ?? 0) : parsed;
  if (!Number.isNaN(parsed)) {
    s.firstTs ??= parsed;
    s.lastTs = Math.max(s.lastTs ?? parsed, parsed);
  }

  if (rec.type === 'user' || rec.type === 'assistant') s.closed = false;
  switch (rec.type) {
    case 'assistant':
      onAssistant(s, rec, ts);
      break;
    case 'user':
      onUser(s, rec, ts);
      break;
    case 'system':
      onSystem(s, rec, ts);
      break;
    case 'cost-state':
      if (typeof rec.totalCostUSD === 'number') s.costUSD = rec.totalCostUSD;
      s.closed = true;
      break;
  }
}

/** Kolejne pełne linie JSONL; niepoprawne linie są liczone i pomijane. */
export function applyLines(s: TranscriptState, lines: Iterable<string>): void {
  for (const line of lines) {
    if (!line.trim()) continue;
    let rec: unknown;
    try {
      rec = JSON.parse(line);
    } catch {
      s.invalidLines++;
      continue;
    }
    applyRecord(s, rec);
  }
}

export const parseTranscript = (text: string): TranscriptState => {
  const s = createState();
  applyLines(s, text.split('\n'));
  return s;
};
