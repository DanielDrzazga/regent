import { homedir } from 'node:os';
import { join } from 'node:path';

export const defaultClaudeDir = (env: NodeJS.ProcessEnv = process.env): string => env.CLAUDE_CONFIG_DIR ?? join(homedir(), '.claude');
