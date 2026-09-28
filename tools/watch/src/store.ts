// Stan jednej sesji na żywo: transkrypt leada, członków zespołu i subagentów czytany
// przyrostowo, config.json zespołu czytany przy każdym odświeżeniu.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { type TeamConfig, parseTeamConfig, teamNameFor } from './parse/team.js';
import { type TranscriptState, applyLines, createState } from './parse/transcript.js';
import { findSubagents, findTeammates, projectDir, sessionIdOf } from './session.js';
import { JsonlTail } from './tail.js';
import { type AgentKind, type AgentSource, type ViewModel, buildView } from './view.js';

interface Tracked {
  tail: JsonlTail;
  state: TranscriptState;
  kind: AgentKind;
  /** Klucz rodzica (plik transkryptu) — dla subagenta. */
  parent?: string;
  agentType?: string;
}

export interface StoreOptions {
  claudeDir: string;
  leadFile: string;
  /** Co ile ms szukać nowych członków zespołu i subagentów (czytanie plików — przy każdym odświeżeniu). */
  discoveryMs?: number;
}

export class SessionStore {
  readonly leadSessionId: string;
  readonly teamName: string;
  private readonly tracked = new Map<string, Tracked>();
  private team: TeamConfig | undefined;
  private lastDiscovery = Number.NEGATIVE_INFINITY;
  private readonly notTeammates = new Set<string>();

  constructor(private readonly opts: StoreOptions) {
    this.leadSessionId = sessionIdOf(opts.leadFile);
    this.teamName = teamNameFor(this.leadSessionId);
    this.track(opts.leadFile, 'lead');
  }

  get teamConfigFile(): string {
    return join(this.opts.claudeDir, 'teams', this.teamName, 'config.json');
  }

  /** Katalogi do obserwacji (fs.watch): projekt leada i katalog zespołu. */
  get watchDirs(): string[] {
    return [dirname(this.opts.leadFile), join(this.opts.claudeDir, 'teams', this.teamName)];
  }

  private track(file: string, kind: AgentKind, extra: Pick<Tracked, 'parent' | 'agentType'> = {}): void {
    if (this.tracked.has(file)) return;
    this.tracked.set(file, { tail: new JsonlTail(file), state: createState(), kind, ...extra });
  }

  private discover(): void {
    const lead = this.tracked.get(this.opts.leadFile);
    const since = (lead?.state.firstTs ?? 0) - 60_000;
    // Członek zespołu może pracować w innym katalogu (cwd z config.json) — wtedy jego
    // transkrypt leży w innym katalogu projektu.
    const dirs = [
      dirname(this.opts.leadFile),
      ...(this.team?.members.flatMap((m) => (m.cwd ? [projectDir(this.opts.claudeDir, m.cwd)] : [])) ?? []),
    ];
    for (const file of findTeammates(dirs, this.teamName, since, new Set(this.tracked.keys()), this.notTeammates)) {
      this.track(file, 'teammate');
    }
    for (const [file, t] of [...this.tracked]) {
      if (t.kind === 'subagent') continue;
      for (const sub of findSubagents(file)) {
        this.track(sub.file, 'subagent', { parent: file, ...(sub.agentType ? { agentType: sub.agentType } : {}) });
      }
    }
  }

  refresh(now = Date.now()): void {
    try {
      this.team = parseTeamConfig(readFileSync(this.teamConfigFile, 'utf8'));
    } catch {
      this.team = undefined; // brak zespołu albo sesja zamknięta
    }
    for (const t of this.tracked.values()) {
      const { lines, reset } = t.tail.read();
      if (reset) t.state = createState();
      applyLines(t.state, lines);
    }
    if (now - this.lastDiscovery >= (this.opts.discoveryMs ?? 3000)) {
      this.lastDiscovery = now;
      const before = this.tracked.size;
      this.discover();
      if (this.tracked.size > before) this.refresh(now); // dopiero co znalezione pliki — od razu wczytaj
    }
  }

  private nameOf(file: string, t: Tracked): string {
    if (t.kind === 'lead') return 'lead';
    if (t.kind === 'teammate') return t.state.agentName ?? sessionIdOf(file).slice(0, 8);
    const parent = t.parent ? this.tracked.get(t.parent) : undefined;
    const parentName = parent && t.parent ? this.nameOf(t.parent, parent) : '?';
    return `${parentName}›${t.agentType ?? 'agent'}`;
  }

  sources(): AgentSource[] {
    // Kolejność: lead, członkowie zespołu, subagenci — w grupie według pierwszego rekordu.
    const order: Record<AgentKind, number> = { lead: 0, teammate: 1, subagent: 2 };
    return [...this.tracked]
      .sort(([, a], [, b]) => order[a.kind] - order[b.kind] || (a.state.firstTs ?? 0) - (b.state.firstTs ?? 0))
      .map(([file, t]) => ({
        key: file,
        kind: t.kind,
        name: this.nameOf(file, t),
        state: t.state,
        ...(t.parent ? { parent: t.parent } : {}),
      }));
  }

  view(now = Date.now()): ViewModel {
    return buildView({ agents: this.sources(), ...(this.team ? { team: this.team } : {}), now });
  }
}
