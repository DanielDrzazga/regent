import { describe, expect, it } from 'vitest';
import { classifyError, resultText, summarizeTool } from '../src/parse/tools.js';

describe('classifyError', () => {
  const hook = 'PreToolUse:Bash hook error: [bash "/plugins/regent/scripts/hooks/git-guard.sh"]: SDD git-guard: git add całości.\n';

  it('rozpoznaje blokadę hooka i nazwę skryptu', () => {
    expect(classifyError(hook)).toEqual({ kind: 'hook', hook: 'git-guard.sh', text: 'SDD git-guard: git add całości.' });
  });

  it('zdejmuje przedrostek „Error: " z toolUseResult', () => {
    expect(classifyError(`Error: ${hook}`).kind).toBe('hook');
  });

  it('odmowa użytkownika to odmowa, zwykły błąd — błąd narzędzia', () => {
    expect(classifyError("The user doesn't want to proceed with this tool use.").kind).toBe('permission');
    expect(classifyError('File does not exist.')).toEqual({ kind: 'tool', text: 'File does not exist.' });
  });
});

describe('summarizeTool', () => {
  it('opisuje typowe narzędzia', () => {
    expect(summarizeTool('Bash', { command: 'npm test', description: 'Uruchom testy' })).toBe('Uruchom testy');
    expect(summarizeTool('Bash', { command: 'git status' })).toBe('git status');
    expect(summarizeTool('Read', { file_path: '/tmp/demo/src/a.ts' }, '/tmp/demo')).toBe('src/a.ts');
    expect(summarizeTool('SendMessage', { to: 'beta', summary: 'Start' })).toBe('→ beta: Start');
    expect(summarizeTool('Agent', { name: 'alpha', description: 'Przegląd' })).toBe('alpha: Przegląd');
    expect(summarizeTool('Nieznane', { x: 1 })).toBe('');
  });

  it('przycina długie opisy do jednej linii', () => {
    const s = summarizeTool('Bash', { command: `echo ${'x'.repeat(200)}\nls` });
    expect(s.length).toBe(120);
    expect(s.endsWith('…')).toBe(true);
    expect(s).not.toContain('\n');
  });
});

describe('resultText', () => {
  it('łączy bloki tekstu, ignoruje resztę', () => {
    expect(resultText([{ type: 'text', text: 'a' }, { type: 'image' }, { type: 'text', text: 'b' }])).toBe('a\nb');
    expect(resultText(undefined)).toBe('');
  });
});
