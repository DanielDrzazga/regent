import { cpSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { main, type Io } from '../src/main.js';

export const FIXTURES = fileURLToPath(new URL('./fixtures', import.meta.url));

/** Świeży katalog tymczasowy — każda baza w teście jest izolowana. */
export const tempDir = (): string => realpathSync(mkdtempSync(join(tmpdir(), 'regent-')));

/** Katalog z `.git` — korzeń projektu, jak w prawdziwym repo. */
export function gitProject(): string {
  const dir = tempDir();
  mkdirSync(join(dir, '.git'));
  return dir;
}

/** Projekt z syntetycznymi artefaktami SDD — kopia `fixtures/ai/` w katalogu z `.git`. */
export function sddProject(): string {
  const dir = gitProject();
  cpSync(join(FIXTURES, 'ai'), join(dir, 'ai'), { recursive: true });
  return dir;
}

export function write(root: string, path: string, text: string): void {
  mkdirSync(dirname(join(root, path)), { recursive: true });
  writeFileSync(join(root, path), text);
}

export const read = (root: string, path: string): string => readFileSync(join(root, path), 'utf8');

export function edit(root: string, path: string, fn: (text: string) => string): void {
  writeFileSync(join(root, path), fn(read(root, path)));
}

export interface Run {
  code: number;
  out: string;
  err: string;
}

export type Cli = (...argv: string[]) => Run;

export interface CliOptions {
  env?: NodeJS.ProcessEnv;
  cwd?: string;
  now?: () => number;
}

/**
 * regent w procesie testu z własną bazą (REGENT_DB w katalogu tymczasowym — nigdy baza maszyny),
 * katalogiem i zegarem. Kolejne wywołania tej samej funkcji pracują na tej samej bazie.
 */
export function cli(options: CliOptions = {}): Cli & { db: string } {
  const db = join(tempDir(), 'regent.db');
  const cwd = options.cwd ?? gitProject();
  const run = (...argv: string[]): Run => {
    const out: string[] = [];
    const err: string[] = [];
    const io: Io = {
      argv,
      env: { REGENT_DB: db, ...options.env },
      cwd,
      now: options.now ?? (() => Date.UTC(2026, 8, 29, 10, 0)),
      out: (text) => out.push(text),
      err: (text) => err.push(text),
    };
    const code = main(io);
    return { code, out: out.join('\n'), err: err.join('\n') };
  };
  return Object.assign(run, { db });
}
