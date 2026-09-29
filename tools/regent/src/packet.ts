// Paczka dla agenta implementującego — składana przy odczycie z aktualnych plików zmiany, zamiast
// czytania całych tasks.md, design.md i delty. Reguły (plan task-core, tabela Decyzje):
// zawsze linie tasków, wskazane bloki REQ z delty, INVARIANTS i stałe sekcje designu;
// [BE]/[FE] (brak tagu = [BE]) dokładają kontrakt API i obsługę błędów, [DB] — zmiany bazy;
// `— design: <sekcja>` w linii taska dokłada sekcję.

import { readdirSync } from 'node:fs';
import { join, relative } from 'node:path';
import { UsageError } from './model.js';
import { archiveDir, archivedChanges, changeDir, isDir, readText } from './sdd.js';
import { layerOf, parseTasks, type ParsedTask } from './tasksmd.js';

export const BASE_SECTIONS = ['Overview', 'Affected Files', 'Decyzje techniczne', 'Odstępstwa od zasad', 'Testing Strategy'];
export const LAYER_SECTIONS: Readonly<Record<string, readonly string[]>> = {
  BE: ['API / Interface Contract', 'Error Handling'],
  FE: ['API / Interface Contract', 'Error Handling'],
  DB: ['Database Changes'],
};

/** Szacunek tokenów: bajty / 3,5. */
export const tokens = (bytes: number): number => Math.round(bytes / 3.5);

export interface PacketStats {
  packetBytes: number;
  packetTokens: number;
  /** Pliki, które paczka zastępuje: tasks.md, design.md, specs/*.md. */
  files: string[];
  filesBytes: number;
  filesTokens: number;
}

export interface Packet {
  change: string;
  /** Katalog zmiany względem korzenia projektu. */
  dir: string;
  keys: string[];
  text: string;
  /** Sekcje i REQ, o które paczka prosiła, a pliki ich nie mają. */
  missing: string[];
  stats: PacketStats;
}

/** Katalog zmiany: aktywny `ai/changes/<zmiana>/`, a gdy go nie ma — archiwum (po nazwie albo katalogu). */
export function resolveChange(root: string, name: string): string {
  if (name !== 'archive' && isDir(changeDir(root, name))) return changeDir(root, name);
  const archived = archivedChanges(root).get(name);
  if (archived) return join(archiveDir(root), archived.dir);
  if (isDir(join(archiveDir(root), name))) return join(archiveDir(root), name);
  throw new UsageError(`nie ma zmiany ${name} w ai/changes/ ani w archiwum`);
}

interface Heading {
  level: number;
  title: string;
  /** Indeks linii nagłówka w `lines`. */
  at: number;
}

interface Outline {
  lines: string[];
  headings: Heading[];
}

/** Linie bez komentarzy HTML (instrukcje szablonów) i nagłówki — oba poza blokami kodu. */
function outline(text: string): Outline {
  const lines: string[] = [];
  const headings: Heading[] = [];
  let fence = false;
  let comment = false;
  for (const raw of text.split('\n')) {
    const line = raw.replace(/\r$/, '');
    if (!comment && /^[ \t]*(```|~~~)/.test(line)) {
      fence = !fence;
      lines.push(line);
      continue;
    }
    if (fence) {
      lines.push(line);
      continue;
    }
    let out = '';
    let rest = line;
    while (rest) {
      if (comment) {
        const end = rest.indexOf('-->');
        if (end < 0) break;
        rest = rest.slice(end + 3);
        comment = false;
        continue;
      }
      const start = rest.indexOf('<!--');
      if (start < 0) {
        out += rest;
        break;
      }
      out += rest.slice(0, start);
      rest = rest.slice(start + 4);
      comment = true;
    }
    if (line.trim() && !out.trim()) continue; // linia z samym komentarzem
    const heading = /^(#{1,6})[ \t]+(.*?)[ \t]*$/.exec(out);
    if (heading) headings.push({ level: heading[1]!.length, title: heading[2]!, at: lines.length });
    lines.push(out.replace(/[ \t]+$/, ''));
  }
  return { lines, headings };
}

/** Koniec sekcji: następny nagłówek tego samego albo wyższego poziomu. */
const sectionEnd = (o: Outline, h: Heading): number =>
  o.headings.find((x) => x.at > h.at && x.level <= h.level)?.at ?? o.lines.length;

/** Treść sekcji bez nagłówka, bez pustych linii i separatorów `---` na brzegach, puste linie sklejone. */
function body(o: Outline, h: Heading): string {
  const lines = o.lines.slice(h.at + 1, sectionEnd(o, h));
  const blank = (l: string | undefined) => l !== undefined && (!l.trim() || /^-{3,}$/.test(l.trim()));
  while (blank(lines[0])) lines.shift();
  while (blank(lines.at(-1))) lines.pop();
  return lines.filter((l, i) => l.trim() || lines[i - 1]?.trim()).join('\n');
}

const norm = (s: string): string => s.toLowerCase().replace(/\s+/g, ' ').trim();
const matches = (title: string, want: string): boolean => norm(title) === norm(want) || norm(title).startsWith(norm(want));

/** Sekcje designu dla tasków, w kolejności reguły, bez powtórzeń. */
export function designWanted(tasks: ParsedTask[]): string[] {
  const wanted = [...BASE_SECTIONS];
  for (const t of tasks) wanted.push(...(LAYER_SECTIONS[layerOf(t.tag)] ?? []), ...t.refs.design);
  return wanted.filter((w, i) => wanted.findIndex((x) => norm(x) === norm(w)) === i);
}

function designPart(text: string | undefined, wanted: string[], missing: string[]): string[] {
  if (text === undefined) {
    missing.push('design.md');
    return [];
  }
  const o = outline(text);
  const picked = new Map<number, Heading>();
  for (const want of wanted) {
    const h = o.headings.find((x) => x.level >= 2 && matches(x.title, want));
    if (h) picked.set(h.at, h);
    else missing.push(`design.md: ${want}`);
  }
  const parts: string[] = [];
  let coveredTo = -1;
  for (const h of [...picked.values()].sort((a, b) => a.at - b.at)) {
    if (h.at < coveredTo) continue; // sekcja wewnątrz już wziętej
    coveredTo = sectionEnd(o, h);
    parts.push(`## Design: ${h.title}`, '', body(o, h), '');
  }
  return parts;
}

interface DeltaFile {
  path: string;
  text: string;
}

function deltaPart(deltas: DeltaFile[], reqs: string[], missing: string[]): string[] {
  const parts: string[] = [];
  const found = new Set<string>();
  const invariants: string[] = [];
  for (const d of deltas) {
    const o = outline(d.text);
    const blocks: string[] = [];
    let section = '';
    for (const h of o.headings) {
      if (h.level <= 2) section = h.title;
      if (h.level === 2 && /^INVARIANTS/i.test(h.title)) {
        const inv = body(o, h);
        if (inv) invariants.push(`## INVARIANTS (${d.path})`, '', inv, '');
      }
      const req = h.level === 3 ? /^REQ-[0-9]+/.exec(h.title)?.[0] : undefined;
      if (!req || !reqs.includes(req) || found.has(req)) continue;
      found.add(req);
      blocks.push(`### ${h.title}${section ? ` — ${section}` : ''}`, '', body(o, h), '');
    }
    if (blocks.length) parts.push(`## Wymagania (${d.path})`, '', ...blocks);
  }
  for (const req of reqs) if (!found.has(req)) missing.push(`delta: ${req}`);
  return [...parts, ...invariants];
}

const bytes = (text: string): number => Buffer.byteLength(text, 'utf8');

export function buildPacket(root: string, change: string, keys: string[]): Packet {
  if (!keys.length) throw new UsageError('packet wymaga kluczy tasków: packet <zmiana> <T-NN>…');
  const dir = resolveChange(root, change);
  const tasksText = readText(join(dir, 'tasks.md'));
  if (tasksText === undefined) throw new UsageError(`${relative(root, dir)}/tasks.md nie istnieje`);
  const all = parseTasks(tasksText);
  const tasks = keys.map((key) => {
    const t = all.find((x) => x.key === key);
    if (!t) throw new UsageError(`nie ma ${key} w ${relative(root, dir)}/tasks.md`);
    return t;
  });

  const specsDir = join(dir, 'specs');
  const deltas: DeltaFile[] = (isDir(specsDir) ? readdirSync(specsDir).filter((f) => f.endsWith('.md')).sort() : []).map((f) => ({
    path: `specs/${f}`,
    text: readText(join(specsDir, f)) ?? '',
  }));
  const designText = readText(join(dir, 'design.md'));
  const reqs = [...new Set(tasks.flatMap((t) => t.refs.reqs.map((r) => r.req)))];
  const missing: string[] = [];
  const rel = `${relative(root, dir)}/`;
  const lines = [
    `# Paczka: ${change} — ${keys.join(', ')}`,
    '',
    `Źródło: ${rel} (tasks.md, design.md, specs/)`,
    '',
    '## Taski',
    '',
    ...tasks.map((t) => t.text),
    '',
    ...deltaPart(deltas, reqs, missing),
    ...designPart(designText, designWanted(tasks), missing),
  ];
  for (const [source, label] of [
    ['design.md', 'design.md'],
    ['delta', 'delcie'],
  ] as const) {
    const items = missing.filter((m) => m.startsWith(`${source}: `)).map((m) => m.slice(source.length + 2));
    if (items.length) lines.push(`Brak w ${label}: ${items.join(', ')}`);
  }
  if (missing.includes('design.md')) lines.push('Brak pliku design.md');
  const text = `${lines.join('\n').trimEnd()}\n`;

  const files = [
    { path: 'tasks.md', text: tasksText },
    ...(designText === undefined ? [] : [{ path: 'design.md', text: designText }]),
    ...deltas,
  ];
  const filesBytes = files.reduce((sum, f) => sum + bytes(f.text), 0);
  return {
    change,
    dir: rel,
    keys,
    text,
    missing,
    stats: {
      packetBytes: bytes(text),
      packetTokens: tokens(bytes(text)),
      files: files.map((f) => f.path),
      filesBytes,
      filesTokens: tokens(filesBytes),
    },
  };
}
