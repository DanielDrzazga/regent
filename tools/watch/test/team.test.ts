import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { parseTeamConfig, teamNameFor } from '../src/parse/team.js';
import { FIXTURES, LEAD, TEAM } from './helpers.js';

describe('team config', () => {
  it('nazwa zespołu to session- + 8 znaków ID leada', () => {
    expect(teamNameFor(LEAD)).toBe(TEAM);
  });

  it('czyta członków z fixture’a', () => {
    const cfg = parseTeamConfig(readFileSync(join(FIXTURES, 'teams', TEAM, 'config.json'), 'utf8'));
    expect(cfg?.name).toBe(TEAM);
    expect(cfg?.leadSessionId).toBe(LEAD);
    expect(cfg?.members.map((m) => m.name)).toEqual(['team-lead', 'alpha']);
    expect(cfg?.members[1]).toMatchObject({ color: 'blue', tmuxPaneId: '%1', isActive: true, backendType: 'tmux' });
  });

  it('odrzuca uszkodzony plik i pomija członków bez nazwy', () => {
    expect(parseTeamConfig('{')).toBeUndefined();
    expect(parseTeamConfig('{"members": []}')).toBeUndefined();
    expect(parseTeamConfig('{"name": "t", "members": [{"x": 1}, {"name": "a", "extra": true}]}')?.members).toEqual([{ name: 'a' }]);
  });
});
