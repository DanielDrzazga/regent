// Zakładki prawego panelu jako czyste funkcje: dane → Line[].

import { PROBLEM_LABEL_TEXT } from './labels.js';
import type { AgentRow, ViewModel } from '../view.js';
import { fmtCost, fmtDuration, fmtTokens } from '../units.js';
import { type Line, kv, section, seg } from './lines.js';
import {
  HEALTH_COLOR,
  HEALTH_MARK,
  STATUS_COLOR,
  bar,
  contextColor,
  contextPct,
  inkColor,
  meter,
  statusDot,
} from './style.js';

export type Tab = 'tabela' | 'oś' | 'graf' | 'przegląd' | 'zdrowie';
export const TABS: Array<{ id: Tab; label: string }> = [
  { id: 'tabela', label: 'Tabela' },
  { id: 'oś', label: 'Oś czasu' },
  { id: 'graf', label: 'Graf' },
  { id: 'przegląd', label: 'Przegląd' },
  { id: 'zdrowie', label: 'Zdrowie' },
];

export function fmtClock(ts: number): string {
  const d = new Date(ts);
  const two = (n: number) => String(n).padStart(2, '0');
  return `${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
}

const col = (text: string, w: number, align: 'l' | 'r' = 'l'): string => {
  const chars = [...text];
  const s = chars.length > w ? `${chars.slice(0, w - 1).join('')}…` : text;
  return align === 'l' ? s.padEnd(w) : s.padStart(w);
};

export const EVENT_MARK = { prompt: '>', tool: '·', message: '@', spawn: '+', error: '✗', retry: '↻', 'turn-end': '─' } as const;

export function tabsLine(active: Tab): Line {
  return TABS.flatMap((t, i) => [
    t.id === active ? seg(`[ ${t.label} ]`, { bold: true, color: 'cyan' }) : seg(`  ${t.label}  `, { dim: true }),
    seg(i < TABS.length - 1 ? ' ' : ''),
  ]);
}

// ── Tabela ──────────────────────────────────────────────────────────────────────────────────
const TW = { name: 16, model: 10, ctx: 11, status: 11, time: 7, tokens: 7, cost: 8, problems: 3 };
/** Minimalna szerokość kolumny AKCJA; gdy brakuje miejsca, znikają MODEL, potem TOKENY. */
const ACTION_MIN = 24;

export function tableLines(view: ViewModel, now: number, width: number, frame: number): Line[] {
  const base = TW.name + TW.ctx + TW.status + TW.time + TW.cost + TW.problems + 7;
  const showModel = width - base - TW.model - TW.tokens - 2 >= ACTION_MIN;
  const showTokens = width - base - (showModel ? TW.model + 1 : 0) - TW.tokens - 1 >= ACTION_MIN;
  // Za wąsko nawet bez opcjonalnych kolumn — akcja w osobnej linii pod agentem.
  const actionBelow = width - base < ACTION_MIN;
  const head =
    `${col('AGENT', TW.name)} ${showModel ? `${col('MODEL', TW.model)} ` : ''}${col('KONTEKST', TW.ctx)} ${col('STATUS', TW.status)} ` +
    `${col('CZAS', TW.time, 'r')} ${showTokens ? `${col('TOKENY', TW.tokens, 'r')} ` : ''}${col('KOSZT', TW.cost, 'r')} ${col('!', TW.problems, 'r')}${actionBelow ? '' : '  AKCJA'}`;
  const lines: Line[] = [[seg(head, { dim: true })], [seg('─'.repeat(Math.max(0, width)), { dim: true })]];
  for (const r of view.rows) {
    const pct = contextPct(r);
    const ctxColor = contextColor(r);
    const nameColor = inkColor(r.color);
    const action = seg(r.action || (r.health.level !== 'ok' ? (r.health.issues[0]?.text ?? '') : ''), {
      ...(r.action ? {} : { color: HEALTH_COLOR[r.health.level] ?? 'gray', dim: r.health.level === 'ok' }),
    });
    lines.push([
      seg(col(r.kind === 'subagent' ? `  ${r.name.split('›').pop()}` : r.name, TW.name), {
        ...(nameColor ? { color: nameColor } : {}),
        ...(r.kind === 'lead' ? { bold: true } : {}),
        ...(r.kind === 'subagent' ? { dim: true } : {}),
      }),
      seg(' '),
      ...(showModel ? [seg(col(r.model ?? '—', TW.model), { dim: true }), seg(' ')] : []),
      seg(pct === undefined ? '    ' : `${String(pct).padStart(3)}%`, ctxColor ? { color: ctxColor } : {}),
      seg(' '),
      ...meter(r),
      seg(' '),
      statusDot(r.status, frame),
      seg(` ${col(r.status, TW.status - 2)}`, { color: STATUS_COLOR[r.status], ...(r.status === 'zamknięty' ? { dim: true } : {}) }),
      seg(' '),
      seg(col(r.since === undefined ? '' : fmtDuration(now - r.since), TW.time, 'r')),
      seg(' '),
      ...(showTokens ? [seg(col(fmtTokens(r.tokens), TW.tokens, 'r')), seg(' ')] : []),
      seg(col(`≈${fmtCost(r.cost)}`, TW.cost, 'r')),
      seg(' '),
      seg(col(r.problems > 0 ? String(r.problems) : '', TW.problems, 'r'), r.problems > 0 ? { color: 'red' } : {}),
      ...(actionBelow ? [] : [seg('  '), action]),
    ]);
    if (actionBelow && action.text) lines.push([seg('   └ ', { dim: true }), action]);
  }
  lines.push([seg('─'.repeat(Math.max(0, width)), { dim: true })]);
  const t = view.totals;
  const offset = TW.name + (showModel ? TW.model + 1 : 0) + TW.ctx + TW.status + TW.time + 3;
  lines.push([
    seg(col('RAZEM', offset), { bold: true }),
    seg(' '),
    ...(showTokens ? [seg(col(fmtTokens(t.tokens), TW.tokens, 'r')), seg(' ')] : [seg(`${fmtTokens(t.tokens)} tok. `, { dim: true })]),
    seg(col(`≈${fmtCost(t.cost)}`, TW.cost, 'r')),
    ...(t.exactCost === undefined ? [] : [seg(`    wg Claude Code: ${fmtCost(t.exactCost)}`, { color: 'green' })]),
  ]);
  return lines;
}

// ── Oś czasu ────────────────────────────────────────────────────────────────────────────────
export function timelineLines(view: ViewModel, agentKey?: string): Line[] {
  const events = agentKey ? view.timeline.filter((e) => e.agentKey === agentKey) : view.timeline;
  if (events.length === 0) return [[seg('brak zdarzeń', { dim: true })]];
  return events.map((e) => {
    const color = inkColor(e.color);
    const mark = e.problem === 'hook' ? '⊘' : EVENT_MARK[e.kind];
    const textStyle =
      e.kind === 'error' ? { color: 'red' } : e.kind === 'prompt' ? { color: 'cyan' } : e.kind === 'turn-end' ? { dim: true } : e.kind === 'spawn' ? { color: 'green' } : {};
    return [
      seg(fmtClock(e.ts), { dim: true }),
      seg(' '),
      ...(agentKey ? [] : [seg(col(e.agent, 14), color ? { color } : {}), seg(' ')]),
      seg(`${mark} ${e.text}`, textStyle),
    ];
  });
}

// ── Przegląd ────────────────────────────────────────────────────────────────────────────────
export interface SessionMeta {
  id: string;
  path: string;
  transcript: string;
}

export function overviewLines(view: ViewModel, meta: SessionMeta, now: number, width: number): Line[] {
  const o = view.overview;
  const closed = view.rows.every((r) => r.status === 'zamknięty' || r.status === 'zakończony');
  const lines: Line[] = [section('SESJA', width)];
  lines.push(kv('id', meta.id));
  lines.push(kv('projekt', meta.path));
  if (o.start !== undefined) {
    lines.push(kv('start', `${fmtClock(o.start)} · ${closed ? 'trwała' : 'trwa'} ${fmtDuration((closed ? (o.end ?? now) : now) - o.start)}`));
  }
  lines.push(kv('stan', [seg(closed ? 'zamknięta' : 'aktywna', { color: closed ? 'gray' : 'green' })]));
  lines.push([]);
  lines.push(section('AGENCI', width, String(view.rows.length)));
  const sc = o.statusCounts;
  lines.push([
    seg(`pracuje ${sc.pracuje}`, { color: 'green' }),
    seg(' · '),
    seg(`myśli ${sc.myśli}`, { color: 'cyan' }),
    seg(` · czeka ${sc.czeka} · zakończony ${sc.zakończony} · zamknięty ${sc.zamknięty}`, { dim: true }),
  ]);
  lines.push([]);
  lines.push(section('TOKENY', width, fmtTokens(view.totals.tokens)));
  const u = o.usage;
  lines.push(kv('wejście', fmtTokens(u.input)));
  lines.push(kv('zapis cache', fmtTokens(u.cacheWrite5m + u.cacheWrite1h)));
  lines.push(kv('odczyt cache', fmtTokens(u.cacheRead)));
  lines.push(kv('wyjście', fmtTokens(u.output)));
  lines.push([]);
  lines.push(section('KOSZT', width, `≈${fmtCost(view.totals.cost)}`));
  for (const m of o.byModel) lines.push(kv(m.model, `${fmtTokens(m.tokens).padStart(7)}  ≈${fmtCost(m.cost)}`, 14));
  lines.push(
    view.totals.exactCost === undefined
      ? [seg('koszt wg Claude Code pojawi się po zamknięciu wszystkich sesji; ≈ to dolna granica', { dim: true })]
      : kv('wg Claude Code', [seg(fmtCost(view.totals.exactCost), { color: 'green' })], 16),
  );
  lines.push([]);
  lines.push(section('NARZĘDZIA', width, String(o.tools.reduce((n, t) => n + t.calls, 0))));
  for (const t of o.tools.slice(0, 10)) {
    lines.push([seg(col(t.name, 16)), seg(String(t.calls).padStart(5)), ...(t.errors ? [seg(`   błędy ${t.errors}`, { color: 'red' })] : [])]);
  }
  lines.push([]);
  lines.push(section('KOMUNIKACJA', width));
  lines.push([seg(`wiadomości ${o.messages} · spawny ${o.spawns}`)]);
  lines.push([]);
  lines.push(section('PROBLEMY', width, String(view.problems.length)));
  const p = o.problemsByKind;
  lines.push([
    seg(`${PROBLEM_LABEL_TEXT.hook} ${p.hook}`, p.hook ? { color: 'yellow' } : { dim: true }),
    seg(' · '),
    seg(`${PROBLEM_LABEL_TEXT.permission} ${p.permission}`, p.permission ? { color: 'yellow' } : { dim: true }),
    seg(' · '),
    seg(`${PROBLEM_LABEL_TEXT.tool} ${p.tool}`, p.tool ? { color: 'red' } : { dim: true }),
    seg(' · '),
    seg(`${PROBLEM_LABEL_TEXT.api} ${p.api}`, p.api ? { color: 'red' } : { dim: true }),
  ]);
  lines.push([]);
  lines.push(kv('transkrypt', [seg(meta.transcript, { dim: true })]));
  return lines;
}

// ── Zdrowie ─────────────────────────────────────────────────────────────────────────────────
export function healthLines(view: ViewModel, width: number): Line[] {
  const lines: Line[] = [section('ZDROWIE AGENTÓW', width)];
  for (const r of view.rows) {
    const color = HEALTH_COLOR[r.health.level];
    const closed = r.status === 'zamknięty' || r.status === 'zakończony';
    lines.push([
      seg(`${HEALTH_MARK[r.health.level]} `, color ? { color } : { color: 'green', dim: closed }),
      seg(col(r.name, 16), closed ? { dim: true } : {}),
      seg(col(closed ? r.status : r.health.level, 9), color ? { color } : { dim: true }),
      seg(r.health.issues.map((i) => i.text).join(' · '), color ? { color } : {}),
    ]);
  }
  lines.push([]);
  lines.push([seg('Progi: kontekst 150k (obserwuj) i 250k albo 90% okna (czas na /clear) — jak statusline;', { dim: true })]);
  lines.push([seg('blokady hooka, odmowy, błędy i ponowienia API z ostatnich 30 min; narzędzie albo tura bez', { dim: true })]);
  lines.push([seg('nowych rekordów ponad 10 min. Agenci zamknięci i zakończeni nie są oceniani.', { dim: true })]);
  return lines;
}

// ── Szczegóły agenta ────────────────────────────────────────────────────────────────────────
export interface DetailInput {
  row: AgentRow;
  view: ViewModel;
  transcript: string;
  now: number;
  width: number;
  frame: number;
  inTmux: boolean;
}

export function detailLines({ row: r, view, transcript, now, width, frame, inTmux }: DetailInput): Line[] {
  const pct = contextPct(r);
  const lines: Line[] = [section('KONTEKST', width, pct === undefined ? '—' : `${pct}%`)];
  lines.push(kv('pasek', [...bar(r, Math.max(10, Math.min(40, width - 30))), seg(`  ${pct ?? 0}%`)]));
  lines.push(
    kv('rozmiar', r.context === undefined ? '—' : `${fmtTokens(r.context)} z ${r.contextWindow ? fmtTokens(r.contextWindow) : '?'} (okno wg modelu — szacunek)`),
  );
  const u = r.usage;
  lines.push(kv('tokeny', `wejście ${fmtTokens(u.input)} · zapis cache ${fmtTokens(u.cacheWrite5m + u.cacheWrite1h)} · odczyt cache ${fmtTokens(u.cacheRead)} · wyjście ${fmtTokens(u.output)}`));
  lines.push(kv('koszt', [seg(`≈${fmtCost(r.cost)}`), ...(r.exactCost === undefined ? [] : [seg(`  wg Claude Code: ${fmtCost(r.exactCost)}`, { color: 'green' })])]));
  lines.push(kv('model', r.model ?? '—'));
  lines.push([]);
  lines.push(section('BIEŻĄCA AKCJA', width));
  lines.push(kv('status', [statusDot(r.status, frame), seg(` ${r.status}`, { color: STATUS_COLOR[r.status] }), seg(r.since === undefined ? '' : ` · ${fmtDuration(now - r.since)}`, { dim: true })]));
  lines.push(kv('akcja', r.action || '—'));
  lines.push(kv('ostatnio', r.lastTs === undefined ? '—' : `${fmtClock(r.lastTs)} (${fmtDuration(now - r.lastTs)} temu)`));
  lines.push([]);
  lines.push(section('TMUX', width));
  if (r.kind === 'teammate' && r.paneId) {
    lines.push(kv('panel', [seg(r.paneId), seg(inTmux ? '   t — przejdź do panelu' : '   (widok poza tmux — skok niedostępny)', { dim: true })]));
  } else if (r.kind === 'lead') {
    lines.push(kv('panel', [seg('panel leada', {}), seg(inTmux ? '   t — przejdź (w oknie członków zespołu)' : '   (widok poza tmux)', { dim: true })]));
  } else {
    lines.push(kv('panel', [seg(r.kind === 'subagent' ? 'subagent działa w procesie rodzica' : 'brak panelu', { dim: true })]));
  }
  lines.push([]);
  lines.push(section('ZDROWIE', width, r.health.level));
  if (r.health.issues.length === 0) lines.push([seg('● ok', { color: 'green' })]);
  for (const i of r.health.issues) lines.push([seg(`${HEALTH_MARK[i.level]} ${i.text}`, { color: HEALTH_COLOR[i.level] ?? 'yellow' })]);
  lines.push([]);
  const events = timelineLines(view, r.key).slice(-12);
  lines.push(section('OSTATNIE ZDARZENIA', width, String(view.timeline.filter((e) => e.agentKey === r.key).length)));
  lines.push(...events);
  const problems = view.problems.filter((p) => p.agentKey === r.key);
  lines.push([]);
  lines.push(section('BLOKADY I BŁĘDY', width, String(problems.length)));
  if (problems.length === 0) lines.push([seg('brak', { dim: true })]);
  for (const p of problems.slice(-8)) {
    lines.push([
      seg(fmtClock(p.ts), { dim: true }),
      seg(' '),
      seg(`${PROBLEM_LABEL_TEXT[p.kind]}${p.hook ? ` ${p.hook}` : ''}`, { color: p.kind === 'tool' || p.kind === 'api' ? 'red' : 'yellow' }),
      seg(` ${p.tool}: ${p.text}`),
    ]);
  }
  lines.push([]);
  lines.push(section('SESJA', width));
  lines.push(kv('id sesji', r.sessionId ?? '—'));
  lines.push(kv('transkrypt', [seg(transcript, { dim: true })]));
  return lines;
}

// ── Pomoc ───────────────────────────────────────────────────────────────────────────────────
export function helpLines(width: number): Line[] {
  const key = (k: string, what: string): Line => [seg(k.padEnd(18), { color: 'cyan' }), seg(what)];
  return [
    section('KLAWISZE', width),
    key('↑ ↓   k j', 'wybór w drzewie'),
    key('→ ←   l h', 'rozwiń / zwiń sesję; ← na agencie — wróć do sesji'),
    key('Enter', 'rozwiń sesję albo otwórz szczegóły agenta'),
    key('Esc', 'wróć do sesji · wyczyść filtr · zamknij pomoc'),
    key('Tab  1–5', 'zakładka sesji: Tabela, Oś czasu, Graf, Przegląd, Zdrowie'),
    key('PgUp PgDn', 'przewijanie prawego panelu'),
    key('g  G', 'początek / koniec (koniec osi czasu = na żywo)'),
    key('t', 'przełącz tmux na panel wybranego agenta'),
    key('/', 'filtr: projekt, sesja albo agent (Enter — zatwierdź, Esc — wyczyść)'),
    key('?', 'ta pomoc'),
    key('q', 'wyjście'),
    [],
    section('SYMBOLE', width),
    [seg('⠧ ', { color: 'green' }), seg('pracuje (narzędzie w toku)   '), seg('⠧ ', { color: 'cyan' }), seg('myśli   '), seg('● ', { color: 'gray' }), seg('czeka   '), seg('○ ', { dim: true }), seg('zakończony / zamknięty')],
    [seg('▲ ', { color: 'yellow' }), seg('uwaga   '), seg('✗ ', { color: 'red' }), seg('problem   '), seg('⊘ ', { color: 'yellow' }), seg('blokada hooka   '), seg('@ ', {}), seg('wiadomość   '), seg('+ ', { color: 'green' }), seg('nowy członek zespołu')],
    [],
    [seg('Widok tylko czyta transkrypty z ~/.claude/projects i stan zespołów z ~/.claude/teams.', { dim: true })],
    [seg('Koszt ≈ to szacunek z cennika API (dolna granica); dokładny pojawia się po zamknięciu sesji.', { dim: true })],
  ];
}

