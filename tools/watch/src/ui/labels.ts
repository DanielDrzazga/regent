import type { ProblemKind } from '../parse/tools.js';

export const PROBLEM_LABEL_TEXT: Record<ProblemKind, string> = {
  hook: 'blokada hooka',
  permission: 'odmowa',
  tool: 'błąd narzędzia',
  api: 'błąd API',
};
