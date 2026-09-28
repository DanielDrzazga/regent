import { appendFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { SessionStore } from '../src/store.js';
import { ALPHA, LEAD, TEAM, claudeDirCopy, projectFile } from './helpers.js';

const store = () => {
  const dir = claudeDirCopy();
  const s = new SessionStore({ claudeDir: dir, leadFile: projectFile(dir, LEAD), discoveryMs: 0 });
  s.refresh();
  return { dir, s };
};

describe('SessionStore + buildView', () => {
  it('agenci: lead, członkowie (wg dołączenia), subagent', () => {
    const { s } = store();
    const v = s.view();
    expect(v.rows.map((r) => [r.name, r.kind, r.status])).toEqual([
      ['lead', 'lead', 'czeka'],
      ['alpha', 'teammate', 'pracuje'],
      ['beta', 'teammate', 'zamknięty'],
      ['lead›Explore', 'subagent', 'zakończony'],
    ]);
    const alpha = v.rows[1];
    expect(alpha).toMatchObject({ action: 'Bash Uruchom testy', color: 'blue', model: 'haiku-4-5', problems: 1 });
    expect(alpha?.since).toBe(Date.parse('2026-01-01T10:00:09.000Z'));
    expect(v.rows[3]?.model).toBe('sonnet-5');
  });

  it('tokeny i koszt: suma wierszy; koszt wg Claude Code dopiero, gdy każda sesja go zapisała', () => {
    const { s } = store();
    const v = s.view();
    expect(v.totals.tokens).toBe(v.rows.reduce((t, r) => t + r.tokens, 0));
    expect(v.totals.cost).toBeCloseTo(v.rows.reduce((t, r) => t + (r.cost ?? 0), 0), 10);
    expect(v.totals.exactCost).toBeUndefined();
  });

  it('oś czasu posortowana, problemy z nazwą agenta', () => {
    const { s } = store();
    const v = s.view();
    const ts = v.timeline.map((e) => e.ts);
    expect(ts).toEqual([...ts].sort((a, b) => a - b));
    expect(v.problems.map((p) => [p.agent, p.kind])).toEqual([
      ['alpha', 'tool'],
      ['beta', 'hook'],
    ]);
  });

  it('dopisane linie i zniknięcie zespołu widać po odświeżeniu', () => {
    const { dir, s } = store();
    appendFileSync(
      projectFile(dir, ALPHA),
      `${JSON.stringify({ type: 'user', teamName: TEAM, agentName: 'alpha', timestamp: '2026-01-01T10:00:30.000Z', message: { content: [{ type: 'tool_result', tool_use_id: 'toolu_A2', content: 'ok' }] } })}\n`,
    );
    rmSync(join(dir, 'teams', TEAM), { recursive: true });
    s.refresh();
    const alpha = s.view().rows.find((r) => r.name === 'alpha');
    expect(alpha?.status).toBe('zamknięty');
    expect(alpha?.action).toBe('');
  });
});
