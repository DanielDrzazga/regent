// Linie ekranu jako dane: segmenty tekstu ze stylem. Panele budują Line[] czystymi funkcjami,
// komponent <Lines> tylko je rysuje — dzięki temu każdy widok da się przetestować jako tekst.

export interface Seg {
  text: string;
  color?: string;
  bold?: boolean;
  dim?: boolean;
  inverse?: boolean;
}

export type Line = Seg[];

export const seg = (text: string, style: Omit<Seg, 'text'> = {}): Seg => ({ text, ...style });

export const plain = (line: Line): string => line.map((s) => s.text).join('');

export const lineWidth = (line: Line): number => [...plain(line)].length;

/** Linia przycięta do szerokości w (z „…"); dłuższe segmenty skracane od końca. */
export function fitLine(line: Line, w: number): Line {
  const out: Line = [];
  let left = w;
  for (const s of line) {
    if (left <= 0) break;
    const chars = [...s.text];
    if (chars.length <= left) {
      out.push(s);
      left -= chars.length;
    } else {
      out.push({ ...s, text: left > 1 ? `${chars.slice(0, left - 1).join('')}…` : '…' });
      left = 0;
    }
  }
  return out;
}

/** Linia dopełniona spacjami do szerokości w (po przycięciu). */
export function padLine(line: Line, w: number, style: Omit<Seg, 'text'> = {}): Line {
  const fitted = fitLine(line, w);
  const rest = w - lineWidth(fitted);
  return rest > 0 ? [...fitted, seg(' '.repeat(rest), style)] : fitted;
}

/** Nagłówek sekcji w stylu OpenRig: „── TYTUŁ · dopisek ────". */
export function section(title: string, width: number, extra?: string): Line {
  const head = `── ${title}${extra ? ` · ${extra}` : ''} `;
  return [seg('── ', { dim: true }), seg(title, { bold: true }), seg(extra ? ` · ${extra} ` : ' ', { dim: false }), seg('─'.repeat(Math.max(0, width - [...head].length)), { dim: true })];
}

/** Para „etykieta: wartość" z wyrównaną etykietą. */
export const kv = (label: string, value: Line | string, labelW = 14): Line => [
  seg(`${label}:`.padEnd(labelW), { dim: true }),
  ...(typeof value === 'string' ? [seg(value)] : value),
];

/** Widoczny fragment linii: offset od góry albo od dołu (oś czasu — najnowsze na dole). */
export function viewport(lines: Line[], height: number, offset: number, anchor: 'top' | 'bottom'): Line[] {
  if (height <= 0) return [];
  const max = Math.max(0, lines.length - height);
  const o = Math.min(max, Math.max(0, offset));
  const start = anchor === 'top' ? o : Math.max(0, lines.length - height - o);
  return lines.slice(start, start + height);
}

export const maxOffset = (lines: number, height: number): number => Math.max(0, lines - height);
