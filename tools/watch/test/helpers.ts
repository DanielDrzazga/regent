import { cpSync, mkdtempSync, readFileSync, utimesSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Syntetyczne fixture'y w kształcie rekordów ze spike'a (docs/plans/agent-teams-view.md).
export const FIXTURES = fileURLToPath(new URL('./fixtures/claude', import.meta.url));
export const CWD = '/tmp/demo';
export const LEAD = '11111111-aaaa-4bbb-8ccc-000000000001';
export const ALPHA = '22222222-aaaa-4bbb-8ccc-000000000002';
export const BETA = '33333333-aaaa-4bbb-8ccc-000000000003';
export const OTHER = '44444444-aaaa-4bbb-8ccc-000000000004';
export const TEAM = 'session-11111111';

export const projectFile = (root: string, id: string): string => join(root, 'projects', '-tmp-demo', `${id}.jsonl`);
export const readFixture = (id: string): string => readFileSync(projectFile(FIXTURES, id), 'utf8');

/** Kopia fixture'ów w katalogu tymczasowym; mtime: OTHER < LEAD < BETA < ALPHA (najnowszy). */
export function claudeDirCopy(): string {
  const dir = mkdtempSync(join(tmpdir(), 'regent-watch-'));
  cpSync(FIXTURES, dir, { recursive: true });
  const base = Date.now() / 1000 - 600;
  [OTHER, LEAD, BETA, ALPHA].forEach((id, i) => utimesSync(projectFile(dir, id), base + i * 10, base + i * 10));
  return dir;
}
