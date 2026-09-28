import { render } from 'ink-testing-library';
import { describe, expect, it } from 'vitest';
import { App } from '../src/ui/App.js';
import { fitLine, plain, seg, viewport } from '../src/ui/lines.js';
import { inkColor, meter } from '../src/ui/style.js';
import { fmtDuration, fmtTokens } from '../src/units.js';
import { Workspace } from '../src/workspace.js';
import { LEAD, claudeDirCopy, projectFile } from './helpers.js';

const NOW = Date.parse('2026-01-01T10:00:39.000Z');
const tick = () => new Promise((r) => setTimeout(r, 30));
const KEY = { down: '\u001B[B', up: '\u001B[A', left: '\u001B[D', right: '\u001B[C', esc: '\u001B', enter: '\r', tab: '\t' };

function mount(opts: { tmuxRun?: (args: string[]) => string; inTmux?: boolean } = {}) {
  const dir = claudeDirCopy();
  // Okno aktywności obejmuje fixture'y z 2026-01-01 tylko przy dużym --active — tu wystarczy pinned + skan.
  const ws = new Workspace({ claudeDir: dir, activeMs: Number.MAX_SAFE_INTEGER, pinned: projectFile(dir, LEAD), discoveryMs: 0 });
  const calls: string[][] = [];
  const run = opts.tmuxRun ?? ((args: string[]) => (calls.push(args), ''));
  const app = render(
    <App source={ws} now={NOW} frame={0} size={{ columns: 100, rows: 40 }} tmux={{ inTmux: opts.inTmux ?? true, run, selfPane: '%9' }} />,
  );
  return { ...app, calls };
}

describe('format i linie', () => {
  it('jednostki, przycinanie, pasek, kolory', () => {
    expect([fmtTokens(950), fmtTokens(12_400), fmtTokens(1_160_000)]).toEqual(['950', '12k', '1.1M']);
    expect([fmtDuration(4_200), fmtDuration(185_000), fmtDuration(3_900_000)]).toEqual(['4 s', '3 min', '1 h 5 min']);
    expect(plain(fitLine([seg('abc'), seg('def')], 5))).toBe('abcd…');
    expect(plain(meter({ context: 100_000, contextWindow: 200_000 }))).toBe('▪▪▪▫▫');
    expect([inkColor('purple'), inkColor('blue'), inkColor('chartreuse')]).toEqual(['magenta', 'blue', undefined]);
    const lines = [1, 2, 3, 4, 5].map((n) => [seg(String(n))]);
    expect(viewport(lines, 2, 0, 'bottom').map(plain)).toEqual(['4', '5']);
    expect(viewport(lines, 2, 1, 'bottom').map(plain)).toEqual(['3', '4']);
    expect(viewport(lines, 2, 9, 'top').map(plain)).toEqual(['4', '5']);
  });
});

describe('App — mission control', () => {
  it('drzewo sesji z agentami, tabela, podsumowanie w stopce', () => {
    const { lastFrame, unmount } = mount();
    const f = lastFrame() ?? '';
    unmount();
    expect(f).toContain('SESJE');
    expect(f).toMatch(/demo\s+2/); // projekt z dwiema sesjami
    expect(f).toContain('▾ ⠋ sesja 11111111'); // animacja: alpha pracuje
    expect(f).toMatch(/├ ⠋ alpha\s+\d+%/);
    expect(f).toMatch(/└ ○ Explore/);
    expect(f).toContain('[ Tabela ]');
    expect(f).toMatch(/alpha\s+\d+% ▫▫▫▫▫ ⠋ pracuje\s+30 s/);
    expect(f).toContain('Bash Uruchom testy');
    expect(f).toContain('UWAGA (1)');
    expect(f).toContain('▲ lead inny · ponowieni'); // ucięte na szerokości drzewa
    expect(f).toMatch(/3 sesji · 6 agentów · 2 pracuje/);
  });

  it('zakładki 2–5: oś czasu, graf, przegląd, zdrowie; ? — pomoc', async () => {
    const { lastFrame, stdin, unmount } = mount();
    const frames: Record<string, string> = {};
    for (const k of ['2', '3', '4', '5', '?']) {
      stdin.write(k);
      await tick();
      frames[k] = lastFrame() ?? '';
      if (k === '?') stdin.write(KEY.esc);
    }
    unmount();
    expect(frames['2']).toContain('[ Oś czasu ]');
    expect(frames['2']).toContain('+ alpha (haiku)');
    expect(frames['2']).toContain('⊘ Bash: SDD git-guard');
    expect(frames['3']).toContain('[ Graf ]');
    expect(frames['3']).toMatch(/╭─+╮/);
    expect(frames['3']).toContain('✉1↓1↑');
    expect(frames['3']).toContain('alpha → beta');
    expect(frames['4']).toContain('NARZĘDZIA');
    expect(frames['4']).toMatch(/SendMessage\s+3/);
    expect(frames['5']).toContain('ZDROWIE AGENTÓW');
    expect(frames['?']).toContain('KLAWISZE');
  });

  it('strzałki: wybór agenta → szczegóły; Esc — z powrotem do sesji', async () => {
    const { lastFrame, stdin, unmount } = mount();
    stdin.write(KEY.down); // lead
    await tick();
    stdin.write(KEY.down); // alpha
    await tick();
    const detail = lastFrame() ?? '';
    stdin.write(KEY.esc);
    await tick();
    const back = lastFrame() ?? '';
    unmount();
    expect(detail).toContain('agent alpha · pracuje');
    expect(detail).toContain('KONTEKST');
    expect(detail).toMatch(/panel:\s+%1/);
    expect(detail).toContain('BLOKADY I BŁĘDY · 1');
    expect(back).toContain('[ Tabela ]');
  });

  it('t — skok do panelu członka zespołu przez tmux', async () => {
    const { lastFrame, stdin, unmount, calls } = mount();
    stdin.write(KEY.down);
    await tick();
    stdin.write(KEY.down);
    await tick();
    stdin.write('t');
    await tick();
    const f = lastFrame() ?? '';
    unmount();
    expect(calls).toEqual([
      ['select-window', '-t', '%1'],
      ['select-pane', '-t', '%1'],
    ]);
    expect(f).toContain('tmux: panel %1');
  });

  it('t poza tmux — komunikat zamiast skoku', async () => {
    const { lastFrame, stdin, unmount, calls } = mount({ inTmux: false });
    stdin.write('t');
    await tick();
    const f = lastFrame() ?? '';
    unmount();
    expect(calls).toEqual([]);
    expect(f).toContain('widok nie działa w tmux');
  });

  it('/ — filtr drzewa po nazwie agenta', async () => {
    const { lastFrame, stdin, unmount } = mount();
    stdin.write('/');
    await tick();
    for (const ch of 'bet') {
      stdin.write(ch);
      await tick();
    }
    const f = lastFrame() ?? '';
    unmount();
    expect(f).toContain('/bet');
    expect(f).toMatch(/beta\s+\d+%/);
    expect(f).not.toMatch(/├ ⠋ alpha/);
    expect(f).not.toContain('sesja 55555555'); // sekcja Uwaga zostaje bez filtra
  });
});
