// Jednolinijkowy opis wywołania narzędzia i klasyfikacja błędów z tool_result.

const clip = (s: string, n = 120): string => {
  const line = s.replace(/\s+/g, ' ').trim();
  return line.length > n ? `${line.slice(0, n - 1)}…` : line;
};

const str = (v: unknown): string => (typeof v === 'string' ? v : '');

function relPath(p: string, cwd: string | undefined): string {
  if (cwd && p.startsWith(`${cwd}/`)) return p.slice(cwd.length + 1);
  return p;
}

/** Bieżąca akcja agenta w tabeli i na osi czasu, np. „Read src/a.ts", „Bash: Uruchom testy". */
export function summarizeTool(name: string, input: unknown, cwd?: string): string {
  const i = (input ?? {}) as Record<string, unknown>;
  switch (name) {
    case 'Bash':
      return clip(str(i.description) || str(i.command));
    case 'Read':
    case 'Write':
    case 'Edit':
    case 'NotebookEdit':
      return clip(relPath(str(i.file_path) || str(i.notebook_path), cwd));
    case 'Grep':
      return clip(`"${str(i.pattern)}"${i.path ? ` ${relPath(str(i.path), cwd)}` : ''}`);
    case 'Glob':
      return clip(str(i.pattern));
    case 'Agent':
    case 'Task':
      return clip([str(i.name) || str(i.subagent_type), str(i.description)].filter(Boolean).join(': '));
    case 'SendMessage':
      return clip(`→ ${str(i.to)}${i.summary ? `: ${str(i.summary)}` : ''}`);
    case 'TaskCreate':
      return clip(str(i.subject));
    case 'TaskUpdate':
      return clip(`#${str(i.taskId)} ${[str(i.status), str(i.owner)].filter(Boolean).join(' ')}`);
    case 'WebFetch':
      return clip(str(i.url));
    case 'WebSearch':
    case 'ToolSearch':
      return clip(str(i.query));
    case 'Skill':
      return clip(str(i.skill));
    default:
      return '';
  }
}

export type ProblemKind = 'hook' | 'permission' | 'tool' | 'api';

export interface ClassifiedError {
  kind: ProblemKind;
  /** Treść do wyświetlenia — przy blokadzie hooka bez przedrostka Claude Code. */
  text: string;
  /** Nazwa skryptu hooka, gdy dało się ją ustalić (np. git-guard.sh). */
  hook?: string;
}

// Claude Code: „PreToolUse:Bash hook error: [<polecenie hooka>]: <stderr hooka>".
const HOOK_RE = /^(\w+):(\S+) hook error: \[(.*?)\]: ([\s\S]*)$/;
const PERMISSION_RE = /doesn't want to proceed|tool use was rejected|permission to use .* (?:has been )?denied/i;

function hookScript(command: string): string | undefined {
  const tokens = command.replace(/["']/g, ' ').split(/\s+/).filter(Boolean);
  const path = [...tokens].reverse().find((t) => t.includes('/'));
  return path ? path.slice(path.lastIndexOf('/') + 1) : tokens[tokens.length - 1];
}

/** Tekst z tool_result.content: string albo lista bloków {type: "text", text}. */
export function resultText(content: unknown): string {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((b) => (b && typeof b === 'object' && 'text' in b ? str((b as { text: unknown }).text) : ''))
      .filter(Boolean)
      .join('\n');
  }
  return '';
}

export function classifyError(raw: string): ClassifiedError {
  const text = raw.replace(/^Error: /, '').trim();
  const m = HOOK_RE.exec(text);
  if (m) {
    const hook = hookScript(m[3] ?? '');
    return { kind: 'hook', text: clip(m[4] ?? '', 300), ...(hook ? { hook } : {}) };
  }
  if (PERMISSION_RE.test(text)) return { kind: 'permission', text: clip(text, 300) };
  return { kind: 'tool', text: clip(text, 300) };
}
