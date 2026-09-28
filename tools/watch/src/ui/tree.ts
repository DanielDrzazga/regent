// Drzewo po lewej (jak Explorer w OpenRig): projekt → sesja → lead, członkowie, subagenci,
// a pod spodem sekcja Uwaga. Czysta funkcja: dane + stan rozwinięcia → wiersze z liniami.

import type { AgentRow, HealthLevel, ViewModel } from '../view.js';
import { type Line, padLine, seg } from './lines.js';
import { HEALTH_COLOR, HEALTH_MARK, contextColor, contextPct, inkColor, isBusy, spinner, statusDot } from './style.js';

export interface TreeSession {
  key: string;
  id: string;
  project: { name: string; path: string };
  view: ViewModel;
}

export type TreeRow =
  | { kind: 'project'; key: string; line: Line }
  | { kind: 'section'; key: string; line: Line }
  | { kind: 'session'; key: string; session: string; line: Line }
  | { kind: 'agent'; key: string; session: string; agent: string; line: Line }
  | { kind: 'attention'; key: string; session: string; agent: string; line: Line };

export const selectable = (r: TreeRow): boolean => r.kind === 'session' || r.kind === 'agent' || r.kind === 'attention';
export const agentRowKey = (agent: string): string => `agent:${agent}`;

const LEVEL_ORDER: Record<HealthLevel, number> = { ok: 0, uwaga: 1, problem: 2 };
const worst = (rows: AgentRow[]): HealthLevel =>
  rows.reduce<HealthLevel>((w, r) => (LEVEL_ORDER[r.health.level] > LEVEL_ORDER[w] ? r.health.level : w), 'ok');

/** Agenci w kolejności drzewa z głębokością i informacją, czy są ostatnim dzieckiem. */
export function hierarchy(rows: AgentRow[]): Array<{ row: AgentRow; prefix: string }> {
  const lead = rows.find((r) => r.kind === 'lead');
  const children = new Map<string, AgentRow[]>();
  const push = (parent: string, r: AgentRow) => children.set(parent, [...(children.get(parent) ?? []), r]);
  for (const r of rows) {
    if (r === lead) continue;
    const parent = r.kind === 'subagent' && r.parent && rows.some((p) => p.key === r.parent) ? r.parent : lead?.key;
    if (parent) push(parent, r);
  }
  const out: Array<{ row: AgentRow; prefix: string }> = [];
  const walk = (r: AgentRow, stems: string, last: boolean, root: boolean) => {
    out.push({ row: r, prefix: root ? '' : `${stems}${last ? '└ ' : '├ '}` });
    const kids = children.get(r.key) ?? [];
    kids.forEach((k, i) => walk(k, root ? '' : `${stems}${last ? '  ' : '│ '}`, i === kids.length - 1, false));
  };
  if (lead) walk(lead, '', true, true);
  else rows.forEach((r) => out.push({ row: r, prefix: '' }));
  return out;
}

const shortName = (r: AgentRow): string => (r.kind === 'subagent' ? (r.name.split('›').pop() ?? r.name) : r.name);

function agentLine(r: AgentRow, prefix: string, indent: string, width: number, frame: number): Line {
  const pct = contextPct(r);
  const ctxColor = contextColor(r);
  const right: Line = [
    seg(pct === undefined ? '    ' : `${String(pct).padStart(3)}%`, ctxColor ? { color: ctxColor } : { dim: true }),
    seg(' '),
    r.health.level === 'ok' ? seg(' ') : seg(HEALTH_MARK[r.health.level], { color: HEALTH_COLOR[r.health.level] }),
  ];
  const nameColor = inkColor(r.color);
  const left: Line = [
    seg(indent + prefix, { dim: true }),
    statusDot(r.status, frame),
    seg(' '),
    seg(shortName(r), {
      ...(nameColor ? { color: nameColor } : {}),
      ...(r.status === 'zamknięty' || r.kind === 'subagent' ? { dim: true } : {}),
    }),
  ];
  return [...padLine(left, width - 6), ...right];
}

function sessionLine(s: TreeSession, expanded: boolean, width: number, frame: number): Line {
  const busy = s.view.rows.some((r) => isBusy(r.status));
  const closed = s.view.rows.every((r) => r.status === 'zamknięty' || r.status === 'zakończony');
  const level = worst(s.view.rows);
  const left: Line = [
    seg(`  ${expanded ? '▾' : '›'} `, { dim: true }),
    busy ? seg(spinner(frame), { color: 'green' }) : closed ? seg('○', { dim: true }) : seg('●', { color: 'gray' }),
    seg(` sesja ${s.id.slice(0, 8)}`, closed ? { dim: true } : {}),
  ];
  const right: Line = [
    seg(String(s.view.rows.length).padStart(4), { dim: true }),
    seg(' '),
    level === 'ok' ? seg(' ') : seg(HEALTH_MARK[level], { color: HEALTH_COLOR[level] }),
  ];
  return [...padLine(left, width - 6), ...right];
}

export interface TreeInput {
  sessions: TreeSession[];
  expanded: Set<string>;
  filter: string;
  width: number;
  frame: number;
}

export function treeRows({ sessions, expanded, filter, width, frame }: TreeInput): TreeRow[] {
  const q = filter.trim().toLowerCase();
  const matches = (t: string) => q === '' || t.toLowerCase().includes(q);
  const rows: TreeRow[] = [];
  const projects = new Map<string, TreeSession[]>();
  for (const s of sessions) projects.set(s.project.path, [...(projects.get(s.project.path) ?? []), s]);

  for (const [path, list] of projects) {
    const visible = list.flatMap((s) => {
      const hit = matches(s.project.name) || matches(s.id.slice(0, 8));
      const agents = hierarchy(s.view.rows).filter(({ row }) => hit || matches(row.name));
      return hit || agents.length > 0 ? [{ s, agents, forced: !hit && q !== '' }] : [];
    });
    if (visible.length === 0) continue;
    const name = list[0]?.project.name ?? path;
    rows.push({
      kind: 'project',
      key: `project:${path}`,
      line: padLine([seg('▪ ', { color: 'blue' }), seg(name, { bold: true }), seg(`  ${visible.length}`, { dim: true })], width),
    });
    for (const { s, agents, forced } of visible) {
      const open = forced || expanded.has(s.key);
      rows.push({ kind: 'session', key: s.key, session: s.key, line: sessionLine(s, open, width, frame) });
      if (!open) continue;
      for (const { row, prefix } of agents) {
        rows.push({ kind: 'agent', key: agentRowKey(row.key), session: s.key, agent: row.key, line: agentLine(row, prefix, '    ', width, frame) });
      }
    }
  }

  const attention = sessions.flatMap((s) =>
    s.view.rows.filter((r) => r.health.level !== 'ok').map((r) => ({ s, r })),
  );
  rows.push({ kind: 'section', key: 'section:attention', line: [] });
  rows.push({
    kind: 'section',
    key: 'section:attention-title',
    line: [seg('UWAGA', { bold: true, ...(attention.length ? { color: 'yellow' } : {}) }), seg(` (${attention.length})`, { dim: true })],
  });
  if (attention.length === 0) rows.push({ kind: 'section', key: 'section:attention-none', line: [seg('  wszystko w porządku', { dim: true })] });
  for (const { s, r } of attention) {
    const issue = r.health.issues[0]?.text ?? '';
    rows.push({
      kind: 'attention',
      key: `attn:${r.key}`,
      session: s.key,
      agent: r.key,
      line: padLine(
        [
          seg(`  ${HEALTH_MARK[r.health.level]} `, { color: HEALTH_COLOR[r.health.level] }),
          seg(shortName(r)),
          seg(` ${s.project.name}`, { dim: true }),
          seg(` · ${issue}`, { dim: true }),
        ],
        width,
      ),
    });
  }
  return rows;
}
