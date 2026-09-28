import { rmSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { Workspace, projectLabel } from '../src/workspace.js';
import { LEAD, OTHER, TEAM, claudeDirCopy, projectFile } from './helpers.js';

const SOLO = '55555555-aaaa-4bbb-8ccc-000000000005';
const soloFile = (dir: string) => join(dir, 'projects', '-tmp-inny', `${SOLO}.jsonl`);
const ids = (ws: Workspace) => ws.sessions().map((e) => e.leadFile);

describe('Workspace — sesje z całej maszyny', () => {
  it('aktywne sesje ze wszystkich projektów, bez transkryptów członków zespołu', () => {
    const dir = claudeDirCopy();
    const ws = new Workspace({ claudeDir: dir, activeMs: 60 * 60_000, discoveryMs: 0 });
    ws.refresh();
    expect(ids(ws).sort()).toEqual([projectFile(dir, LEAD), projectFile(dir, OTHER), soloFile(dir)].sort());
    const lead = ws.sessions().find((e) => e.leadFile === projectFile(dir, LEAD));
    expect(lead?.store.sources().map((a) => a.name)).toEqual(['lead', 'alpha', 'beta', 'lead›Explore']);
  });

  it('żywy zespół trzyma sesję mimo starego transkryptu; stare sesje wypadają', () => {
    const dir = claudeDirCopy(); // demo ma mtime sprzed ~10 min
    const ws = new Workspace({ claudeDir: dir, activeMs: 5 * 60_000, discoveryMs: 0 });
    ws.refresh();
    expect(ids(ws).sort()).toEqual([projectFile(dir, LEAD), soloFile(dir)].sort());
    rmSync(join(dir, 'teams', TEAM), { recursive: true });
    ws.refresh(Date.now() + 10_000);
    expect(ids(ws)).toEqual([soloFile(dir)]);
  });

  it('sesja wybrana na starcie zostaje i jest pierwsza', () => {
    const dir = claudeDirCopy();
    const ws = new Workspace({ claudeDir: dir, activeMs: 60_000, pinned: projectFile(dir, OTHER), discoveryMs: 0 });
    ws.refresh();
    expect(ids(ws)[0]).toBe(projectFile(dir, OTHER));
    expect(ws.sessions()[0]?.pinned).toBe(true);
  });

  it('etykieta projektu z cwd sesji', () => {
    const dir = claudeDirCopy();
    const ws = new Workspace({ claudeDir: dir, activeMs: 60 * 60_000, discoveryMs: 0 });
    ws.refresh();
    const solo = ws.sessions().find((e) => e.leadFile === soloFile(dir));
    expect(solo && projectLabel(solo)).toEqual({ name: 'inny', path: '/tmp/inny' });
  });
});
