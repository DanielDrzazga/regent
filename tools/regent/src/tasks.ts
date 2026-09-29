// TaskStore — jedyny moduł, który zmienia stan zadań. Każda zmiana to UPDATE zadania i INSERT do logu
// przejść w jednej transakcji; CLI, hooki, skille i później TUI zmieniają stan tylko przez niego.

import type { Db, Param } from './db.js';
import {
  CLOSED,
  KINDS,
  STATE_LABEL,
  TransitionError,
  UsageError,
  canTransition,
  handoffState,
  isOwner,
  isReopen,
  requiresReason,
  type Kind,
  type Owner,
  type State,
} from './model.js';

/** Zegar w milisekundach epoki — wstrzykiwany, żeby testy podmieniały czas. */
export type Clock = () => number;

/** Kto i skąd zmienia stan: trafia do każdego wpisu w logu przejść. */
export interface Ctx {
  actor: string;
  source: string;
}

export interface Session {
  sessionId?: string | null;
  transcriptPath?: string | null;
}

export interface Task {
  id: number;
  project: string;
  parentId: number | null;
  key: string | null;
  kind: Kind;
  tag: string | null;
  title: string;
  owner: Owner;
  state: State;
  refs: Record<string, unknown>;
  closureReason: string | null;
  sessionId: string | null;
  transcriptPath: string | null;
  fileSig: string | null;
  claimedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Transition {
  id: number;
  taskId: number;
  at: string;
  state: State;
  owner: string;
  actor: string;
  source: string;
  reason: string | null;
}

export interface NewTask {
  project: string;
  title: string;
  owner: Owner;
  kind?: Kind;
  parentId?: number;
  key?: string;
  tag?: string;
  refs?: Record<string, unknown>;
  /** Stan początkowy (domyślnie „oczekuje”) — sync zakłada np. szkic zmiany od razu jako „czeka na Ciebie”. */
  state?: State;
  reason?: string;
  fileSig?: string;
}

/** Treść z plików (tytuł, tag, refs, sygnatura) — zmienia ją sync, bez wpisu w logu przejść. */
export interface Revision {
  title?: string;
  tag?: string | null;
  refs?: Record<string, unknown>;
  fileSig?: string | null;
}

export interface SyncMark {
  at: string;
  source: string;
}

export interface TransitionOptions extends Ctx {
  owner?: Owner;
  reason?: string | null;
  /** Sesja nowego wzięcia; przy wejściu w „w toku” bez niej sesja jest zerowana. */
  session?: Session;
}

interface TaskRow {
  id: number;
  project: string;
  parent_id: number | null;
  key: string | null;
  kind: Kind;
  tag: string | null;
  title: string;
  owner: Owner;
  state: State;
  refs: string;
  closure_reason: string | null;
  session_id: string | null;
  transcript_path: string | null;
  file_sig: string | null;
  claimed_at: string | null;
  created_at: string;
  updated_at: string;
}

interface TransitionRow {
  id: number;
  task_id: number;
  at: string;
  state: State;
  owner: string;
  actor: string;
  source: string;
  reason: string | null;
}

const toTask = (r: TaskRow): Task => ({
  id: r.id,
  project: r.project,
  parentId: r.parent_id,
  key: r.key,
  kind: r.kind,
  tag: r.tag,
  title: r.title,
  owner: r.owner,
  state: r.state,
  refs: JSON.parse(r.refs) as Record<string, unknown>,
  closureReason: r.closure_reason,
  sessionId: r.session_id,
  transcriptPath: r.transcript_path,
  fileSig: r.file_sig,
  claimedAt: r.claimed_at,
  createdAt: r.created_at,
  updatedAt: r.updated_at,
});

const toTransition = (r: TransitionRow): Transition => ({
  id: r.id,
  taskId: r.task_id,
  at: r.at,
  state: r.state,
  owner: r.owner,
  actor: r.actor,
  source: r.source,
  reason: r.reason,
});

const clean = (text: string | null | undefined): string | null => text?.trim() || null;
const reasonMissing = (state: State) => new UsageError(`„${STATE_LABEL[state]}” wymaga powodu (--reason)`);
const CLOSED_SQL = CLOSED.map(() => '?').join(', ');

export class TaskStore {
  private readonly db: Db;
  private readonly clock: Clock;

  constructor(db: Db, clock: Clock) {
    this.db = db;
    this.clock = clock;
  }

  add(input: NewTask, ctx: Ctx): Task {
    const title = input.title.trim();
    if (!title) throw new UsageError('zadanie wymaga tytułu');
    if (!isOwner(input.owner)) throw new UsageError(`nieznany właściciel: ${input.owner} (me albo agent)`);
    const kind = input.kind ?? 'manual';
    const state = input.state ?? 'pending';
    const reason = clean(input.reason);
    if (requiresReason(state) && !reason) throw reasonMissing(state);

    return this.db.transaction(() => {
      this.checkLevel(kind, input);
      const at = this.stamp();
      const { lastInsertRowid: id } = this.db.run(
        `INSERT INTO tasks (project, parent_id, key, kind, tag, title, owner, state, refs, closure_reason, file_sig, claimed_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        input.project,
        input.parentId ?? null,
        input.key ?? null,
        kind,
        input.tag ?? null,
        title,
        input.owner,
        state,
        JSON.stringify(input.refs ?? {}),
        CLOSED.includes(state) ? reason : null,
        input.fileSig ?? null,
        state === 'in_progress' ? at : null,
        at,
        at,
      );
      this.log(id, at, state, input.owner, ctx, reason);
      return this.mustGet(id);
    });
  }

  get(id: number): Task | undefined {
    const row = this.db.get<TaskRow>('SELECT * FROM tasks WHERE id = ?', id);
    return row && toTask(row);
  }

  mustGet(id: number): Task {
    const task = this.get(id);
    if (!task) throw new UsageError(`nie ma zadania #${id}`);
    return task;
  }

  transition(id: number, to: State, opts: TransitionOptions): Task {
    if (opts.owner !== undefined && !isOwner(opts.owner)) throw new UsageError(`nieznany właściciel: ${opts.owner} (me albo agent)`);
    return this.db.transaction(() => {
      const task = this.mustGet(id);
      if (!canTransition(task.state, to)) throw new TransitionError(id, task.state, to);
      const reason = clean(opts.reason);
      if (requiresReason(to) && !reason) throw reasonMissing(to);
      if (isReopen(task.state, to) && !reason) throw new UsageError(`ponowne otwarcie #${id} wymaga powodu`);
      const owner = opts.owner ?? task.owner;
      const at = this.stamp();
      const entering = to === 'in_progress';
      this.db.run(
        `UPDATE tasks SET state = ?, owner = ?, closure_reason = ?, claimed_at = ?, session_id = ?, transcript_path = ?, updated_at = ?
         WHERE id = ?`,
        to,
        owner,
        CLOSED.includes(to) ? reason : null,
        entering ? at : task.claimedAt,
        entering ? (opts.session?.sessionId ?? null) : task.sessionId,
        entering ? (opts.session?.transcriptPath ?? null) : task.transcriptPath,
        at,
        id,
      );
      this.log(id, at, to, owner, opts, reason);
      return this.mustGet(id);
    });
  }

  /** Biorący zostaje właścicielem; czas wzięcia i sesja liczą się do utknięcia. */
  take(id: number, owner: Owner, ctx: Ctx, session?: Session): Task {
    return this.transition(id, 'in_progress', { ...ctx, owner, ...(session ? { session } : {}) });
  }

  handoff(id: number, owner: Owner, ctx: Ctx, reason?: string): Task {
    return this.transition(id, handoffState(owner), { ...ctx, owner, reason: reason ?? null });
  }

  done(id: number, reason: string, ctx: Ctx): Task {
    return this.transition(id, 'done', { ...ctx, reason });
  }

  drop(id: number, reason: string, ctx: Ctx): Task {
    return this.transition(id, 'dropped', { ...ctx, reason });
  }

  /** Zadania projektu: rodzic, pod nim dzieci. Bez `all` tylko otwarte (i rodzice otwartych dzieci). */
  list(project: string, { all }: { all: boolean }): Task[] {
    const filter = all
      ? ''
      : `AND (state NOT IN (${CLOSED_SQL})
              OR id IN (SELECT parent_id FROM tasks WHERE project = ? AND parent_id IS NOT NULL AND state NOT IN (${CLOSED_SQL})))`;
    const params: Param[] = all ? [project] : [project, ...CLOSED, project, ...CLOSED];
    return this.db
      .all<TaskRow>(
        `SELECT * FROM tasks WHERE project = ? ${filter}
         ORDER BY ifnull(parent_id, id), parent_id IS NOT NULL, id`,
        ...params,
      )
      .map(toTask);
  }

  history(id: number): Transition[] {
    return this.db.all<TransitionRow>('SELECT * FROM transitions WHERE task_id = ? ORDER BY id', id).map(toTransition);
  }

  /** Zadanie po kluczu w danym miejscu: zmiana SDD (`sdd:<zmiana>`, bez rodzica) albo task zmiany. */
  findByKey(project: string, parentId: number | null, key: string): Task | undefined {
    const row = this.db.get<TaskRow>(
      'SELECT * FROM tasks WHERE project = ? AND ifnull(parent_id, 0) = ? AND key = ?',
      project,
      parentId ?? 0,
      key,
    );
    return row && toTask(row);
  }

  /** Zmiany SDD projektu — także zamknięte. */
  changes(project: string): Task[] {
    return this.db.all<TaskRow>("SELECT * FROM tasks WHERE project = ? AND kind = 'change' ORDER BY id", project).map(toTask);
  }

  children(parentId: number): Task[] {
    return this.db.all<TaskRow>('SELECT * FROM tasks WHERE parent_id = ? ORDER BY id', parentId).map(toTask);
  }

  /** Aktualizuje treść z plików; zapis tylko, gdy coś się zmieniło. `updated_at` zostaje — to czas zmiany stanu. */
  revise(id: number, fields: Revision): Task {
    return this.db.transaction(() => {
      const task = this.mustGet(id);
      const next = {
        title: fields.title?.trim() || task.title,
        tag: fields.tag === undefined ? task.tag : fields.tag,
        refs: fields.refs ?? task.refs,
        fileSig: fields.fileSig === undefined ? task.fileSig : fields.fileSig,
      };
      const same =
        next.title === task.title && next.tag === task.tag && next.fileSig === task.fileSig && JSON.stringify(next.refs) === JSON.stringify(task.refs);
      if (same) return task;
      this.db.run(
        'UPDATE tasks SET title = ?, tag = ?, refs = ?, file_sig = ? WHERE id = ?',
        next.title,
        next.tag,
        JSON.stringify(next.refs),
        next.fileSig,
        id,
      );
      return this.mustGet(id);
    });
  }

  /** Hook zna ścieżkę transkryptu sesji, `take` tylko jej id — łączymy po id sesji. */
  attachTranscript(project: string, sessionId: string, transcriptPath: string): number {
    return this.db.run(
      `UPDATE tasks SET transcript_path = ?
       WHERE project = ? AND session_id = ? AND state = 'in_progress' AND ifnull(transcript_path, '') <> ?`,
      transcriptPath,
      project,
      sessionId,
      transcriptPath,
    ).changes;
  }

  recordSync(project: string, source: string): void {
    this.db.run(
      'INSERT INTO syncs (project, at, source) VALUES (?, ?, ?) ON CONFLICT (project) DO UPDATE SET at = excluded.at, source = excluded.source',
      project,
      this.stamp(),
      source,
    );
  }

  lastSync(project: string): SyncMark | undefined {
    return this.db.get<SyncMark>('SELECT at, source FROM syncs WHERE project = ?', project);
  }

  /** Kilka zmian w jednej transakcji — równoległe hooki nie przeplatają się w połowie sync. */
  batch<T>(fn: () => T): T {
    return this.db.transaction(fn);
  }

  private checkLevel(kind: Kind, input: NewTask): void {
    if (!KINDS.includes(kind)) throw new UsageError(`nieznany rodzaj zadania: ${kind}`);
    if (kind !== 'task' && input.parentId !== undefined) throw new UsageError('rodzica ma tylko task zmiany SDD');
    if (kind === 'change' && !input.key?.startsWith('sdd:')) throw new UsageError('zmiana SDD wymaga klucza sdd:<zmiana>');
    if (kind === 'task') {
      if (!input.key) throw new UsageError('task zmiany wymaga klucza (T-NN albo #<n>)');
      const parent = input.parentId === undefined ? undefined : this.get(input.parentId);
      if (!parent || parent.kind !== 'change' || parent.project !== input.project) {
        throw new UsageError('task wymaga rodzica: zmiany SDD z tego samego projektu');
      }
    }
    if (input.key !== undefined) {
      const taken = this.db.get(
        'SELECT id FROM tasks WHERE project = ? AND ifnull(parent_id, 0) = ? AND key = ?',
        input.project,
        input.parentId ?? 0,
        input.key,
      );
      if (taken) throw new UsageError(`klucz ${input.key} już istnieje w tym miejscu`);
    }
  }

  private log(taskId: number, at: string, state: State, owner: string, ctx: Ctx, reason: string | null): void {
    this.db.run(
      'INSERT INTO transitions (task_id, at, state, owner, actor, source, reason) VALUES (?, ?, ?, ?, ?, ?, ?)',
      taskId,
      at,
      state,
      owner,
      ctx.actor,
      ctx.source,
      reason,
    );
  }

  private stamp(): string {
    return new Date(this.clock()).toISOString();
  }
}
