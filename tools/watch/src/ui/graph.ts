// Graf sesji jak GRAPH w OpenRig, ograniczony do drzewa: lead → członkowie zespołu → subagenci.
// Pudełka w kolumnach wg głębokości, krawędzie z liczbą wiadomości (✉ w dół ↓ / w górę ↑).
// Rysowane na siatce znaków — czysta funkcja, wynik to Line[].

import type { AgentRow, ViewModel } from '../view.js';
import { type Line, type Seg, seg } from './lines.js';
import { HEALTH_COLOR, HEALTH_MARK, STATUS_COLOR, contextPct, inkColor, statusDot } from './style.js';

const BW = 22; // szerokość pudełka
const BH = 4; // wysokość pudełka
const GAP = 12; // odstęp między kolumnami (krawędź + etykieta)
const VGAP = 1;

type Style = Omit<Seg, 'text'>;
interface Cell {
  ch: string;
  style: Style;
}

class Canvas {
  readonly cells: Cell[][];
  constructor(
    readonly w: number,
    readonly h: number,
  ) {
    this.cells = Array.from({ length: h }, () => Array.from({ length: w }, () => ({ ch: ' ', style: {} })));
  }
  put(x: number, y: number, ch: string, style: Style = {}): void {
    const row = this.cells[y];
    if (row && x >= 0 && x < this.w) row[x] = { ch, style };
  }
  text(x: number, y: number, text: string, style: Style = {}): void {
    [...text].forEach((ch, i) => this.put(x + i, y, ch, style));
  }
  lines(): Line[] {
    return this.cells.map((row) => {
      const out: Line = [];
      let lastKey = '';
      for (const c of row) {
        const key = JSON.stringify(c.style);
        const last = out[out.length - 1];
        if (last && key === lastKey) last.text += c.ch;
        else out.push({ text: c.ch, ...c.style });
        lastKey = key;
      }
      // bez końcowych spacji
      while (out.length && out[out.length - 1]?.text.trim() === '') out.pop();
      return out;
    });
  }
}

const styleOf = (s: Seg): Style => {
  const { text: _t, ...style } = s;
  return style;
};

const clip = (s: string, n: number): string => {
  const chars = [...s];
  return chars.length > n ? `${chars.slice(0, n - 1).join('')}…` : s;
};

function borderColor(r: AgentRow): Style {
  const h = HEALTH_COLOR[r.health.level];
  if (h) return { color: h };
  if (r.status === 'pracuje' || r.status === 'myśli') return { color: STATUS_COLOR[r.status] };
  return { dim: true };
}

function drawBox(c: Canvas, x: number, y: number, r: AgentRow, frame: number): void {
  const b = borderColor(r);
  c.text(x, y, `╭${'─'.repeat(BW - 2)}╮`, b);
  c.text(x, y + BH - 1, `╰${'─'.repeat(BW - 2)}╯`, b);
  for (let i = 1; i < BH - 1; i++) {
    c.put(x, y + i, '│', b);
    c.put(x + BW - 1, y + i, '│', b);
  }
  const dot = statusDot(r.status, frame);
  c.put(x + 2, y + 1, dot.text, styleOf(dot));
  const nameColor = inkColor(r.color);
  const name = r.kind === 'subagent' ? (r.name.split('›').pop() ?? r.name) : r.name;
  c.text(x + 4, y + 1, clip(name, BW - 7), {
    ...(nameColor ? { color: nameColor } : {}),
    ...(r.kind === 'lead' ? { bold: true } : {}),
    ...(r.status === 'zamknięty' ? { dim: true } : {}),
  });
  if (r.health.level !== 'ok') c.put(x + BW - 3, y + 1, HEALTH_MARK[r.health.level], { color: HEALTH_COLOR[r.health.level] });
  c.text(x + 2, y + 2, clip(r.model ?? '—', BW - 9), { dim: true });
  const pct = contextPct(r);
  if (pct !== undefined) c.text(x + BW - 6, y + 2, `${String(pct).padStart(3)}%`);
}

export function graphLines(view: ViewModel, frame: number): Line[] {
  const byKey = new Map(view.rows.map((r) => [r.key, r]));
  const children = new Map<string, string[]>();
  const hasParent = new Set<string>();
  for (const e of view.edges) {
    if (!byKey.has(e.from) || !byKey.has(e.to)) continue;
    children.set(e.from, [...(children.get(e.from) ?? []), e.to]);
    hasParent.add(e.to);
  }
  const roots = view.rows.filter((r) => !hasParent.has(r.key));
  const pos = new Map<string, { x: number; y: number; depth: number; slot: number }>();
  let next = 0;
  let maxDepth = 0;
  const place = (key: string, depth: number): number => {
    maxDepth = Math.max(maxDepth, depth);
    const kids = children.get(key) ?? [];
    let slot: number;
    if (kids.length === 0) slot = next++;
    else slot = kids.map((k) => place(k, depth + 1))[0] ?? next++;
    pos.set(key, { x: depth * (BW + GAP), y: slot * (BH + VGAP), depth, slot });
    return slot;
  };
  for (const r of roots) place(r.key, 0);

  const canvas = new Canvas((maxDepth + 1) * (BW + GAP) - GAP, Math.max(1, next * (BH + VGAP)));
  const edgeStyle: Style = { dim: true };
  for (const [parent, kids] of children) {
    const p = pos.get(parent);
    if (!p) continue;
    const rowP = p.y + 1;
    const trunk = p.x + BW + 2;
    canvas.text(p.x + BW, rowP, '──', edgeStyle);
    const rows = kids.map((k) => (pos.get(k)?.y ?? 0) + 1);
    const last = Math.max(...rows);
    for (let y = rowP; y <= last; y++) canvas.put(trunk, y, '│', edgeStyle);
    kids.forEach((k, i) => {
      const cpos = pos.get(k);
      if (!cpos) return;
      const rowC = cpos.y + 1;
      const isFirst = rowC === rowP;
      const isLast = i === kids.length - 1;
      canvas.put(trunk, rowC, isFirst ? (isLast ? '─' : '┬') : isLast ? '└' : '├', edgeStyle);
      canvas.text(trunk + 1, rowC, '─'.repeat(Math.max(0, cpos.x - trunk - 2)), edgeStyle);
      canvas.put(cpos.x - 1, rowC, '▶', edgeStyle);
      const edge = view.edges.find((e) => e.from === parent && e.to === k);
      if (edge && edge.kind === 'spawn' && edge.down + edge.up > 0) {
        canvas.text(trunk + 2, rowC + 1, `✉${edge.down}↓${edge.up}↑`, { color: 'cyan' });
      }
    });
  }
  for (const r of view.rows) {
    const p = pos.get(r.key);
    if (p) drawBox(canvas, p.x, p.y, r, frame);
  }

  const lines = canvas.lines();
  lines.push([]);
  if (view.rows.length === 1) lines.push([seg('Sesja bez członków zespołu i subagentów.', { dim: true })]);
  if (view.sideMessages.length > 0) {
    lines.push([seg('Wiadomości między członkami:', { bold: true })]);
    for (const m of view.sideMessages) lines.push([seg(`  ${m.from} → ${m.to}`), seg(`  ✉${m.count}`, { color: 'cyan' })]);
  }
  lines.push([seg('✉ n↓ m↑ — wiadomości lead → członek i członek → lead · ramka: kolor statusu, żółta/czerwona — zdrowie', { dim: true })]);
  return lines;
}
