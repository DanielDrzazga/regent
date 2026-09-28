// Sesje z całej maszyny: każdy katalog ~/.claude/projects/*, sesja aktywna = zmiana transkryptu
// w oknie activeMs albo żywy katalog zespołu. Transkrypty członków zespołu nie są osobnymi
// sesjami — czyta je SessionStore ich leada. Tylko odczyt.

import { readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, join } from 'node:path';
import { readHead, sessionIdOf } from './session.js';
import { SessionStore } from './store.js';

export interface WorkspaceOptions {
  claudeDir: string;
  /** Sesja wybrana na starcie (najnowsza z bieżącego katalogu albo --session) — zawsze na liście. */
  pinned?: string;
  /** Okno aktywności (ms). */
  activeMs: number;
  /** Co ile ms skanować katalogi projektów. */
  scanMs?: number;
  /** Przekazywane do SessionStore (testy). */
  discoveryMs?: number;
}

export interface SessionEntry {
  leadFile: string;
  store: SessionStore;
  pinned: boolean;
  /** Ostatnia zmiana któregokolwiek pliku sesji (mtime transkryptu leada). */
  mtime: number;
}

/** Katalog projektu sesji do wyświetlenia: cwd z transkryptu (~ zamiast katalogu domowego). */
export function projectLabel(entry: SessionEntry): { name: string; path: string } {
  const cwd = entry.store.sources().find((a) => a.kind === 'lead')?.state.cwd;
  if (!cwd) {
    const dir = basename(join(entry.leadFile, '..'));
    return { name: dir, path: dir };
  }
  const home = homedir();
  const path = cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
  return { name: basename(cwd), path };
}

export class Workspace {
  private readonly entries = new Map<string, SessionEntry>();
  /** Tożsamość pliku z jego początku: true = transkrypt członka zespołu (nie osobna sesja). */
  private readonly isTeammate = new Map<string, boolean>();
  private lastScan = Number.NEGATIVE_INFINITY;

  constructor(private readonly opts: WorkspaceOptions) {
    if (opts.pinned) this.add(opts.pinned, true, 0);
  }

  private add(leadFile: string, pinned: boolean, mtime: number): void {
    const existing = this.entries.get(leadFile);
    if (existing) {
      existing.mtime = Math.max(existing.mtime, mtime);
      return;
    }
    const store = new SessionStore({
      claudeDir: this.opts.claudeDir,
      leadFile,
      ...(this.opts.discoveryMs !== undefined ? { discoveryMs: this.opts.discoveryMs } : {}),
    });
    this.entries.set(leadFile, { leadFile, store, pinned, mtime });
  }

  private teammate(file: string): boolean {
    let t = this.isTeammate.get(file);
    if (t === undefined) {
      const head = readHead(file);
      t = Boolean(head.agentName && head.teamName);
      // Plik bez rekordów rozmowy może jeszcze dostać teamName — nie zapamiętujemy werdyktu.
      if (t || head.conversational) this.isTeammate.set(file, t);
    }
    return t;
  }

  private scan(now: number): void {
    const projects = join(this.opts.claudeDir, 'projects');
    let liveTeams: string[] = [];
    try {
      liveTeams = readdirSync(join(this.opts.claudeDir, 'teams'))
        .filter((n) => n.startsWith('session-'))
        .map((n) => n.slice('session-'.length));
    } catch {
      // brak katalogu zespołów
    }
    let dirs: string[] = [];
    try {
      dirs = readdirSync(projects);
    } catch {
      return;
    }
    const seen = new Set<string>();
    for (const d of dirs) {
      const dir = join(projects, d);
      let names: string[];
      try {
        names = readdirSync(dir);
      } catch {
        continue;
      }
      for (const n of names) {
        if (!n.endsWith('.jsonl')) continue;
        const file = join(dir, n);
        let mtime: number;
        try {
          mtime = statSync(file).mtimeMs;
        } catch {
          continue;
        }
        const id = sessionIdOf(file);
        const live = liveTeams.some((p) => id.startsWith(p));
        if (!live && mtime < now - this.opts.activeMs) continue;
        if (this.teammate(file)) continue;
        this.add(file, false, mtime);
        seen.add(file);
      }
    }
    for (const [file, e] of this.entries) {
      if (!e.pinned && !seen.has(file)) this.entries.delete(file);
    }
  }

  refresh(now = Date.now()): void {
    if (now - this.lastScan >= (this.opts.scanMs ?? 5000)) {
      this.lastScan = now;
      this.scan(now);
    }
    for (const e of this.entries.values()) e.store.refresh(now);
  }

  /** Sesje od ostatnio aktywnej; sesja wybrana na starcie pierwsza w swoim projekcie. */
  sessions(): SessionEntry[] {
    return [...this.entries.values()].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.mtime - a.mtime);
  }

  /** Katalogi do obserwacji (fs.watch): projekty aktywnych sesji i ich zespoły. */
  get watchDirs(): string[] {
    return [...new Set([...this.entries.values()].flatMap((e) => e.store.watchDirs))];
  }
}
