// Widok Ink: agenci z bieżącą akcją, oś czasu z przewijaniem, blokady i błędy, tokeny i koszt.

import { watch, type FSWatcher } from 'node:fs';
import { Box, Text, useApp, useInput, useWindowSize } from 'ink';
import { useEffect, useRef, useState } from 'react';
import type { ViewModel } from '../view.js';
import {
  EVENT_MARK,
  PROBLEM_LABEL,
  STATUS_COLOR,
  fit,
  fmtClock,
  fmtCost,
  fmtDuration,
  fmtTokens,
  inkColor,
} from './format.js';

export interface ViewSource {
  refresh(): void;
  view(): ViewModel;
  /** Katalogi obserwowane przez fs.watch — zmiana pliku odświeża widok od razu. */
  readonly watchDirs?: string[];
}

export interface AppProps {
  source: ViewSource;
  title: string;
  /** Odświeżanie awaryjne, gdy fs.watch nie zgłosi zmiany (ms). */
  intervalMs?: number;
  /** Klawiatura (wymaga TTY na stdin). */
  interactive?: boolean;
  /** Stały czas — do testów. */
  now?: number;
}

const COL = { name: 14, model: 10, status: 10, time: 7, tokens: 7, cost: 8, problems: 3 };
const PROBLEMS_SHOWN = 5;

function useLiveView(source: ViewSource, intervalMs: number): { view: ViewModel; now: number } {
  const [state, setState] = useState(() => {
    source.refresh();
    return { view: source.view(), now: Date.now() };
  });
  useEffect(() => {
    let timer: NodeJS.Timeout | undefined;
    const update = () => {
      source.refresh();
      setState({ view: source.view(), now: Date.now() });
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
        // katalog jeszcze nie istnieje (np. zespół) — zostaje odświeżanie cykliczne
      }
    }
    const interval = setInterval(update, intervalMs);
    return () => {
      clearInterval(interval);
      clearTimeout(timer);
      for (const w of watchers) w.close();
    };
  }, [source, intervalMs]);
  return state;
}

function AgentsPanel({ view, now, width }: { view: ViewModel; now: number; width: number }) {
  const fixed = COL.name + COL.model + COL.status + COL.time + COL.tokens + COL.cost + COL.problems + 8;
  const actionW = Math.max(10, width - fixed);
  const header =
    `${fit('AGENT', COL.name)} ${fit('MODEL', COL.model)} ${fit('STATUS', COL.status)} ${fit('CZAS', COL.time, 'right')} ` +
    `${fit('TOKENY', COL.tokens, 'right')} ${fit('KOSZT', COL.cost, 'right')} ${fit('!', COL.problems, 'right')}  AKCJA`;
  const { totals } = view;
  return (
    <Box flexDirection="column">
      <Text bold>Agenci</Text>
      <Text dimColor>{header}</Text>
      {view.rows.map((r) => (
        <Text key={r.key} wrap="truncate-end">
          <Text color={inkColor(r.color)} bold={r.kind === 'lead'} dimColor={r.kind === 'subagent'}>
            {fit(r.name, COL.name)}
          </Text>{' '}
          <Text dimColor>{fit(r.model ?? '—', COL.model)}</Text>{' '}
          <Text color={STATUS_COLOR[r.status]}>{fit(r.status, COL.status)}</Text>{' '}
          {fit(r.since === undefined ? '' : fmtDuration(now - r.since), COL.time, 'right')}{' '}
          {fit(fmtTokens(r.tokens), COL.tokens, 'right')} {fit(`≈${fmtCost(r.cost)}`, COL.cost, 'right')}{' '}
          <Text color={r.problems > 0 ? 'red' : undefined}>{fit(r.problems > 0 ? String(r.problems) : '', COL.problems, 'right')}</Text>
          {'  '}
          {fit(r.action, actionW)}
        </Text>
      ))}
      <Text wrap="truncate-end">
        <Text bold>{fit('RAZEM', COL.name + COL.model + COL.status + COL.time + 3)}</Text>{' '}
        {fit(fmtTokens(totals.tokens), COL.tokens, 'right')} {fit(`≈${fmtCost(totals.cost)}`, COL.cost, 'right')}
        {totals.exactCost === undefined ? '' : `    wg Claude Code: ${fmtCost(totals.exactCost)}`}
      </Text>
    </Box>
  );
}

function TimelinePanel({ view, height, offset }: { view: ViewModel; height: number; offset: number }) {
  const total = view.timeline.length;
  const end = total - offset;
  const lines = view.timeline.slice(Math.max(0, end - height), end);
  const where = offset === 0 ? 'na żywo' : `${offset} wstecz`;
  return (
    <Box flexDirection="column" height={height + 1}>
      <Text>
        <Text bold>Oś czasu</Text>
        <Text dimColor> ({total}, {where})</Text>
      </Text>
      {lines.map((e, i) => (
        <Text key={`${e.ts}-${i}`} wrap="truncate-end" dimColor={e.kind === 'turn-end'}>
          <Text dimColor>{fmtClock(e.ts)}</Text> <Text color={inkColor(e.color)}>{fit(e.agent, COL.name)}</Text>{' '}
          <Text color={e.kind === 'error' ? 'red' : e.kind === 'prompt' ? 'cyan' : undefined}>
            {e.problem === 'hook' ? '⊘' : EVENT_MARK[e.kind]} {e.text}
          </Text>
        </Text>
      ))}
    </Box>
  );
}

function ProblemsPanel({ view }: { view: ViewModel }) {
  const shown = view.problems.slice(-PROBLEMS_SHOWN);
  return (
    <Box flexDirection="column">
      <Text>
        <Text bold>Blokady i błędy</Text>
        <Text dimColor>{view.problems.length === 0 ? ' — brak' : ` (${view.problems.length})`}</Text>
      </Text>
      {shown.map((p, i) => (
        <Text key={`${p.ts}-${i}`} wrap="truncate-end">
          <Text dimColor>{fmtClock(p.ts)}</Text> <Text color={inkColor(p.color)}>{fit(p.agent, COL.name)}</Text>{' '}
          <Text color="red">
            {PROBLEM_LABEL[p.kind]}
            {p.hook ? ` ${p.hook}` : ''}
          </Text>{' '}
          {p.tool}: {p.text}
        </Text>
      ))}
    </Box>
  );
}

export function App({ source, title, intervalMs = 1000, interactive = true, now: fixedNow }: AppProps) {
  const { exit } = useApp();
  const { columns, rows } = useWindowSize();
  const live = useLiveView(source, intervalMs);
  const { view } = live;
  const now = fixedNow ?? live.now;
  const [offset, setOffset] = useState(0);
  // Przewinięta oś trzyma oglądany fragment: nowe zdarzenia zwiększają odległość od końca.
  const seen = useRef(view.timeline.length);
  useEffect(() => {
    const added = view.timeline.length - seen.current;
    seen.current = view.timeline.length;
    if (added > 0) setOffset((o) => (o > 0 ? o + added : 0));
  }, [view.timeline.length]);

  const problemsH = 1 + Math.min(view.problems.length, PROBLEMS_SHOWN);
  const agentsH = 3 + view.rows.length;
  const timelineH = Math.max(3, rows - agentsH - problemsH - 5);
  const maxOffset = Math.max(0, view.timeline.length - timelineH);
  const clamp = (n: number) => Math.min(maxOffset, Math.max(0, n));

  useInput(
    (input, key) => {
      if (input === 'q' || key.escape) exit();
      else if (key.upArrow || input === 'k') setOffset((o) => clamp(o + 1));
      else if (key.downArrow || input === 'j') setOffset((o) => clamp(o - 1));
      else if (key.pageUp) setOffset((o) => clamp(o + timelineH));
      else if (key.pageDown) setOffset((o) => clamp(o - timelineH));
      else if (key.home || input === 'g') setOffset(maxOffset);
      else if (key.end || input === 'G') setOffset(0);
    },
    { isActive: interactive },
  );

  return (
    <Box flexDirection="column" width={columns}>
      <Text wrap="truncate-end">
        <Text bold color="magenta">
          regent-watch
        </Text>{' '}
        <Text dimColor>{title}</Text>
      </Text>
      <Box marginTop={1}>
        <AgentsPanel view={view} now={now} width={columns} />
      </Box>
      <Box marginTop={1}>
        <TimelinePanel view={view} height={timelineH} offset={clamp(offset)} />
      </Box>
      <ProblemsPanel view={view} />
      <Text dimColor wrap="truncate-end">
        ↑↓ j/k przewijanie · PgUp/PgDn strona · g/G początek/koniec · q wyjście · tylko odczyt, koszt ≈ szacunek z cennika
      </Text>
    </Box>
  );
}
