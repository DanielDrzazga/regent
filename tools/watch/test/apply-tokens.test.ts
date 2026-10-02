import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { main } from '../src/apply-tokens.js';

// Syntetyczny ~/.claude/projects: subagenci w <projekt>/<sesja>/subagents/agent-*.jsonl + .meta.json.
interface Sub {
  project: string;
  id: string;
  type?: string;
  cwd: string;
  date: string;
  prompt: string;
  /** Wejście kolejnych wywołań API (cały kontekst jako odczyt cache). */
  calls: number[];
  report?: string;
  /** Pierwszy Read to paczka z pliku (`1\t# Paczka: …`), nie design.md. */
  packetFile?: boolean;
}

function transcript(s: Sub): string {
  const ts = `${s.date}T12:00:00.000Z`;
  const recs: object[] = [{ type: 'user', timestamp: ts, cwd: s.cwd, message: { role: 'user', content: s.prompt } }];
  s.calls.forEach((n, i) => {
    const last = i === s.calls.length - 1;
    const content = last
      ? [{ type: 'text', text: s.report ?? 'Gotowe.' }]
      : [{ type: 'tool_use', id: `t${i}`, name: i === 1 ? 'Edit' : 'Read', input: { file_path: !i && s.packetFile ? '/tmp/scratch/packet.md' : `${s.cwd}/ai/changes/x/${i ? 'src.ts' : 'design.md'}` } }];
    recs.push({
      type: 'assistant',
      timestamp: ts,
      message: { id: `${s.id}-${i}`, content, usage: { input_tokens: 0, cache_read_input_tokens: n, output_tokens: 10 }, stop_reason: last ? 'end_turn' : 'tool_use' },
    });
    const output = !i && s.packetFile ? '1\t# Paczka: x — T-02\n2\t' : 'x'.repeat(i ? 10 : 3500);
    if (!last) recs.push({ type: 'user', timestamp: ts, message: { content: [{ type: 'tool_result', tool_use_id: `t${i}`, content: output }] } });
  });
  return recs.map((r) => JSON.stringify(r)).join('\n');
}

function claudeDir(subs: Sub[], metaOnly: Sub[] = []): string {
  const dir = mkdtempSync(join(tmpdir(), 'regent-apply-tokens-'));
  for (const s of [...subs, ...metaOnly]) {
    const sub = join(dir, 'projects', s.project, 'sesja-1', 'subagents');
    mkdirSync(sub, { recursive: true });
    writeFileSync(join(sub, `agent-${s.id}.meta.json`), JSON.stringify({ agentType: s.type ?? 'backend-dev' }));
    if (subs.includes(s)) writeFileSync(join(sub, `agent-${s.id}.jsonl`), transcript(s));
  }
  return dir;
}

const APPLY = 'Zaimplementuj T-01 ze zmiany ai/changes/x/.';
const PACKET = `${APPLY}\n\n# Paczka: x — T-01\n\nŹródło: ai/changes/x/`;

const SUBS: Sub[] = [
  { project: '-tmp-demo', id: 'a1', type: 'frontend-dev', cwd: '/tmp/demo', date: '2026-09-20', prompt: APPLY, calls: [1000, 5000, 6000] },
  {
    project: '-tmp-demo',
    id: 'a2',
    type: 'regent:backend-dev',
    cwd: '/tmp/demo',
    date: '2026-09-30',
    prompt: PACKET,
    calls: [2000, 2500],
    report: 'Gotowe.\nBRAK W PACZCE: design.md › Error Handling — kody błędów',
  },
  { project: '-tmp-demo', id: 'a6', type: 'frontend-dev', cwd: '/tmp/demo', date: '2026-10-01', prompt: APPLY, calls: [1500, 2500], packetFile: true },
  { project: '-tmp-demo', id: 'a3', type: 'architect', cwd: '/tmp/demo', date: '2026-09-20', prompt: APPLY, calls: [9] },
  { project: '-tmp-demo', id: 'a4', type: 'backend-dev', cwd: '/tmp/demo', date: '2026-09-20', prompt: 'Napraw błąd w logowaniu.', calls: [9] },
  { project: '-tmp-demo-2', id: 'c1', type: 'dba', cwd: '/tmp/demo-2', date: '2026-09-21', prompt: APPLY, calls: [3000, 4000, 8000] },
  { project: '-tmp-inny', id: 'b1', type: 'backend-dev', cwd: '/tmp/inny/.claude/worktrees/w1', date: '2026-09-22', prompt: APPLY, calls: [4000, 7000, 9000] },
];
const NO_TRANSCRIPT: Sub = { project: '-tmp-demo', id: 'a5', type: 'dba', cwd: '/tmp/demo', date: '2026-09-20', prompt: APPLY, calls: [] };

function run(dir: string, ...argv: string[]) {
  const out: string[] = [];
  const err: string[] = [];
  const code = main({ argv, env: { CLAUDE_CONFIG_DIR: dir }, cwd: '/tmp', out: (t) => out.push(t), err: (t) => err.push(t) });
  return { code, out: out.join('\n'), err: err.join('\n') };
}
const json = (dir: string, ...argv: string[]) => JSON.parse(run(dir, '--json', ...argv).out);

describe('regent-apply-tokens — pierwsza tura subagentów apply', () => {
  const dir = claudeDir(SUBS, [NO_TRANSCRIPT]);

  it('próbka: implementujący z promptem o ai/changes/, podział na bez paczki i z paczką (w prompcie albo z pliku)', () => {
    const r = json(dir);
    expect(r.groups.plain.n).toBe(3);
    expect(r.groups.plain.byType).toEqual({ 'frontend-dev': 1, dba: 1, 'backend-dev': 1 });
    expect(r.groups.plain.from).toBe('2026-09-20');
    expect(r.groups.plain.to).toBe('2026-09-22');
    expect(r.groups.plain.median).toEqual({
      sumFirstTurn: 15000,
      calls: 3,
      firstCall: 3000,
      atFirstEdit: 5000,
      maxCtx: 8000,
      changeReadTokens: 1000,
    });
    expect(r.groups.plain.readers).toBe(3);
    expect(r.groups.plain.packetFromFile).toBe(0);
    expect(r.groups.packet.n).toBe(2);
    expect(r.groups.packet.byType).toEqual({ 'backend-dev': 1, 'frontend-dev': 1 });
    expect(r.groups.packet.median.sumFirstTurn).toBe(4250);
    expect(r.groups.packet.readers).toBe(1);
    expect(r.groups.packet.packetFromFile).toBe(1);
    expect(r.missing).toEqual({ 'design.md › Error Handling': 1 });
  });

  it('--project zawęża po cwd: katalog i podkatalogi (worktree), bez sąsiada o wspólnym prefiksie', () => {
    const demo = json(dir, '--project', '/tmp/demo');
    expect([demo.groups.plain.n, demo.groups.packet.n]).toEqual([1, 2]);
    const inny = json(dir, '--project', '/tmp/inny', '--project', '/tmp/demo-2');
    expect([inny.groups.plain.n, inny.groups.packet.n]).toEqual([2, 0]);
    expect(json(dir, '--project', 'demo', '--until', '2026-09-20').groups.plain.n).toBe(1); // względna ścieżka od cwd
  });

  it('--since i --until po dacie pierwszego rekordu', () => {
    expect(json(dir, '--since', '2026-09-25').groups.plain.n).toBe(0);
    expect(json(dir, '--since', '2026-09-25').groups.packet.n).toBe(2);
    expect(json(dir, '--until', '2026-09-21').groups.plain.n).toBe(2);
  });

  it('tekst: tabela median i zgłoszenia BRAK W PACZCE', () => {
    const r = run(dir);
    expect(r.code).toBe(0);
    expect(r.out).toContain('Próbka: 5 subagentów (backend-dev 2, frontend-dev 2, dba 1), 2026-09-20 … 2026-10-01');
    expect(r.out).toMatch(/\n {2}subagenci +3 +2\n/);
    expect(r.out).toMatch(/\n {2}suma wejścia pierwszej tury +15k +4k\n/);
    expect(r.out).toMatch(/\n {2}czytało pliki zmiany +3\/3 +1\/2\n/);
    expect(r.out).toMatch(/\n {2}paczka z pliku +– +1\/2\n/);
    expect(r.out).toMatch(/BRAK W PACZCE:\n {2}1 {2}design\.md › Error Handling$/);
  });

  it('pusta próbka — komunikat, kod 0; zła data — kod 2', () => {
    const empty = mkdtempSync(join(tmpdir(), 'regent-apply-tokens-'));
    expect(run(empty).out).toMatch(/^Brak subagentów apply w próbce/);
    expect(run(dir, '--since', '29.09.2026')).toMatchObject({ code: 2 });
    expect(run(dir, '--until', '2026-13-01')).toMatchObject({ code: 2 });
    expect(run(dir, '--nieznana')).toMatchObject({ code: 2 });
    expect(run(dir, '--help').out).toMatch(/^regent-apply-tokens/);
  });
});
