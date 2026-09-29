// tasks.md — parser linii tasków (semantyka TASK_AWK z scripts/sdd-check.sh) i rozbiór linii na refs.

import { createHash } from 'node:crypto';

/** Stan linii jak w TASK_AWK: TODO `[ ]`, DONE `[x]`, BADBOX inny znak albo `[]`, NOBOX `- T-NN` bez pola. */
export type Box = 'TODO' | 'DONE' | 'BADBOX' | 'NOBOX';

export interface TaskLine {
  /** Numer linii od 1. */
  line: number;
  box: Box;
  /** Ostatni nagłówek `## ` nad linią. */
  group: string;
  /** Pierwsze `T-NN` w linii — jak `match(line, /T-[0-9]+/)` w awk; '' gdy brak. */
  id: string;
  /** Linia bez wcięcia i końcowych spacji, tabulatory jako spacje. */
  text: string;
}

const trim = (s: string): string => s.replace(/^[ \t]+/, '').replace(/[ \t\r]+$/, '');

/**
 * Port TASK_AWK: pomija bloki kodu (``` i ~~~ przełączają się nawzajem), grupy z `## `.
 * Awk działa w LC_ALL=C, więc `\[.\]` to jeden bajt — znak spoza ASCII (`[✓]`) nie jest checkboxem.
 */
export function parseTaskLines(text: string): TaskLine[] {
  const out: TaskLine[] = [];
  let fence = false;
  let group = '';
  text.split('\n').forEach((raw, i) => {
    const line = raw.replace(/\r$/, '');
    if (/^[ \t]*(```|~~~)/.test(line)) {
      fence = !fence;
      return;
    }
    if (fence) return;
    if (line.startsWith('## ')) {
      group = trim(line.slice(3));
      return;
    }
    const id = /T-[0-9]+/.exec(line)?.[0] ?? '';
    const rec = (box: Box) => out.push({ line: i + 1, box, group, id, text: trim(line).replace(/\t/g, ' ') });
    if (/^[ \t]*- \[\]/.test(line)) return rec('BADBOX');
    const box = /^[ \t]*- \[([\x00-\x7f])\]/.exec(line);
    if (box) return rec(box[1] === ' ' ? 'TODO' : box[1] === 'x' || box[1] === 'X' ? 'DONE' : 'BADBOX');
    if (/^[ \t]*[-*] T-[0-9]+/.test(line)) rec('NOBOX');
  });
  return out;
}

/** Liczniki jak `sdd-check.sh status`: zrobione (DONE) / wszystkie (DONE, TODO, BADBOX). */
export function countTasks(lines: TaskLine[]): { done: number; total: number } {
  const done = lines.filter((l) => l.box === 'DONE').length;
  return { done, total: done + lines.filter((l) => l.box === 'TODO' || l.box === 'BADBOX').length };
}

export interface ReqRef {
  req: string;
  /** null — cały REQ. */
  ac: string[] | null;
}

export interface TaskRefs {
  group: string;
  line: number;
  box: Box;
  reqs: ReqRef[];
  inv: string[];
  files: string | null;
  verify: string | null;
  /** Zależności z `(po T-XX, T-YY)`. */
  after: string[];
  /** Sekcje designu dołożone przez `— design: <sekcja>`. */
  design: string[];
  commit: string | null;
  tests: string | null;
}

export interface ParsedTask {
  /** `T-NN`, a w starszym formacie (albo przy powtórzonym ID) `#<n>` wg kolejności tasków. */
  key: string;
  tag: string | null;
  title: string;
  done: boolean;
  /** Sygnatura linii — inna niż zapisana w bazie znaczy, że linię zmieniono w pliku. */
  sig: string;
  text: string;
  refs: TaskRefs;
}

const SEP = ' — ';
const TRACE = ' ✅ (';
const REQ_REF = /REQ-[0-9]+(\/AC-[0-9]+(([ \t]*,[ \t]*(AC-)?[0-9]+)|(\.\.(AC-)?[0-9]+))*)?/g;

export const lineSig = (text: string): string => createHash('sha1').update(text).digest('hex').slice(0, 12);

/** REQ/AC jak w regułach `sdd-check.sh change`: lista `AC-1, AC-3`, zakres `AC-1..3`, sam REQ — całość. */
export function parseReqRefs(text: string): ReqRef[] {
  const byReq = new Map<string, Set<string> | null>();
  for (const [m] of text.matchAll(REQ_REF)) {
    const [req, list] = m.split('/') as [string, string | undefined];
    if (list === undefined) {
      byReq.set(req, null);
      continue;
    }
    if (byReq.get(req) === null) continue;
    const acs = byReq.get(req) ?? new Set<string>();
    for (const part of list.replace(/AC-/g, '').replace(/[ \t]/g, '').split(',')) {
      const [from, to] = part.split('..').map(Number) as [number, number | undefined];
      for (let n = from; n <= (to ?? from); n++) acs.add(`AC-${n}`);
    }
    byReq.set(req, acs);
  }
  return [...byReq].map(([req, acs]) => ({ req, ac: acs && [...acs] }));
}

function parseLine(l: TaskLine, key: string): ParsedTask {
  const traceAt = l.text.indexOf(TRACE);
  const body = traceAt < 0 ? l.text : l.text.slice(0, traceAt);
  const trace = traceAt < 0 ? '' : l.text.slice(traceAt + TRACE.length).replace(/\)\s*$/, '');
  const [head = '', ...segments] = body.split(SEP);

  let title = head.replace(/^[-*] (\[[^\]]?\] )?/, '');
  if (l.id && title.startsWith(l.id)) title = title.slice(l.id.length).replace(/^:?[ \t]*/, '');
  const tag = /^\[(BE|FE|DB)\][ \t]*/.exec(title);
  if (tag) title = title.slice(tag[0].length);

  const after = [...body.matchAll(/\(po ([^)]*)\)/g)].flatMap(([, list]) => list!.match(/T-[0-9]+/g) ?? []);
  const field = (name: string): string | null => {
    const seg = segments.find((s) => s.toLowerCase().startsWith(`${name}:`));
    return seg ? seg.slice(name.length + 1).replace(/\(po [^)]*\)/g, '').trim() || null : null;
  };
  const traceField = (name: string): string | null =>
    trace
      .split(' · ')
      .find((p) => p.startsWith(`${name}:`))
      ?.slice(name.length + 1)
      .trim() || null;

  return {
    key,
    tag: tag ? tag[1]! : null,
    title: title.trim() || key,
    done: l.box === 'DONE',
    sig: lineSig(l.text),
    text: l.text,
    refs: {
      group: l.group,
      line: l.line,
      box: l.box,
      reqs: parseReqRefs(body),
      inv: [...new Set(body.match(/INV-[0-9]+/g) ?? [])],
      files: field('pliki'),
      verify: field('weryfikacja'),
      after: [...new Set(after)],
      design: (field('design') ?? '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
      commit: traceField('commit'),
      tests: traceField('testy'),
    },
  };
}

/** Taski pliku (bez NOBOX — `sdd-check.sh status` ich nie liczy) z kluczem i rozebraną linią. */
export function parseTasks(text: string): ParsedTask[] {
  const seen = new Set<string>();
  return parseTaskLines(text)
    .filter((l) => l.box !== 'NOBOX')
    .map((l, i) => {
      const key = l.id && !seen.has(l.id) ? l.id : `#${i + 1}`;
      seen.add(key);
      return parseLine(l, key);
    });
}

/** Warstwa taska do `next --layer`: brak tagu = `[BE]` (konwencja `propose` 2d). */
export const layerOf = (tag: string | null): string => tag ?? 'BE';
