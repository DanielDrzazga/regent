// Artefakty SDD projektu. Stan aktywnych zmian liczy `scripts/sdd-check.sh status` — wołamy skrypt,
// nie kopiujemy jego logiki. Archiwum (`ai/changes/archive/`) czytamy sami, bo skrypt go nie raportuje.

import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** sdd-check.sh z tego samego repo pluginu: `src/` i `dist/` leżą na tej samej głębokości. */
export const SDD_CHECK = fileURLToPath(new URL('../../../scripts/sdd-check.sh', import.meta.url));

export const changesDir = (root: string): string => join(root, 'ai', 'changes');
export const changeDir = (root: string, name: string): string => join(root, 'ai', 'changes', name);
export const archiveDir = (root: string): string => join(root, 'ai', 'changes', 'archive');

export interface ChangeStatus {
  name: string;
  /** Pole Status z proposal.md; `brak`, gdy pola albo pliku nie ma. */
  status: string;
  done: number;
  total: number;
  /** null — brak verification.md; '' — plik bez pola Verdict. */
  verdict: string | null;
  head: string | null;
}

const STATUS_LINE = /^INFO {2}(.+?): Status=(.*) tasks=(-|\d+\/\d+) verification=(.*)$/;

/** Jedna linia `sdd-check.sh status` na aktywną zmianę. */
export function parseStatus(stdout: string): ChangeStatus[] {
  return stdout.split('\n').flatMap((line) => {
    const m = STATUS_LINE.exec(line);
    if (!m) return [];
    const [, name, status, tasks, verification] = m as unknown as [string, string, string, string, string];
    const [done = 0, total = 0] = tasks === '-' ? [] : tasks.split('/').map(Number);
    const at = verification.lastIndexOf('@');
    const verified = verification !== 'brak' && at >= 0;
    return [
      {
        name,
        status,
        done,
        total,
        verdict: verified ? verification.slice(0, at) : null,
        head: verified ? verification.slice(at + 1) || null : null,
      },
    ];
  });
}

export function sddStatus(root: string, script: string = SDD_CHECK): ChangeStatus[] {
  const r = spawnSync('bash', [script, 'status'], { cwd: root, encoding: 'utf8', timeout: 30_000 });
  if (r.error) throw new Error(`sdd-check.sh status: ${r.error.message}`);
  if (r.status !== 0) {
    const first = `${r.stdout}${r.stderr}`.trim().split('\n')[0] ?? '';
    throw new Error(`sdd-check.sh status: kod ${r.status}${first ? ` — ${first}` : ''}`);
  }
  return parseStatus(r.stdout);
}

export const isDir = (path: string): boolean => {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
};

const subdirs = (dir: string): string[] => {
  try {
    return readdirSync(dir)
      .filter((name) => !name.startsWith('.') && isDir(join(dir, name)))
      .sort();
  } catch {
    return [];
  }
};

/** Aktywne zmiany: katalogi w `ai/changes/` poza `archive/` — ten sam zbiór, co `ai/changes/*\/` w skrypcie. */
export const activeChanges = (root: string): string[] => subdirs(changesDir(root)).filter((name) => name !== 'archive');

export interface Archived {
  name: string;
  dir: string;
}

/** Katalogi archiwum `RRRR-MM-DD-<zmiana>`; przy powtórzonej nazwie wygrywa najnowszy. */
export function archivedChanges(root: string): Map<string, Archived> {
  const entries = subdirs(archiveDir(root)).map((dir) => ({ name: dir.replace(/^\d{4}-\d{2}-\d{2}-/, ''), dir }));
  return new Map(entries.map((a) => [a.name, a]));
}

export const readText = (path: string): string | undefined => {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return undefined;
  }
};

/**
 * Pole z tabeli metadanych (`| Status | Approved |`) albo linii `Status: Approved` — jak `meta_field`
 * w sdd-check.sh: pogrubienie i backticki to formatowanie, wartość z `/` w całości, inaczej pierwsze słowo.
 * Tylko dla archiwum: skrypt nie ma trybu, który czyta zarchiwizowane proposal.md.
 */
export function metaField(text: string, key: string): string | undefined {
  const table = new RegExp(`^\\|[ \\t]*${key}[ \\t]*\\|([^|]*)`);
  const line = new RegExp(`^${key}:[ \\t](.*)$`);
  for (const raw of text.split('\n')) {
    const clean = raw.replace(/\r$/, '').replace(/[*`]/g, '');
    const m = table.exec(clean) ?? line.exec(clean);
    if (!m) continue;
    const value = m[1]!.trim();
    return value.includes('/') ? value : value.split(/[ \t]+/)[0];
  }
  return undefined;
}

export const isAbandoned = (root: string, archived: Archived): boolean => {
  const proposal = readText(join(archiveDir(root), archived.dir, 'proposal.md'));
  return proposal !== undefined && metaField(proposal, 'Status') === 'Abandoned';
};

/** Pliki, z których `sdd-check.sh status` liczy stan zmiany. */
const STATE_FILES = ['proposal.md', 'tasks.md', 'verification.md'];

/** Sygnatura treści plików stanu — bez zmiany nie ma po co wołać skryptu. */
export function changeSig(dir: string): string {
  const hash = createHash('sha1');
  for (const file of STATE_FILES) {
    const text = readText(join(dir, file));
    hash.update(`${file}\0${text === undefined ? '-' : `+${text}`}\0`);
  }
  return hash.digest('hex').slice(0, 16);
}
