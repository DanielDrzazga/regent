import { render } from 'ink-testing-library';
import { describe, expect, it } from 'vitest';
import { SessionStore } from '../src/store.js';
import { App } from '../src/ui/App.js';
import { fit, fmtDuration, fmtTokens, inkColor } from '../src/ui/format.js';
import { LEAD, claudeDirCopy, projectFile } from './helpers.js';

describe('format', () => {
  it('liczby, czas, kolumny', () => {
    expect([fmtTokens(950), fmtTokens(12_400), fmtTokens(1_160_000)]).toEqual(['950', '12k', '1.1M']);
    expect([fmtDuration(4_200), fmtDuration(185_000), fmtDuration(3_900_000)]).toEqual(['4 s', '3 min', '1 h 5 min']);
    expect(fit('abcdef', 4)).toBe('abc…');
    expect(fit('ab', 4, 'right')).toBe('  ab');
    expect([inkColor('purple'), inkColor('blue'), inkColor('chartreuse')]).toEqual(['magenta', 'blue', undefined]);
  });
});

describe('App', () => {
  it('renderuje agentów, oś czasu i blokady', () => {
    const dir = claudeDirCopy();
    const source = new SessionStore({ claudeDir: dir, leadFile: projectFile(dir, LEAD), discoveryMs: 0 });
    const now = Date.parse('2026-01-01T10:00:39.000Z');
    const { lastFrame, unmount } = render(<App source={source} title="sesja 11111111" interactive={false} now={now} intervalMs={60_000} />);
    const frame = lastFrame() ?? '';
    unmount();
    expect(frame).toContain('regent-watch');
    expect(frame).toMatch(/alpha\s+haiku-4-5\s+pracuje\s+30 s/);
    expect(frame).toContain('Bash Uruchom testy');
    expect(frame).toMatch(/beta\s+haiku-4-5\s+zamknięty/);
    expect(frame).toContain('lead›Explore');
    expect(frame).toContain('Oś czasu');
    expect(frame).toContain('blokada hooka git-guard.sh');
    expect(frame).toContain('błąd narzędzia');
    expect(frame).toMatch(/RAZEM\s+\S+\s+≈\$0\.\d\d/);
  });
});
