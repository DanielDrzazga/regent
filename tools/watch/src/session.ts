// Odnajdywanie plików sesji: transkrypt leada, członków zespołu i subagentów.
// Tylko odczyt — widok niczego nie zapisuje w ~/.claude.

import { closeSync, existsSync, openSync, readFileSync, readSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, join } from 'node:path';

export const defaultClaudeDir = (): string => process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), '.claude');

/** Katalog projektu w ~/.claude/projects: każdy znak spoza [A-Za-z0-9] → „-". */
export const projectKey = (cwd: string): string => cwd.replace(/[^A-Za-z0-9]/g, '-');

export const projectDir = (claudeDir: string, cwd: string): string => join(claudeDir, 'projects', projectKey(cwd));

export const sessionIdOf = (file: string): string => basename(file, '.jsonl');

interface Head {
  sessionId?: string;
  agentName?: string;
  teamName?: string;
  /** Był już rekord rozmowy (user/assistant/system/attachment) — u członka zespołu niesie teamName. */
  conversational?: boolean;
}

const CONVERSATIONAL = new Set(['user', 'assistant', 'system', 'attachment']);

const HEAD_BYTES = 256 * 1024;

/** Tożsamość transkryptu z jego początku (członek zespołu ma agentName i teamName w rekordach). */
export function readHead(file: string): Head {
  const head: Head = {};
  let fd: number | undefined;
  try {
    fd = openSync(file, 'r');
    const buf = Buffer.alloc(HEAD_BYTES);
    const n = readSync(fd, buf, 0, HEAD_BYTES, 0);
    const text = buf.subarray(0, n).toString('utf8');
    const lines = text.split('\n');
    if (n === HEAD_BYTES) lines.pop(); // ostatnia linia może być ucięta
    for (const line of lines) {
      if (!line.trim()) continue;
      let rec: Record<string, unknown>;
      try {
        rec = JSON.parse(line) as Record<string, unknown>;
      } catch {
        continue;
      }
      if (typeof rec.sessionId === 'string') head.sessionId ??= rec.sessionId;
      if (typeof rec.agentName === 'string') head.agentName ??= rec.agentName;
      if (typeof rec.teamName === 'string') head.teamName ??= rec.teamName;
      if (typeof rec.type === 'string' && CONVERSATIONAL.has(rec.type)) head.conversational = true;
      if (head.sessionId && head.agentName && head.teamName) break;
    }
  } catch {
    // brak pliku albo brak dostępu — pusta tożsamość
  } finally {
    if (fd !== undefined) closeSync(fd);
  }
  return head;
}

function jsonlFiles(dir: string): Array<{ file: string; mtime: number }> {
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  const out: Array<{ file: string; mtime: number }> = [];
  for (const n of names) {
    if (!n.endsWith('.jsonl')) continue;
    const file = join(dir, n);
    try {
      const st = statSync(file);
      if (st.isFile()) out.push({ file, mtime: st.mtimeMs });
    } catch {
      // plik zniknął między readdir a stat
    }
  }
  return out;
}

/** Transkrypt członka zespołu → transkrypt leada z tego samego katalogu (po teamName). */
export function toLeadTranscript(file: string): string {
  const head = readHead(file);
  if (!head.agentName || !head.teamName?.startsWith('session-')) return file;
  const prefix = head.teamName.slice('session-'.length);
  const lead = jsonlFiles(dirname(file))
    .map((f) => f.file)
    .find((f) => f !== file && sessionIdOf(f).startsWith(prefix));
  return lead ?? file;
}

export interface FindOptions {
  claudeDir: string;
  cwd: string;
  /** Pełne ID sesji, jego prefiks albo nazwa zespołu session-<8 znaków>. */
  session?: string;
}

/** Transkrypt leada: wskazana sesja albo najnowsza w katalogu projektu bieżącego katalogu. */
export function findLeadTranscript(opts: FindOptions): string | undefined {
  const own = projectDir(opts.claudeDir, opts.cwd);
  if (!opts.session) {
    const newest = jsonlFiles(own).sort((a, b) => b.mtime - a.mtime)[0];
    return newest ? toLeadTranscript(newest.file) : undefined;
  }
  const prefix = opts.session.replace(/^session-/, '').replace(/\.jsonl$/, '');
  const match = (dir: string) =>
    jsonlFiles(dir)
      .filter((f) => sessionIdOf(f.file).startsWith(prefix))
      .sort((a, b) => b.mtime - a.mtime)[0]?.file;
  let found = match(own);
  if (!found) {
    const projects = join(opts.claudeDir, 'projects');
    let dirs: string[] = [];
    try {
      dirs = readdirSync(projects).map((d) => join(projects, d));
    } catch {
      return undefined;
    }
    for (const d of dirs) {
      found = match(d);
      if (found) break;
    }
  }
  return found ? toLeadTranscript(found) : undefined;
}

/**
 * Transkrypty członków zespołu: pliki z rekordami teamName = nazwa zespołu, nowsze niż start leada.
 * `rejected` zbiera pliki, które na pewno nie należą do zespołu — kolejne wyszukiwania ich nie czytają.
 */
export function findTeammates(
  dirs: string[],
  teamName: string,
  since: number,
  known: Set<string>,
  rejected = new Set<string>(),
): string[] {
  const out: string[] = [];
  for (const dir of new Set(dirs)) {
    for (const { file, mtime } of jsonlFiles(dir)) {
      if (known.has(file) || rejected.has(file) || mtime < since) continue;
      const head = readHead(file);
      if (head.teamName === teamName && head.agentName) out.push(file);
      else if (head.conversational) rejected.add(file);
    }
  }
  return out;
}

export interface SubagentFile {
  file: string;
  agentType?: string;
  description?: string;
}

/** Subagenci sesji: <sesja>/subagents/agent-<id>.jsonl + agent-<id>.meta.json. */
export function findSubagents(transcript: string): SubagentFile[] {
  const dir = join(transcript.replace(/\.jsonl$/, ''), 'subagents');
  if (!existsSync(dir)) return [];
  return jsonlFiles(dir)
    .sort((a, b) => a.mtime - b.mtime)
    .map(({ file }) => {
      const sub: SubagentFile = { file };
      try {
        const meta = JSON.parse(readFileSync(file.replace(/\.jsonl$/, '.meta.json'), 'utf8')) as Record<string, unknown>;
        if (typeof meta.agentType === 'string') sub.agentType = meta.agentType;
        if (typeof meta.description === 'string') sub.description = meta.description;
      } catch {
        // brak meta — subagent bez typu
      }
      return sub;
    });
}
