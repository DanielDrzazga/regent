// Pierwsza tura subagenta — pomiar paczki apply (docs/plans/task-core-check.md,
// docs/plans/apply-tokens-detekcja.md). Tura i tokeny jak w transcript.ts: koniec na end_turn/…
// albo turn_duration, wejście wywołania = input + zapis i odczyt cache, deduplikacja po message.id.
// Czysta funkcja: linie JSONL na wejściu.

import { usageFromRecord } from './pricing.js';
import { resultText } from './tools.js';
import { TURN_END } from './transcript.js';

export interface FirstTurn {
  prompt: string;
  /** Skąd agent ma paczkę (`# Paczka:`): z promptu albo z wyniku narzędzia w pierwszej turze (plik). */
  packet?: 'prompt' | 'tool';
  cwd?: string;
  /** Czas pierwszego rekordu (ms). */
  startedAt?: number;
  /** Tokeny wejścia każdego wywołania API w pierwszej turze, po kolei. */
  calls: number[];
  /** Kontekst wywołania, które jako pierwsze zmieniło plik (Edit, Write, MultiEdit, NotebookEdit, zapis w Bash). */
  atFirstEdit?: number;
  /** Bajty wyników Read i Bash plików zmiany: tasks.md, design.md, specs/*.md w ai/changes/. */
  changeReadBytes: number;
  /** `BRAK W PACZCE: <plik> › <sekcja>` z odpowiedzi i raportu (SubagentHandback) całego transkryptu, bez powtórzeń. */
  missing: string[];
}

const EDITS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);
const HANDBACK = 'SubagentHandback';
const CHANGE_FILE = /ai\/changes\/.*(\/tasks\.md|\/design\.md|\/specs\/.+\.md)$/;
// Nagłówek paczki z `regent task packet` — w prompcie albo w wyniku Read (z numerem linii).
const PACKET = /^(?:\s*\d+\t)?# Paczka: /m;
const MISSING = /BRAK W PACZCE:\s*(.+)$/;
const MISSING_HEADING = /^\s*#+\s*BRAK W PACZCE\b/;
const BULLET = /^\s*(?:[-*]|\d+\.)\s+(.+)$/;
const NOTHING = /^(brak|nic|nie|none)\b/i;
const HEREDOC = /<<-?\s*(['"]?)(\w+)\1/;
const BASH_WRITE = [
  /(?:^|[^\d&<>])>>?(?!&)\s*(?!\/dev\/null\b)[^\s|&;<>()]/,
  /\btee\b/,
  /\bsed\b[^|;&]*\s(?:-[a-zA-Z]*i|--in-place)/,
  /\bperl\b[^|;&]*\s-[a-zA-Z]*i/,
];

type Rec = Record<string, unknown>;
const isObj = (v: unknown): v is Rec => typeof v === 'object' && v !== null && !Array.isArray(v);
const blocks = (content: unknown): Rec[] => (Array.isArray(content) ? content.filter(isObj) : []);

/** Klucz `<plik> › <sekcja>` ze zgłoszenia; wzorzec z promptu (`<plik>`) i „brak” pomijamy. */
function missingKey(raw: string): string | undefined {
  const key = raw.split(/\s+—\s+/)[0]!.replace(/[`*]/g, '').trim();
  return key && !key.includes('<plik>') && !NOTHING.test(key) ? key : undefined;
}

/** Zgłoszenia z tekstu: linie `BRAK W PACZCE: …` i punkty pod nagłówkiem `BRAK W PACZCE`. */
export function missingKeys(text: string): string[] {
  const keys: string[] = [];
  let section = false;
  for (const line of text.split('\n')) {
    const heading = /^\s*#/.test(line);
    if (heading) section = MISSING_HEADING.test(line);
    const raw = MISSING.exec(line)?.[1] ?? (section && !heading ? BULLET.exec(line)?.[1] : undefined);
    const key = raw === undefined ? undefined : missingKey(raw);
    if (key) keys.push(key);
  }
  return keys;
}

/** Polecenie Bash zapisuje plik: przekierowanie, tee, sed -i, perl -i — poza heredokiem i cudzysłowami. */
export function bashWrites(command: string): boolean {
  let end: string | undefined;
  for (const line of command.split('\n')) {
    if (end !== undefined) {
      if (line.trim() === end) end = undefined;
      continue;
    }
    const bare = line.replace(/'[^']*'|"(?:[^"\\]|\\.)*"/g, "''");
    if (BASH_WRITE.some((re) => re.test(bare))) return true;
    end = HEREDOC.exec(line)?.[2];
  }
  return false;
}

/** Polecenie Bash czyta plik zmiany: wskazuje ai/changes/ i tasks.md, design.md albo specs/. */
const bashReadsChange = (command: string): boolean =>
  command.includes('ai/changes/') && /\btasks\.md\b|\bdesign\.md\b|\bspecs\//.test(command);

export function firstTurn(lines: Iterable<string>): FirstTurn | undefined {
  let t: FirstTurn | undefined;
  let cwd: string | undefined;
  let startedAt: number | undefined;
  let ended = false;
  const seen = new Set<string>();
  const changeReads = new Set<string>();
  const missing = new Set<string>();

  for (const line of lines) {
    let rec: unknown;
    try {
      rec = JSON.parse(line);
    } catch {
      continue;
    }
    if (!isObj(rec)) continue;
    if (typeof rec.cwd === 'string') cwd ??= rec.cwd;
    const ts = typeof rec.timestamp === 'string' ? Date.parse(rec.timestamp) : Number.NaN;
    if (!Number.isNaN(ts)) startedAt ??= ts;
    const msg = isObj(rec.message) ? rec.message : undefined;

    if (rec.type === 'assistant' && msg) {
      for (const b of blocks(msg.content)) {
        const input = isObj(b.input) ? b.input : {};
        const text =
          b.type === 'text' && typeof b.text === 'string'
            ? b.text
            : b.type === 'tool_use' && b.name === HANDBACK && typeof input.message === 'string'
              ? input.message
              : undefined;
        if (text) for (const key of missingKeys(text)) missing.add(key);
      }
    }
    if (ended) continue;

    if (rec.type === 'user' && msg) {
      if (!t) {
        const prompt = resultText(msg.content);
        if (prompt) t = { prompt, ...(PACKET.test(prompt) ? { packet: 'prompt' as const } : {}), calls: [], changeReadBytes: 0, missing: [] };
        continue;
      }
      for (const b of blocks(msg.content)) {
        if (b.type !== 'tool_result') continue;
        const text = resultText(b.content);
        if (typeof b.tool_use_id === 'string' && changeReads.has(b.tool_use_id)) t.changeReadBytes += Buffer.byteLength(text);
        if (!t.packet && PACKET.test(text)) t.packet = 'tool';
      }
    } else if (rec.type === 'system' && rec.subtype === 'turn_duration') {
      ended = t !== undefined;
    } else if (rec.type === 'assistant' && msg && t) {
      const id = typeof msg.id === 'string' ? msg.id : undefined;
      if (id && !seen.has(id) && msg.usage) {
        seen.add(id);
        const u = usageFromRecord(msg.usage);
        t.calls.push(u.input + u.cacheWrite5m + u.cacheWrite1h + u.cacheRead);
      }
      for (const b of blocks(msg.content)) {
        if (b.type !== 'tool_use' || typeof b.name !== 'string') continue;
        const input = isObj(b.input) ? b.input : {};
        const command = b.name === 'Bash' && typeof input.command === 'string' ? input.command : undefined;
        if (EDITS.has(b.name) || (command !== undefined && bashWrites(command))) t.atFirstEdit ??= t.calls.at(-1);
        const reads =
          (b.name === 'Read' && typeof input.file_path === 'string' && CHANGE_FILE.test(input.file_path)) ||
          (command !== undefined && bashReadsChange(command));
        if (reads && typeof b.id === 'string') changeReads.add(b.id);
      }
      if (typeof msg.stop_reason === 'string' && TURN_END.has(msg.stop_reason)) ended = true;
    }
  }

  if (!t || !t.calls.length) return undefined;
  return { ...t, ...(cwd ? { cwd } : {}), ...(startedAt !== undefined ? { startedAt } : {}), missing: [...missing] };
}
