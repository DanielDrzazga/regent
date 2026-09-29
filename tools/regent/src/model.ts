// Model zadań — stany, tabela dozwolonych przejść, właściciele i rodzaje. Czyste dane i funkcje,
// bez bazy: jedynym modułem, który zmienia stan, jest TaskStore (tasks.ts).

/** „Wstrzymane do resetu” dochodzi w etapie 3 razem z limitem — schemat trzyma stan jako tekst. */
export const STATES = ['pending', 'in_progress', 'waiting', 'blocked', 'handed_off', 'done', 'dropped'] as const;
export type State = (typeof STATES)[number];

export const STATE_LABEL: Readonly<Record<State, string>> = {
  pending: 'oczekuje',
  in_progress: 'w toku',
  waiting: 'czeka na Ciebie',
  blocked: 'zablokowane',
  handed_off: 'przekazane',
  done: 'zakończone',
  dropped: 'porzucone',
};

/** Zamknięcie jest jawne i ma powód; jedyne wyjście ze stanu końcowego to ponowne otwarcie. */
export const CLOSED: readonly State[] = ['done', 'dropped'];

/**
 * Dozwolone przejścia (z → do). Poza tabelą: wejście w ten sam stan, zakończenie zadania
 * przekazanego albo zablokowanego — najpierw ktoś musi je wziąć.
 * Przejścia bez polecenia CLI (np. w toku → oczekuje) zostawiamy dla sync z artefaktów SDD.
 * Ponowne otwarcie (zamknięte → oczekuje) też woła tylko sync — gdy plik cofa zamknięcie
 * (odznaczony task, zmiana wyjęta z archiwum) — i zawsze z powodem.
 */
export const TRANSITIONS: Readonly<Record<State, readonly State[]>> = {
  pending: ['in_progress', 'waiting', 'handed_off', 'blocked', 'done', 'dropped'],
  in_progress: ['pending', 'waiting', 'handed_off', 'blocked', 'done', 'dropped'],
  waiting: ['pending', 'in_progress', 'handed_off', 'done', 'dropped'],
  blocked: ['pending', 'in_progress', 'waiting', 'handed_off', 'dropped'],
  handed_off: ['in_progress', 'waiting', 'dropped'],
  done: ['pending'],
  dropped: ['pending'],
};

/** Właściciel w etapie 1; od etapu 2 dochodzi adres seatu. */
export const OWNERS = ['me', 'agent'] as const;
export type Owner = (typeof OWNERS)[number];

/** Dwa poziomy: zmiana SDD (rodzic, klucz `sdd:<zmiana>`) i jej taski; ręczne zadania bez rodzica. */
export const KINDS = ['change', 'task', 'manual'] as const;
export type Kind = (typeof KINDS)[number];

export const isState = (value: string): value is State => (STATES as readonly string[]).includes(value);
export const isOwner = (value: string): value is Owner => (OWNERS as readonly string[]).includes(value);

export const allowedFrom = (from: State): readonly State[] => TRANSITIONS[from];
export const canTransition = (from: State, to: State): boolean => TRANSITIONS[from].includes(to);
export const requiresReason = (state: State): boolean => CLOSED.includes(state);
export const isReopen = (from: State, to: State): boolean => CLOSED.includes(from) && !CLOSED.includes(to);

/** Przekazanie do mnie to „czeka na Ciebie”; do agenta — „przekazane”, aż je weźmie. */
export const handoffState = (owner: Owner): State => (owner === 'me' ? 'waiting' : 'handed_off');

/** Niedozwolone przejście — CLI kończy się kodem 1 i listą możliwych. */
export class TransitionError extends Error {
  readonly allowed: readonly State[];

  constructor(
    readonly taskId: number,
    readonly from: State,
    readonly to: State,
    message = `#${taskId}: przejście „${STATE_LABEL[from]}” → „${STATE_LABEL[to]}” niedozwolone`,
  ) {
    super(message);
    this.allowed = allowedFrom(from);
  }
}

/** Błędne użycie: nieznane zadanie, brak powodu, zły rodzic — CLI kończy się kodem 2. */
export class UsageError extends Error {}
