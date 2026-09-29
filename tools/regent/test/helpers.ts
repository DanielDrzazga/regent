import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { main, type Io } from '../src/main.js';

/** Świeży katalog tymczasowy — każda baza w teście jest izolowana. */
export const tempDir = (): string => mkdtempSync(join(tmpdir(), 'regent-'));

export interface Run {
  code: number;
  out: string;
  err: string;
}

/** Wywołanie regent w procesie testu: własne środowisko, katalog i zegar. */
export function regent(argv: string[], io: Partial<Omit<Io, 'argv' | 'out' | 'err'>> = {}): Run {
  const out: string[] = [];
  const err: string[] = [];
  const code = main({
    argv,
    env: {},
    cwd: tmpdir(),
    now: () => 0,
    ...io,
    out: (text) => out.push(text),
    err: (text) => err.push(text),
  });
  return { code, out: out.join('\n'), err: err.join('\n') };
}
