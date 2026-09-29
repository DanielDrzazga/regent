// Pierwsza tura subagenta — pomiar paczki apply (docs/plans/task-core-check.md). Tura i tokeny jak
// w transcript.ts: koniec na end_turn/… albo turn_duration, wejście wywołania = input + zapis
// i odczyt cache, deduplikacja po message.id. Czysta funkcja: linie JSONL na wejściu.

import { usageFromRecord } from './pricing.js';
import { resultText } from './tools.js';
import { TURN_END } from './transcript.js';

export interface FirstTurn {
  prompt: string;
  cwd?: string;
  /** Czas pierwszego rekordu (ms). */
  startedAt?: number;
  /** Tokeny wejścia każdego wywołania API w pierwszej turze, po kolei. */
  calls: number[];
  /** Kontekst wywołania, które jako pierwsze zmieniło plik (Edit, Write, MultiEdit, NotebookEdit). */
  atFirstEdit?: number;
  /** Bajty wyników Read plików zmiany: tasks.md, design.md, specs/*.md w ai/changes/. */
  changeReadBytes: number;
  /** `BRAK W PACZCE: <plik> › <sekcja>` z odpowiedzi całego transkryptu, bez powtórzeń. */
  missing: string[];
}

const EDITS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);
const CHANGE_FILE = /ai\/changes\/.*(\/tasks\.md|\/design\.md|\/specs\/.+\.md)$/;
const MISSING = /BRAK W PACZCE:\s*(.+)$/;

type Rec = Record<string, unknown>;
const isObj = (v: unknown): v is Rec => typeof v === 'object' && v !== null && !Array.isArray(v);
const blocks = (content: unknown): Rec[] => (Array.isArray(content) ? content.filter(isObj) : []);

/** Klucz `<plik> › <sekcja>` z linii raportu; wzorzec z promptu (`<plik>`) pomijamy. */
function missingKey(line: string): string | undefined {
  const m = MISSING.exec(line);
  if (!m) return undefined;
  const key = m[1]!.split(/\s+—\s+/)[0]!.replace(/[`*]/g, '').trim();
  return key && !key.includes('<plik>') ? key : undefined;
}

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
        if (b.type !== 'text' || typeof b.text !== 'string') continue;
        for (const l of b.text.split('\n')) {
          const key = missingKey(l);
          if (key) missing.add(key);
        }
      }
    }
    if (ended) continue;

    if (rec.type === 'user' && msg) {
      if (!t) {
        const prompt = resultText(msg.content);
        if (prompt) t = { prompt, calls: [], changeReadBytes: 0, missing: [] };
        continue;
      }
      for (const b of blocks(msg.content)) {
        if (b.type === 'tool_result' && typeof b.tool_use_id === 'string' && changeReads.has(b.tool_use_id)) {
          t.changeReadBytes += Buffer.byteLength(resultText(b.content));
        }
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
        if (EDITS.has(b.name)) t.atFirstEdit ??= t.calls.at(-1);
        const input = isObj(b.input) ? b.input : {};
        if (b.name === 'Read' && typeof b.id === 'string' && typeof input.file_path === 'string' && CHANGE_FILE.test(input.file_path)) {
          changeReads.add(b.id);
        }
      }
      if (typeof msg.stop_reason === 'string' && TURN_END.has(msg.stop_reason)) ended = true;
    }
  }

  if (!t || !t.calls.length) return undefined;
  return { ...t, ...(cwd ? { cwd } : {}), ...(startedAt !== undefined ? { startedAt } : {}), missing: [...missing] };
}
