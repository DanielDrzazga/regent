// regent-watch — logika polecenia; punkt wejścia to cli.ts (ustawia tryb produkcyjny Reacta).

import { parseArgs } from 'node:util';
import { render } from 'ink';
import { defaultClaudeDir, findLeadTranscript } from './session.js';
import { App } from './ui/App.js';
import { Workspace } from './workspace.js';

const HELP = `regent-watch — agenci Claude Code na żywo w stylu mission control: sesje z całej maszyny,
bieżąca akcja, kontekst, oś czasu, graf, tokeny i koszt, zdrowie, blokady i błędy.

Użycie:
  regent-watch                  aktywne sesje z całej maszyny; na starcie wybrana najnowsza
                                sesja projektu z bieżącego katalogu
  regent-watch --session <id>   na starcie wybrana ta sesja (pełne ID, prefiks albo session-<8 znaków>)

Opcje:
  -s, --session <id>    sesja wybrana na starcie
  -a, --active <min>    okno aktywności w minutach (domyślnie 60): sesja z nowszą zmianą
                        transkryptu albo z żywym zespołem jest na liście
  -h, --help            ta pomoc

W widoku: ? — klawisze. Czyta transkrypty z ~/.claude/projects/ i stan zespołów z ~/.claude/teams/
(CLAUDE_CONFIG_DIR zmienia katalog). Niczego nie zapisuje ani nie wysyła; klawisz t zmienia
tylko fokus tmux. Koszt ≈ to szacunek z cennika API; po zamknięciu sesji widok pokazuje też
koszt policzony przez Claude Code.`;

function main(): number {
  let values: { session?: string | undefined; active?: string | undefined; help?: boolean | undefined };
  try {
    ({ values } = parseArgs({
      options: {
        session: { type: 'string', short: 's' },
        active: { type: 'string', short: 'a' },
        help: { type: 'boolean', short: 'h' },
      },
      strict: true,
    }));
  } catch (e) {
    console.error(`regent-watch: ${(e as Error).message}\n\n${HELP}`);
    return 2;
  }
  if (values.help) {
    console.log(HELP);
    return 0;
  }
  const minutes = values.active === undefined ? 60 : Number(values.active);
  if (!Number.isFinite(minutes) || minutes <= 0) {
    console.error(`regent-watch: --active wymaga liczby minut > 0, podano: ${values.active}`);
    return 2;
  }

  const claudeDir = defaultClaudeDir();
  const cwd = process.cwd();
  const pinned = findLeadTranscript({ claudeDir, cwd, ...(values.session ? { session: values.session } : {}) });
  if (values.session && !pinned) {
    console.error(`regent-watch: nie znaleziono sesji ${values.session} w ${claudeDir}/projects`);
    return 2;
  }

  const workspace = new Workspace({ claudeDir, activeMs: minutes * 60_000, ...(pinned ? { pinned } : {}) });
  render(<App source={workspace} interactive={Boolean(process.stdin.isTTY)} />, {
    alternateScreen: true,
    // Animacja pracy przerysowuje ekran kilka razy na sekundę — tylko zmienione linie i limit klatek.
    incrementalRendering: true,
    maxFps: 8,
  });
  return 0;
}

export function run(): void {
  const code = main();
  if (code !== 0) process.exitCode = code;
}
