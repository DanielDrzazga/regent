import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Syntetyczne fixture'y w kształcie rekordów ze spike'a (docs/plans/agent-teams-view.md).
export const FIXTURES = fileURLToPath(new URL('./fixtures/claude', import.meta.url));
export const LEAD = '11111111-aaaa-4bbb-8ccc-000000000001';
export const ALPHA = '22222222-aaaa-4bbb-8ccc-000000000002';
export const BETA = '33333333-aaaa-4bbb-8ccc-000000000003';
export const TEAM = 'session-11111111';

export const projectFile = (root: string, id: string): string => join(root, 'projects', '-tmp-demo', `${id}.jsonl`);
export const readFixture = (id: string): string => readFileSync(projectFile(FIXTURES, id), 'utf8');
