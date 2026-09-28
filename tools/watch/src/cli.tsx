#!/usr/bin/env node
// regent-watch — podgląd pracy agentów Claude Code w terminalu (tylko odczyt).

import { basename } from 'node:path';
import { parseArgs } from 'node:util';
import { render } from 'ink';
import { findLeadTranscript, defaultClaudeDir, sessionIdOf } from './session.js';
import { SessionStore } from './store.js';
import { App } from './ui/App.js';

const HELP = `regent-watch — agenci Claude Code na żywo: bieżąca akcja, oś czasu, tokeny i koszt, blokady i błędy.

Użycie:
  regent-watch                  najnowsza sesja projektu z bieżącego katalogu
  regent-watch --session <id>   sesja o tym ID (pełne, prefiks albo session-<8 znaków>)

Opcje:
  -s, --session <id>   wybór sesji
  -h, --help           ta pomoc

Czyta transkrypty z ~/.claude/projects/ i stan zespołu z ~/.claude/teams/ (CLAUDE_CONFIG_DIR
zmienia katalog). Niczego nie zapisuje ani nie wysyła. Koszt ≈ to szacunek z cennika API;
po zamknięciu sesji widok pokazuje też koszt policzony przez Claude Code.`;

function main(): number {
  let values: { session?: string | undefined; help?: boolean | undefined };
  try {
    ({ values } = parseArgs({
      options: { session: { type: 'string', short: 's' }, help: { type: 'boolean', short: 'h' } },
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

  const claudeDir = defaultClaudeDir();
  const cwd = process.cwd();
  const leadFile = findLeadTranscript({ claudeDir, cwd, ...(values.session ? { session: values.session } : {}) });
  if (!leadFile) {
    console.error(
      values.session
        ? `regent-watch: nie znaleziono sesji ${values.session} w ${claudeDir}/projects`
        : `regent-watch: brak transkryptów dla ${cwd} — uruchom claude w tym katalogu albo podaj --session`,
    );
    return 2;
  }

  const store = new SessionStore({ claudeDir, leadFile });
  store.refresh();
  const leadCwd = store.sources().find((a) => a.kind === 'lead')?.state.cwd;
  const title = `sesja ${sessionIdOf(leadFile).slice(0, 8)}${leadCwd ? ` · ${basename(leadCwd)}` : ''}`;
  render(<App source={store} title={title} interactive={Boolean(process.stdin.isTTY)} />, {
    alternateScreen: true,
  });
  return 0;
}

const code = main();
if (code !== 0) process.exitCode = code;
