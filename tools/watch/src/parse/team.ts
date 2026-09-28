// ~/.claude/teams/session-<8 znaków>/config.json → członkowie zespołu obecni w tej chwili.
// Plik opisuje tylko stan bieżący: członek po shutdownie znika z members, a cały katalog
// zespołu — po zamknięciu sesji leada. Historię agentów widok bierze z transkryptów.

export interface TeamMember {
  name: string;
  agentType?: string;
  model?: string;
  color?: string;
  tmuxPaneId?: string;
  backendType?: string;
  isActive?: boolean;
  cwd?: string;
}

export interface TeamConfig {
  name: string;
  leadSessionId?: string;
  members: TeamMember[];
}

type Rec = Record<string, unknown>;
const isObj = (v: unknown): v is Rec => typeof v === 'object' && v !== null && !Array.isArray(v);
const str = (v: unknown): string | undefined => (typeof v === 'string' && v !== '' ? v : undefined);

/** Nazwa zespołu sesji: „session-" + pierwsze 8 znaków ID sesji leada. */
export const teamNameFor = (leadSessionId: string): string => `session-${leadSessionId.slice(0, 8)}`;

/** Treść config.json → TeamConfig; undefined, gdy plik jest uszkodzony albo ma obcy kształt. */
export function parseTeamConfig(text: string): TeamConfig | undefined {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return undefined;
  }
  if (!isObj(raw) || !str(raw.name)) return undefined;
  const members: TeamMember[] = [];
  for (const m of Array.isArray(raw.members) ? raw.members : []) {
    if (!isObj(m) || !str(m.name)) continue;
    const member: TeamMember = { name: str(m.name) as string };
    for (const k of ['agentType', 'model', 'color', 'tmuxPaneId', 'backendType', 'cwd'] as const) {
      const v = str(m[k]);
      if (v) member[k] = v;
    }
    if (typeof m.isActive === 'boolean') member.isActive = m.isActive;
    members.push(member);
  }
  const lead = str(raw.leadSessionId);
  return { name: str(raw.name) as string, ...(lead ? { leadSessionId: lead } : {}), members };
}
