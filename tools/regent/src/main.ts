// regent — logika polecenia; punkt wejścia to cli.ts. Wejście i wyjście przez Io, żeby testy
// wołały main w procesie, z własnym zegarem i środowiskiem.

import { existsSync } from 'node:fs';
import { parseArgs, type ParseArgsOptionsConfig } from 'node:util';
import { attentionJson, findMismatch, findMissing, hasSdd, type Attention } from './attention.js';
import type { Db } from './db.js';
import { defaultDbPath } from './db.js';
import { renderList, renderShow, renderSync, taskLine } from './format.js';
import { STATE_LABEL, TransitionError, UsageError, isOwner, type Owner, type State } from './model.js';
import { projectRoot } from './project.js';
import { openTaskDb } from './schema.js';
import { DEFAULT_STUCK_MIN, findStuck } from './stuck.js';
import { syncProject } from './sync.js';
import { TaskStore, type Ctx, type Task } from './tasks.js';

export interface Io {
  argv: string[];
  env: NodeJS.ProcessEnv;
  cwd: string;
  /** Zegar wstrzykiwany: logika nie woła Date.now(). */
  now: () => number;
  out: (text: string) => void;
  err: (text: string) => void;
}

const HELP = `regent — zadania, właściciele i log przejść (jedna baza na maszynę).

Użycie:
  regent task <polecenie>   zadania projektu z bieżącego katalogu (korzeń gita)
  regent --help             ta pomoc

Szczegóły: regent task --help`;

const TASK_HELP = `regent task — zadania projektu (korzeń gita bieżącego katalogu).

Polecenia:
  regent task add <tytuł> [--owner me|agent]     nowe zadanie, oczekuje
  regent task take <id>                          biorę: w toku, właścicielem zostaje biorący
  regent task handoff <id> <me|agent> [--reason <powód>]
                                                 przekazanie: do me — czeka na Ciebie,
                                                 do agenta — przekazane, aż je weźmie
  regent task done <id> --reason <powód>         zakończone
  regent task drop <id> --reason <powód>         porzucone
  regent task list [--all] [--stuck <min>]       otwarte zadania; --all także zamknięte.
                                                 Uwaga: w toku, a transkrypt sesji stoi od
                                                 progu (domyślnie ${DEFAULT_STUCK_MIN} min) albo bez
                                                 sesji dłużej niż próg od wzięcia; zmiany
                                                 SDD bez artefaktów albo w rozjeździe z nimi
  regent task show <id>                          zadanie i historia przejść
  regent task sync [--session-id <id> --transcript-path <plik>] [--source <źródło>]
                                                 zmiany SDD z ai/changes/ jako zadania: stan
                                                 z artefaktów (sdd-check.sh status, archiwum),
                                                 po Approved taski z tasks.md — zmieniona linia
                                                 wygrywa z bazą; sesja dopina transkrypt

Opcje: --json — wynik jako JSON; -h, --help — ta pomoc.
Wykonawca: w sesji Claude Code (CLAUDECODE) agent, poza nią me.
Baza: REGENT_DB albo \${XDG_STATE_HOME:-~/.local/state}/regent/regent.db.
Kody wyjścia: 0 — ok, 1 — odrzucone przejście, 2 — błędne użycie, 4 — błąd bazy.`;

type Values = Record<string, string | boolean | undefined>;

interface Call {
  io: Io;
  values: Values;
  positionals: string[];
  project: string;
  ctx: Ctx;
  /** Wykonawca jako właściciel: tak bierze zadanie i zakłada je domyślnie. */
  self: Owner;
  dbPath: string;
  /** Otwiera bazę (zakłada ją, gdy nie istnieje). */
  store: () => TaskStore;
  print: (task: Task) => void;
}

interface Command {
  options: ParseArgsOptionsConfig;
  run: (call: Call) => number;
}

const JSON_OPT: ParseArgsOptionsConfig = { json: { type: 'boolean' } };
const REASON_OPT: ParseArgsOptionsConfig = { reason: { type: 'string' } };

/** Polecenie, które prowadzi do stanu — do listy możliwych przy odrzuconym przejściu. */
const COMMAND_TO: Partial<Record<State, string>> = {
  in_progress: 'take',
  waiting: 'handoff me',
  handed_off: 'handoff agent',
  done: 'done',
  dropped: 'drop',
};

function taskId(positionals: string[]): number {
  if (positionals.length !== 1) throw new UsageError(positionals.length ? 'podaj jedno id zadania' : 'brak id zadania');
  const match = /^#?(\d+)$/.exec(positionals[0]!);
  if (!match) throw new UsageError(`nieprawidłowe id zadania: ${positionals[0]}`);
  return Number(match[1]);
}

function owner(value: string | undefined): Owner {
  if (value === undefined || !isOwner(value)) throw new UsageError(`nieznany właściciel: ${value} (me albo agent)`);
  return value;
}

function stuckMinutes(value: string | boolean | undefined): number {
  if (value === undefined) return DEFAULT_STUCK_MIN;
  const minutes = Number(value);
  if (!Number.isFinite(minutes) || minutes <= 0) throw new UsageError(`--stuck wymaga liczby minut > 0, podano: ${value}`);
  return minutes;
}

const text = (value: string | boolean | undefined): string | undefined =>
  typeof value === 'string' && value.trim() ? value.trim() : undefined;

function reason(call: Call, command: string): string {
  const text = typeof call.values.reason === 'string' ? call.values.reason.trim() : '';
  if (!text) throw new UsageError(`${command} wymaga --reason <powód>`);
  return text;
}

/** Odrzucone przejście opisane poleceniem, które je wywołało, i poleceniami, które są możliwe. */
function attempt<T>(command: string, fn: () => T): T {
  try {
    return fn();
  } catch (e) {
    if (e instanceof TransitionError) {
      const possible = e.allowed.flatMap((s) => (COMMAND_TO[s] ? [`${COMMAND_TO[s]} (${STATE_LABEL[s]})`] : []));
      const list = possible.length ? possible.join(', ') : 'nic — stan końcowy';
      throw new TransitionError(e.taskId, e.from, e.to, `#${e.taskId} jest „${STATE_LABEL[e.from]}” — ${command} niedozwolone. Możliwe: ${list}.`);
    }
    throw e;
  }
}

const COMMANDS: Record<string, Command> = {
  add: {
    options: { ...JSON_OPT, owner: { type: 'string' } },
    run: (c) => {
      const title = c.positionals.join(' ').trim();
      if (!title) throw new UsageError('add wymaga tytułu');
      const who = c.values.owner === undefined ? c.self : owner(c.values.owner as string);
      c.print(c.store().add({ project: c.project, title, owner: who }, c.ctx));
      return 0;
    },
  },
  take: {
    options: JSON_OPT,
    run: (c) => {
      const id = taskId(c.positionals);
      const sessionId = c.io.env.CLAUDE_CODE_SESSION_ID;
      c.print(attempt('take', () => c.store().take(id, c.self, c.ctx, sessionId ? { sessionId } : undefined)));
      return 0;
    },
  },
  handoff: {
    options: { ...JSON_OPT, ...REASON_OPT },
    run: (c) => {
      if (c.positionals.length !== 2) throw new UsageError('handoff wymaga id i właściciela: handoff <id> <me|agent>');
      const id = taskId(c.positionals.slice(0, 1));
      const to = owner(c.positionals[1]);
      const why = typeof c.values.reason === 'string' ? c.values.reason : undefined;
      c.print(attempt(`handoff ${to}`, () => c.store().handoff(id, to, c.ctx, why)));
      return 0;
    },
  },
  done: {
    options: { ...JSON_OPT, ...REASON_OPT },
    run: (c) => {
      const id = taskId(c.positionals);
      const why = reason(c, 'done');
      c.print(attempt('done', () => c.store().done(id, why, c.ctx)));
      return 0;
    },
  },
  drop: {
    options: { ...JSON_OPT, ...REASON_OPT },
    run: (c) => {
      const id = taskId(c.positionals);
      const why = reason(c, 'drop');
      c.print(attempt('drop', () => c.store().drop(id, why, c.ctx)));
      return 0;
    },
  },
  list: {
    options: { ...JSON_OPT, all: { type: 'boolean' }, stuck: { type: 'string' } },
    run: (c) => {
      if (c.positionals.length) throw new UsageError(`list nie przyjmuje argumentów: ${c.positionals.join(' ')}`);
      const all = Boolean(c.values.all);
      const thresholdMs = stuckMinutes(c.values.stuck) * 60_000;
      const sdd = hasSdd(c.project);
      if (!existsSync(c.dbPath)) {
        const none: Attention = { stuck: [], missing: [], mismatch: [], sdd, lastSync: null };
        c.io.out(
          c.values.json
            ? JSON.stringify({ project: c.project, db: null, tasks: [], attention: attentionJson(none) }, null, 2)
            : `Brak bazy zadań (${c.dbPath}) — nic jeszcze nie zapisano.`,
        );
        return 0;
      }
      const store = c.store();
      const tasks = store.list(c.project, { all });
      const attention: Attention = {
        stuck: findStuck(tasks, { now: c.io.now(), thresholdMs }),
        missing: sdd ? findMissing(c.project, tasks) : [],
        mismatch: findMismatch(tasks),
        sdd,
        lastSync: store.lastSync(c.project) ?? null,
      };
      c.io.out(
        c.values.json
          ? JSON.stringify({ project: c.project, db: c.dbPath, tasks, attention: attentionJson(attention) }, null, 2)
          : renderList(c.project, tasks, all, attention),
      );
      return 0;
    },
  },
  show: {
    options: JSON_OPT,
    run: (c) => {
      const id = taskId(c.positionals);
      if (!existsSync(c.dbPath)) throw new UsageError(`nie ma zadania #${id} (brak bazy ${c.dbPath})`);
      const store = c.store();
      const task = store.mustGet(id);
      const history = store.history(id);
      const parent = task.parentId === null ? undefined : store.get(task.parentId);
      c.io.out(c.values.json ? JSON.stringify({ task, history }, null, 2) : renderShow(task, history, parent));
      return 0;
    },
  },
  sync: {
    options: { ...JSON_OPT, 'session-id': { type: 'string' }, 'transcript-path': { type: 'string' }, source: { type: 'string' } },
    run: (c) => {
      if (c.positionals.length) throw new UsageError(`sync nie przyjmuje argumentów: ${c.positionals.join(' ')}`);
      const sessionId = text(c.values['session-id']);
      const transcriptPath = text(c.values['transcript-path']);
      if (transcriptPath && !sessionId) throw new UsageError('--transcript-path wymaga --session-id');
      const report = syncProject(c.store(), c.project, {
        ctx: { actor: 'sync', source: text(c.values.source) ?? 'cli' },
        ...(sessionId ? { session: { id: sessionId, transcriptPath } } : {}),
      });
      c.io.out(c.values.json ? JSON.stringify(report, null, 2) : renderSync(report));
      return 0;
    },
  },
};

function usage(io: Io, message: string, help: string): number {
  io.err(`regent: ${message}\n\n${help}`);
  return 2;
}

export function main(io: Io): number {
  const [group, command, ...rest] = io.argv;
  if (group === '--help' || group === '-h') {
    io.out(HELP);
    return 0;
  }
  if (group === undefined) return usage(io, 'brak polecenia', HELP);
  if (group !== 'task') return usage(io, `nieznane polecenie: ${group}`, HELP);
  if (command === '--help' || command === '-h') {
    io.out(TASK_HELP);
    return 0;
  }
  const spec = command === undefined ? undefined : COMMANDS[command];
  if (!spec) return usage(io, command === undefined ? 'brak polecenia task' : `nieznane polecenie: task ${command}`, TASK_HELP);

  let db: Db | undefined;
  try {
    const parsed = parseArgs({
      args: rest,
      options: { ...spec.options, help: { type: 'boolean', short: 'h' } },
      allowPositionals: true,
      strict: true,
    });
    const values = parsed.values as Values;
    const positionals = parsed.positionals;
    if (values.help) {
      io.out(TASK_HELP);
      return 0;
    }
    const self: Owner = io.env.CLAUDECODE ? 'agent' : 'me';
    const dbPath = defaultDbPath(io.env);
    let store: TaskStore | undefined;
    return spec.run({
      io,
      values,
      positionals,
      project: projectRoot(io.cwd),
      ctx: { actor: self, source: 'cli' },
      self,
      dbPath,
      store: () => (store ??= new TaskStore((db = openTaskDb(dbPath)), io.now)),
      print: (task) => io.out(values.json ? JSON.stringify(task, null, 2) : taskLine(task)),
    });
  } catch (e) {
    if (e instanceof TransitionError) {
      io.err(`regent: ${e.message}`);
      return 1;
    }
    if (e instanceof UsageError || (e as { code?: string }).code?.startsWith('ERR_PARSE_ARGS')) {
      io.err(`regent: ${(e as Error).message}\nPomoc: regent task --help`);
      return 2;
    }
    io.err(`regent: błąd: ${(e as Error).message}`);
    return 4;
  } finally {
    db?.close();
  }
}
