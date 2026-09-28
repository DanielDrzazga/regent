import { describe, expect, it } from 'vitest';
import { findLeadTranscript, findSubagents, findTeammates, projectKey, readHead, toLeadTranscript } from '../src/session.js';
import { ALPHA, BETA, CWD, LEAD, OTHER, TEAM, claudeDirCopy, projectFile } from './helpers.js';

describe('odnajdywanie sesji', () => {
  const dir = claudeDirCopy();

  it('klucz projektu jak w Claude Code', () => {
    expect(projectKey('/Users/x/_Private/regent')).toBe('-Users-x--Private-regent');
    expect(projectKey(CWD)).toBe('-tmp-demo');
  });

  it('najnowszy transkrypt należy do członka zespołu → wybiera leada', () => {
    expect(findLeadTranscript({ claudeDir: dir, cwd: CWD })).toBe(projectFile(dir, LEAD));
  });

  it('--session: pełne ID, prefiks, nazwa zespołu, ID członka', () => {
    for (const session of [LEAD, '1111', TEAM, ALPHA]) {
      expect(findLeadTranscript({ claudeDir: dir, cwd: '/gdzie/indziej', session })).toBe(projectFile(dir, LEAD));
    }
    expect(findLeadTranscript({ claudeDir: dir, cwd: CWD, session: OTHER })).toBe(projectFile(dir, OTHER));
    expect(findLeadTranscript({ claudeDir: dir, cwd: CWD, session: 'ffff' })).toBeUndefined();
  });

  it('brak katalogu projektu → undefined', () => {
    expect(findLeadTranscript({ claudeDir: dir, cwd: '/brak' })).toBeUndefined();
  });

  it('tożsamość z początku pliku', () => {
    expect(readHead(projectFile(dir, ALPHA))).toEqual({ sessionId: ALPHA, agentName: 'alpha', teamName: TEAM, conversational: true });
    expect(toLeadTranscript(projectFile(dir, OTHER))).toBe(projectFile(dir, OTHER));
  });

  it('członkowie zespołu po teamName, bez obcych sesji', () => {
    const found = findTeammates([`${dir}/projects/-tmp-demo`], TEAM, 0, new Set([projectFile(dir, LEAD)]));
    expect(found.sort()).toEqual([projectFile(dir, ALPHA), projectFile(dir, BETA)].sort());
    expect(findTeammates([`${dir}/projects/-tmp-demo`], TEAM, Date.now() + 60_000, new Set())).toEqual([]);
  });

  it('subagenci z meta', () => {
    const subs = findSubagents(projectFile(dir, LEAD));
    expect(subs).toHaveLength(1);
    expect(subs[0]).toMatchObject({ agentType: 'Explore', description: 'Znajdź konfigurację' });
    expect(findSubagents(projectFile(dir, ALPHA))).toEqual([]);
  });
});

describe('findTeammates — pamięć odrzuconych', () => {
  it('obcą sesję z rekordami rozmowy odrzuca raz na zawsze', () => {
    const dir = claudeDirCopy();
    const rejected = new Set<string>();
    findTeammates([`${dir}/projects/-tmp-demo`], TEAM, 0, new Set([projectFile(dir, LEAD)]), rejected);
    expect([...rejected]).toEqual([projectFile(dir, OTHER)]);
  });
});
