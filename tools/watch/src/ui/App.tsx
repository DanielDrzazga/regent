// Widok Ink w stylu OpenRig: drzewo sesji i agentów po lewej, zakładki albo szczegóły agenta
// po prawej, podsumowanie i ostatnie zdarzenie w stopce. Dane tylko do odczytu.

import { type FSWatcher, watch } from 'node:fs';
import { homedir } from 'node:os';
import { Box, Text, useAnimation, useApp, useInput, useWindowSize } from 'ink';
import { useEffect, useMemo, useRef, useState } from 'react';
import { type TmuxRun, findLeadPane, jumpToPane, runTmux } from '../tmux.js';
import { fmtCost } from '../units.js';
import type { AgentRow, ViewModel } from '../view.js';
import { type SessionEntry, projectLabel } from '../workspace.js';
import { graphLines } from './graph.js';
import { type Line, type Seg, fitLine, maxOffset, padLine, seg, viewport } from './lines.js';
import {
  EVENT_MARK,
  type Tab,
  TABS,
  detailLines,
  fmtClock,
  healthLines,
  helpLines,
  overviewLines,
  tableLines,
  tabsLine,
  timelineLines,
} from './panes.js';
import { THEME, inkColor, isBusy } from './style.js';
import { type TreeRow, type TreeSession, agentRowKey, selectable, treeRows } from './tree.js';

export interface WorkspaceSource {
  refresh(now?: number): void;
  sessions(): SessionEntry[];
  readonly watchDirs?: string[];
}

export interface AppProps {
  source: WorkspaceSource;
  /** Odświeżanie awaryjne, gdy fs.watch nie zgłosi zmiany (ms). */
  intervalMs?: number;
  /** Klawiatura (wymaga TTY na stdin). */
  interactive?: boolean;
  /** Stały czas i klatka animacji — do testów. */
  now?: number;
  frame?: number;
  tmux?: { inTmux: boolean; run: TmuxRun; selfPane?: string };
  /** Stały rozmiar ekranu — do testów (domyślnie rozmiar terminala). */
  size?: { columns: number; rows: number };
}

interface SessionData {
  entry: SessionEntry;
  view: ViewModel;
  tree: TreeSession;
}

const shortPath = (p: string): string => {
  const home = homedir();
  return p.startsWith(`${home}/`) ? `~${p.slice(home.length)}` : p;
};

function load(source: WorkspaceSource, now: number): SessionData[] {
  source.refresh(now);
  return source.sessions().map((entry) => {
    const view = entry.store.view(now);
    return { entry, view, tree: { key: entry.leadFile, id: entry.store.leadSessionId, project: projectLabel(entry), view } };
  });
}

function useLive(source: WorkspaceSource, intervalMs: number, fixedNow?: number): { data: SessionData[]; now: number } {
  const [state, setState] = useState(() => {
    const now = fixedNow ?? Date.now();
    return { data: load(source, now), now };
  });
  useEffect(() => {
    if (fixedNow !== undefined) return undefined;
    let timer: NodeJS.Timeout | undefined;
    const update = () => {
      const now = Date.now();
      setState({ data: load(source, now), now });
    };
    const debounced = () => {
      clearTimeout(timer);
      timer = setTimeout(update, 150);
    };
    const watchers: FSWatcher[] = [];
    for (const dir of source.watchDirs ?? []) {
      try {
        watchers.push(watch(dir, { persistent: false }, debounced));
      } catch {
        // katalog jeszcze nie istnieje — zostaje odświeżanie cykliczne
      }
    }
    const interval = setInterval(update, intervalMs);
    return () => {
      clearInterval(interval);
      clearTimeout(timer);
      for (const w of watchers) w.close();
    };
  }, [source, intervalMs, fixedNow]);
  return state;
}

function renderSeg(s: Seg, i: number) {
  return (
    <Text key={i} {...(s.color ? { color: s.color } : {})} bold={s.bold ?? false} dimColor={s.dim ?? false} inverse={s.inverse ?? false}>
      {s.text}
    </Text>
  );
}

function Lines({ lines, width }: { lines: Line[]; width: number }) {
  return (
    <>
      {lines.map((l, i) => (
        <Text key={i} wrap="truncate-end">
          {l.length === 0 ? ' ' : fitLine(l, width).map(renderSeg)}
        </Text>
      ))}
    </>
  );
}

/** Ramka z tytułem w górnej krawędzi: ╭─ TYTUŁ ─────╮. */
function Frame({ title, width, height, children }: { title: Line; width: number; height: number; children: React.ReactNode }) {
  const titleW = [...title.map((s) => s.text).join('')].length;
  const rest = Math.max(0, width - titleW - 5);
  return (
    <Box flexDirection="column" width={width} height={height}>
      <Text wrap="truncate-end">
        <Text color={THEME.frame}>╭─ </Text>
        {title.map(renderSeg)}
        <Text color={THEME.frame}> {'─'.repeat(rest)}╮</Text>
      </Text>
      <Box borderStyle="round" borderTop={false} borderColor={THEME.frame} width={width} height={height - 1} flexDirection="column" paddingX={1} overflow="hidden">
        {children}
      </Box>
    </Box>
  );
}

const highlight = (line: Line, width: number): Line => padLine(line, width).map((s) => ({ ...s, inverse: true }));

export function App({ source, intervalMs = 1000, interactive = true, now: fixedNow, frame: fixedFrame, tmux, size }: AppProps) {
  const { exit } = useApp();
  const windowSize = useWindowSize();
  const { columns, rows } = size ?? windowSize;
  const { data, now } = useLive(source, intervalMs, fixedNow);
  const anyBusy = data.some((d) => d.view.rows.some((r) => isBusy(r.status)));
  const anim = useAnimation({ interval: 250, isActive: anyBusy && fixedFrame === undefined });
  const frame = fixedFrame ?? anim.frame;
  const tmuxEnv = tmux ?? { inTmux: Boolean(process.env.TMUX), run: runTmux, ...(process.env.TMUX_PANE ? { selfPane: process.env.TMUX_PANE } : {}) };

  const first = data[0]?.entry.leadFile ?? '';
  const [selected, setSelected] = useState<string>(first);
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set(first ? [first] : []));
  const [tab, setTab] = useState<Tab>('tabela');
  const [scroll, setScroll] = useState<Record<string, number>>({});
  const [filter, setFilter] = useState('');
  const [filtering, setFiltering] = useState(false);
  const [help, setHelp] = useState(false);
  const [message, setMessage] = useState<{ text: string; until: number } | undefined>();

  const leftW = Math.min(44, Math.max(30, Math.round(columns * 0.28)));
  const rightW = Math.max(40, columns - leftW);
  const height = Math.max(8, rows - 2);
  const innerH = height - 2;
  const leftInner = leftW - 4;
  const rightInner = rightW - 4;

  const tree = useMemo(
    () => treeRows({ sessions: data.map((d) => d.tree), expanded, filter, width: leftInner, frame }),
    [data, expanded, filter, leftInner, frame],
  );
  const selectableRows = tree.filter(selectable);
  const current: TreeRow | undefined = tree.find((r) => r.key === selected) ?? selectableRows[0];
  const sessionKey = current && 'session' in current ? current.session : undefined;
  const session = data.find((d) => d.entry.leadFile === sessionKey);
  const agentKey = current && (current.kind === 'agent' || current.kind === 'attention') ? current.agent : undefined;
  const agent: AgentRow | undefined = agentKey ? session?.view.rows.find((r) => r.key === agentKey) : undefined;

  // Przewinięta oś czasu trzyma oglądany fragment: nowe zdarzenia zwiększają odległość od końca.
  const seen = useRef(new Map<string, number>());
  useEffect(() => {
    for (const d of data) {
      const k = `${d.entry.leadFile}:oś`;
      const prev = seen.current.get(k);
      const n = d.view.timeline.length;
      seen.current.set(k, n);
      if (prev !== undefined && n > prev) setScroll((s) => ((s[k] ?? 0) > 0 ? { ...s, [k]: (s[k] ?? 0) + n - prev } : s));
    }
  }, [data]);

  const paneKey = help ? 'help' : agent ? `detail:${agent.key}` : `${sessionKey ?? ''}:${tab}`;
  const anchor: 'top' | 'bottom' = !help && !agent && tab === 'oś' ? 'bottom' : 'top';

  const content: Line[] = useMemo(() => {
    if (help) return helpLines(rightInner);
    if (!session) return [[seg('Brak aktywnych sesji — uruchom claude albo zwiększ --active.', { dim: true })]];
    if (agent) {
      return detailLines({ row: agent, view: session.view, transcript: shortPath(agent.key), now, width: rightInner, frame, inTmux: tmuxEnv.inTmux });
    }
    switch (tab) {
      case 'tabela':
        return tableLines(session.view, now, rightInner, frame);
      case 'oś':
        return timelineLines(session.view);
      case 'graf':
        return graphLines(session.view, frame);
      case 'przegląd':
        return overviewLines(session.view, { id: session.tree.id, path: session.tree.project.path, transcript: shortPath(session.entry.leadFile) }, now, rightInner);
      case 'zdrowie':
        return healthLines(session.view, rightInner);
    }
  }, [help, session, agent, tab, now, rightInner, frame, tmuxEnv.inTmux]);

  const header: Line[] = !help && session && !agent ? [tabsLine(tab), []] : [];
  const bodyH = innerH - header.length;
  const offset = scroll[paneKey] ?? 0;
  const body = viewport(content, bodyH, offset, anchor);

  const title: Line = help
    ? [seg('POMOC', { bold: true, color: THEME.title })]
    : agent
      ? [seg('agent ', { dim: true }), seg(agent.name, { bold: true, ...(inkColor(agent.color) ? { color: inkColor(agent.color) as string } : {}) }), seg(` · ${agent.status}`, { dim: true })]
      : session
        ? [seg('sesja ', { dim: true }), seg(session.tree.id.slice(0, 8), { bold: true, color: THEME.title }), seg(` · ${session.tree.project.name}`, { dim: true })]
        : [seg('regent-watch', { bold: true })];

  // Drzewo: zaznaczenie zawsze widoczne.
  const treeOffset = useRef(0);
  const selIndex = Math.max(0, tree.findIndex((r) => r.key === current?.key));
  if (selIndex < treeOffset.current) treeOffset.current = selIndex;
  if (selIndex >= treeOffset.current + innerH) treeOffset.current = selIndex - innerH + 1;
  treeOffset.current = Math.min(treeOffset.current, maxOffset(tree.length, innerH));
  const treeLines = tree.slice(treeOffset.current, treeOffset.current + innerH).map((r) => (r.key === current?.key ? highlight(r.line, leftInner) : r.line));

  // Stopka: podsumowanie i ostatnie zdarzenie ze wszystkich sesji.
  const allRows = data.flatMap((d) => d.view.rows);
  const working = allRows.filter((r) => r.status === 'pracuje' || r.status === 'myśli').length;
  const attention = allRows.filter((r) => r.health.level !== 'ok').length;
  const cost = data.every((d) => d.view.totals.cost !== undefined) ? data.reduce((t, d) => t + (d.view.totals.cost ?? 0), 0) : undefined;
  const lastEvent = data
    .flatMap((d) => d.view.timeline.filter((e) => e.kind !== 'turn-end').slice(-1).map((e) => ({ e, project: d.tree.project.name })))
    .sort((a, b) => b.e.ts - a.e.ts)[0];
  const summary: Line = [
    seg(`${data.length} ${data.length === 1 ? 'sesja' : 'sesji'}`, { bold: true }),
    seg(` · ${allRows.length} agentów · `, { dim: true }),
    seg(`${working} pracuje`, { color: 'green' }),
    seg(' · ', { dim: true }),
    seg(`${attention} wymaga uwagi`, attention ? { color: 'yellow' } : { dim: true }),
    seg(` · ≈${fmtCost(cost)}`, { dim: true }),
    ...(lastEvent
      ? [
          seg('   '),
          seg(fmtClock(lastEvent.e.ts), { dim: true }),
          seg(` ${lastEvent.e.agent}`, inkColor(lastEvent.e.color) ? { color: inkColor(lastEvent.e.color) as string } : {}),
          seg(` (${lastEvent.project}) `, { dim: true }),
          seg(`${lastEvent.e.problem === 'hook' ? '⊘' : EVENT_MARK[lastEvent.e.kind]} ${lastEvent.e.text}`, lastEvent.e.kind === 'error' ? { color: 'red' } : {}),
        ]
      : []),
  ];
  const keys: Line = filtering
    ? [seg('/', { color: 'cyan', bold: true }), seg(filter), seg('▏', { color: 'cyan' }), seg('   Enter — zatwierdź · Esc — wyczyść', { dim: true })]
    : message && message.until > Date.now()
      ? [seg(message.text, { color: 'yellow' })]
      : [
          ...(filter ? [seg(`filtr: ${filter}  `, { color: 'cyan' })] : []),
          seg('↑↓ wybór · ←→ zwiń/rozwiń · Enter szczegóły · Tab/1–5 widok · PgUp/PgDn przewiń · t tmux · / filtr · ? pomoc · q wyjście', { dim: true }),
        ];

  const say = (text: string) => setMessage({ text, until: Date.now() + 4000 });
  const move = (delta: number) => {
    const i = selectableRows.findIndex((r) => r.key === current?.key);
    const next = selectableRows[Math.min(selectableRows.length - 1, Math.max(0, i + delta))];
    if (next) setSelected(next.key);
  };
  const toSession = () => sessionKey && setSelected(sessionKey);
  const setOffset = (fn: (o: number) => number) => {
    const max = maxOffset(content.length, bodyH);
    setScroll((s) => ({ ...s, [paneKey]: Math.min(max, Math.max(0, fn(s[paneKey] ?? 0))) }));
  };
  const jump = () => {
    if (!tmuxEnv.inTmux) return say('tmux: widok nie działa w tmux — skok niedostępny');
    if (!session) return;
    const target = agent?.kind === 'subagent' ? session.view.rows.find((r) => r.key === agent.parent) : agent;
    const members = session.view.rows.filter((r) => r.kind === 'teammate' && r.status !== 'zamknięty' && r.paneId).map((r) => r.paneId as string);
    const pane = target?.kind === 'teammate' ? target.paneId : findLeadPane(members, tmuxEnv.selfPane, tmuxEnv.run);
    if (!pane) return say(target?.kind === 'teammate' ? 'tmux: członek nie ma panelu' : 'tmux: panel leada da się wskazać tylko przy żywym zespole');
    return say(jumpToPane(pane, tmuxEnv.run).message);
  };

  useInput(
    (input, key) => {
      if (filtering) {
        if (key.escape) {
          setFilter('');
          setFiltering(false);
        } else if (key.return) setFiltering(false);
        else if (key.backspace || key.delete) setFilter((f) => f.slice(0, -1));
        else if (input && !key.ctrl && !key.meta) setFilter((f) => f + input);
        return;
      }
      if (help) {
        if (input === 'q') exit();
        setHelp(false);
        return;
      }
      if (input === 'q') exit();
      else if (input === '?') setHelp(true);
      else if (input === '/') setFiltering(true);
      else if (key.upArrow || input === 'k') move(-1);
      else if (key.downArrow || input === 'j') move(1);
      else if (key.rightArrow || input === 'l' || (key.return && current?.kind === 'session')) {
        if (current?.kind === 'session') setExpanded((e) => new Set([...e, current.key]));
      } else if (key.leftArrow || input === 'h') {
        if (current?.kind === 'session') setExpanded((e) => new Set([...e].filter((k) => k !== current.key)));
        else toSession();
      } else if (key.return && current?.kind === 'attention') {
        setExpanded((e) => new Set([...e, current.session]));
        setSelected(agentRowKey(current.agent));
      } else if (key.escape) {
        if (agent) toSession();
        else if (filter) setFilter('');
      } else if (key.tab || /^[1-5]$/.test(input)) {
        const i = TABS.findIndex((t) => t.id === tab);
        const next = /^[1-5]$/.test(input) ? Number(input) - 1 : (i + (key.shift ? TABS.length - 1 : 1)) % TABS.length;
        setTab(TABS[next]?.id ?? 'tabela');
        if (agent) toSession();
      } else if (key.pageUp) setOffset((o) => (anchor === 'bottom' ? o + bodyH - 1 : o - bodyH + 1));
      else if (key.pageDown) setOffset((o) => (anchor === 'bottom' ? o - bodyH + 1 : o + bodyH - 1));
      else if (key.home || input === 'g') setOffset(() => (anchor === 'bottom' ? Number.MAX_SAFE_INTEGER : 0));
      else if (key.end || input === 'G') setOffset(() => (anchor === 'bottom' ? 0 : Number.MAX_SAFE_INTEGER));
      else if (input === 't') jump();
    },
    { isActive: interactive },
  );

  return (
    <Box flexDirection="column" width={columns}>
      <Box flexDirection="row">
        <Frame title={[seg('SESJE', { bold: true, color: THEME.title }), seg(`  ${fmtClock(now)}`, { dim: true })]} width={leftW} height={height}>
          <Lines lines={treeLines} width={leftInner} />
        </Frame>
        <Frame title={title} width={rightW} height={height}>
          <Lines lines={[...header, ...body]} width={rightInner} />
        </Frame>
      </Box>
      <Text wrap="truncate-end">{fitLine(summary, columns).map(renderSeg)}</Text>
      <Text wrap="truncate-end">{fitLine(keys, columns).map(renderSeg)}</Text>
    </Box>
  );
}
