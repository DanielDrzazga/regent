// Sync z artefaktów SDD. Zmiana w `ai/changes/` to zadanie-rodzic `sdd:<zmiana>`, którego stan wynika
// z plików. Sync przestawia stan tylko wtedy, gdy zmienił się stan wynikający z artefaktów
// (`refs.implied`): ręczna zmiana przez CLI zostaje do następnej zmiany plików, a rozjazd widać
// w Uwadze `list`. Przejście, którego tabela nie dopuszcza, zostaje niewykonane — bez zgadywania.

import { existsSync } from 'node:fs';
import { CLOSED, canTransition, type Owner, type State } from './model.js';
import {
  activeChanges,
  archivedChanges,
  changeDir,
  changeSig,
  changesDir,
  isAbandoned,
  sddStatus,
  type ChangeStatus,
} from './sdd.js';
import type { Ctx, Task, TaskStore } from './tasks.js';

export interface Implied {
  state: State;
  reason: string;
}

/** Werdykty z verification.md (`PASS / FAIL`) i słownik subagentów weryfikacji (`PASS / WARN / BLOCK`). */
const PASSING = ['PASS', 'WARN'];
const BLOCKING = ['BLOCK', 'FAIL'];

/** Mapa SDD → stan zmiany (plan task-core, tabela Decyzje). */
export function impliedState(s: ChangeStatus): Implied {
  switch (s.status) {
    case 'Draft':
      return { state: 'waiting', reason: 'Status: Draft' };
    case 'Rejected':
      return { state: 'dropped', reason: 'Status: Rejected' };
    case 'Abandoned':
      return { state: 'dropped', reason: 'Status: Abandoned' };
    case 'Approved':
      break;
    default:
      return { state: 'waiting', reason: `Status: ${s.status} — popraw proposal.md` };
  }
  const tasks = `Approved, taski ${s.done}/${s.total}`;
  if (s.done === 0) return { state: 'pending', reason: tasks };
  if (s.done < s.total) return { state: 'in_progress', reason: tasks };
  if (s.verdict === null) return { state: 'pending', reason: `${tasks}, do weryfikacji` };
  const verified = `${tasks}, weryfikacja ${s.verdict || 'bez Verdict'}${s.head ? `@${s.head}` : ''}`;
  if (PASSING.includes(s.verdict)) return { state: 'waiting', reason: `${verified} — do archiwum` };
  if (BLOCKING.includes(s.verdict)) return { state: 'in_progress', reason: verified };
  return { state: 'pending', reason: `${verified} — nieznany werdykt, do weryfikacji` };
}

export interface SyncEvent {
  id: number;
  key: string;
  /** null — zadanie założone w tym sync. */
  from: State | null;
  to: State;
  reason: string;
}

export interface SyncReport {
  project: string;
  /** Projekt ma `ai/changes/`. */
  sdd: boolean;
  /** Zawołano sdd-check.sh — pliki stanu którejś zmiany się zmieniły. */
  checked: boolean;
  events: SyncEvent[];
}

export interface SyncOptions {
  ctx: Ctx;
  session?: { id: string; transcriptPath?: string | undefined };
  script?: string;
}

export const changeKey = (name: string): string => `sdd:${name}`;
export const changeName = (t: Task): string => (t.key ?? '').replace(/^sdd:/, '');

/** Właściciel wynika ze stanu: „czeka na Ciebie” → me, praca → agent; zamknięcie właściciela nie zmienia. */
function ownerFor(state: State, current: Owner): Owner {
  if (state === 'waiting') return 'me';
  if (state === 'pending' || state === 'in_progress') return 'agent';
  return current;
}

/**
 * Przestawia zadanie na stan z artefaktów. Zamknięte, a pliki mówią inaczej → najpierw ponowne
 * otwarcie. Przejście spoza tabeli (np. przekazane → zakończone) — stan zostaje.
 */
function mover(store: TaskStore, ctx: Ctx, events: SyncEvent[]) {
  const step = (t: Task, to: State, reason: string): Task => {
    const next = store.transition(t.id, to, { ...ctx, owner: ownerFor(to, t.owner), reason });
    events.push({ id: t.id, key: t.key ?? `#${t.id}`, from: t.state, to, reason });
    return next;
  };
  return (t: Task, { state, reason }: Implied): Task => {
    let current = t;
    if (current.state !== state && !canTransition(current.state, state) && CLOSED.includes(current.state)) {
      current = step(current, 'pending', `ponowne otwarcie — ${reason}`);
    }
    if (current.state !== state && canTransition(current.state, state)) current = step(current, state, reason);
    return current;
  };
}

export function syncProject(store: TaskStore, root: string, opts: SyncOptions): SyncReport {
  if (opts.session?.transcriptPath) store.attachTranscript(root, opts.session.id, opts.session.transcriptPath);
  const report: SyncReport = { project: root, sdd: existsSync(changesDir(root)), checked: false, events: [] };
  if (!report.sdd) return report;

  const active = activeChanges(root).map((name) => ({ name, sig: changeSig(changeDir(root, name)) }));
  const known = new Map(store.changes(root).map((t) => [changeName(t), t]));
  const statuses = new Map<string, ChangeStatus>();
  // Skrypt wołamy, gdy pliki stanu którejś zmiany się zmieniły albo zmiana wróciła z archiwum.
  const stale = ({ name, sig }: { name: string; sig: string }) => {
    const t = known.get(name);
    return t?.fileSig !== sig || t.refs.archive !== undefined;
  };
  if (active.some(stale)) {
    for (const s of sddStatus(root, opts.script)) statuses.set(s.name, s);
    report.checked = true;
  }
  const activeNames = new Set(active.map((c) => c.name));
  const move = mover(store, opts.ctx, report.events);

  store.batch(() => {
    for (const { name, sig } of active) {
      const status = statuses.get(name);
      if (!status) continue; // pliki stanu bez zmian od ostatniego sync
      const implied = impliedState(status);
      const refs = {
        status: status.status,
        tasks: `${status.done}/${status.total}`,
        verification: status.verdict === null ? null : `${status.verdict}@${status.head ?? ''}`,
        implied: implied.state,
      };
      const key = changeKey(name);
      const t = store.findByKey(root, null, key);
      if (!t) {
        const owner = ownerFor(implied.state, 'me');
        const created = store.add(
          { project: root, kind: 'change', key, title: name, owner, state: implied.state, reason: implied.reason, refs, fileSig: sig },
          opts.ctx,
        );
        report.events.push({ id: created.id, key, from: null, to: created.state, reason: implied.reason });
        continue;
      }
      const edge = t.refs.implied !== implied.state;
      const revised = store.revise(t.id, { refs, fileSig: sig });
      if (edge) move(revised, implied);
    }

    // Archiwum: zamykamy tylko zmiany, które baza zna — historii sprzed pierwszego sync nie odtwarzamy.
    // Katalog archiwum już widziany (refs.archive) nie jest nowym faktem.
    for (const [name, archived] of archivedChanges(root)) {
      if (activeNames.has(name)) continue;
      const t = store.findByKey(root, null, changeKey(name));
      if (!t || t.refs.archive === archived.dir) continue;
      const abandoned = isAbandoned(root, archived);
      const implied: Implied = abandoned
        ? { state: 'dropped', reason: `archiwum: ${archived.dir}, Status: Abandoned` }
        : { state: 'done', reason: `archiwum: ${archived.dir}` };
      const revised = store.revise(t.id, { refs: { ...t.refs, archive: archived.dir, implied: implied.state } });
      move(revised, implied);
    }
    store.recordSync(root, opts.ctx.source);
  });
  return report;
}
