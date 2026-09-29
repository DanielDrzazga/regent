// Projekt zadania = korzeń gita (katalog z `.git`, także plikiem w worktree); poza repo — sam katalog.

import { existsSync, realpathSync } from 'node:fs';
import { dirname, join } from 'node:path';

export function projectRoot(cwd: string): string {
  const start = realpathSync(cwd);
  for (let dir = start; ; dir = dirname(dir)) {
    if (existsSync(join(dir, '.git'))) return dir;
    if (dirname(dir) === dir) return start;
  }
}
