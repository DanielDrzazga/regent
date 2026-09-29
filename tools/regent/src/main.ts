// regent — logika polecenia; punkt wejścia to cli.ts. Wejście i wyjście przez Io, żeby testy
// wołały main w procesie, z własnym zegarem i środowiskiem.

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
  regent --help         ta pomoc`;

export function main(io: Io): number {
  const [first] = io.argv;
  if (first === '--help' || first === '-h') {
    io.out(HELP);
    return 0;
  }
  io.err(first === undefined ? HELP : `regent: nieznane polecenie: ${first}\n\n${HELP}`);
  return 2;
}
