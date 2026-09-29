import { renameSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildPacket, tokens } from '../src/packet.js';
import { cli, read, sddProject, write } from './helpers.js';

const json = <T = any>(text: string): T => JSON.parse(text) as T;

/** Nagłówki `## ` paczki — jej spis treści. */
const sections = (text: string): string[] => {
  let fence = false;
  return text.split('\n').filter((l) => {
    if (/^```/.test(l)) fence = !fence;
    return !fence && l.startsWith('## ');
  });
};

describe('paczka — reguły z planu', () => {
  it('[BE]: linia taska, jego REQ z delty, INVARIANTS, stałe sekcje designu + API i Error Handling', () => {
    const p = buildPacket(sddProject(), 'note-tags', ['T-02']);
    expect(p.text).toMatch(/^# Paczka: note-tags — T-02\n\nŹródło: ai\/changes\/note-tags\/ /);
    expect(sections(p.text)).toEqual([
      '## Taski',
      '## Wymagania (specs/notes.md)',
      '## INVARIANTS (specs/notes.md)',
      '## Design: Overview',
      '## Design: Affected Files',
      '## Design: API / Interface Contract',
      '## Design: Decyzje techniczne',
      '## Design: Odstępstwa od zasad',
      '## Design: Error Handling',
      '## Design: Testing Strategy',
    ]);
    expect(p.text).toContain('\n- [ ] T-02: [BE] Serwis tagów — REQ-004/AC-1..3 —');
    expect(p.text).toContain('### REQ-004: Tagi notatki — ADDED\n\n**Given** zalogowany użytkownik z notatką');
    expect(p.text).toContain('- [ ] AC-3: pusty tag → 400');
    expect(p.text).not.toContain('REQ-005');
    expect(p.text).toContain('- **INV-1:** notatki bez tagów');
    // blok kodu z „## …” w środku nie ucina sekcji API
    expect(p.text).toMatch(/## Design: API \/ Interface Contract\n[\s\S]*## to nie jest nagłówek[\s\S]*\n## Design: Decyzje techniczne/);
    for (const absent of ['Database Changes', 'Ryzyka', 'Security', 'Observability', 'Component Breakdown', 'INSTRUKCJA', 'Kontrakt czytania', '<!--']) {
      expect(p.text, absent).not.toContain(absent);
    }
    expect(p.missing).toEqual([]);
  });

  it('[DB] dokłada Database Changes zamiast API; brak tagu to [BE]; design: dokłada sekcję', () => {
    const project = sddProject();
    const db = sections(buildPacket(project, 'note-tags', ['T-01']).text);
    expect(db).toContain('## Design: Database Changes');
    expect(db).not.toContain('## Design: API / Interface Contract');
    expect(sections(buildPacket(project, 'note-tags', ['T-05']).text)).toContain('## Design: API / Interface Contract');
    const fe = buildPacket(project, 'note-tags', ['T-04']);
    expect(sections(fe.text)).toContain('## Design: Observability / Logging');
    expect(fe.text).toContain('### REQ-002: Lista notatek — MODIFIED');
    expect(fe.text).toContain('### REQ-005: Filtr po tagu — ADDED');
  });

  it('kilka tasków — suma reguł, każda sekcja raz', () => {
    const text = buildPacket(sddProject(), 'note-tags', ['T-01', 'T-04']).text;
    const s = sections(text);
    expect(s).toEqual(expect.arrayContaining(['## Design: Database Changes', '## Design: API / Interface Contract', '## Design: Observability / Logging']));
    expect(new Set(s).size).toBe(s.length);
    expect(text.match(/### REQ-004/g)).toHaveLength(1);
  });

  it('kontrakt pod nazwą „Kontrakt API…” (checklista architekta) trafia do paczki jako API', () => {
    const project = sddProject();
    const design = 'ai/changes/note-tags/design.md';
    write(project, design, read(project, design).replace('## API / Interface Contract', '## Kontrakt API↔UI (kontrakt-first)'));
    const p = buildPacket(project, 'note-tags', ['T-02']);
    expect(sections(p.text)).toContain('## Design: Kontrakt API↔UI (kontrakt-first)');
    expect(p.text).toContain('### GET /notes?tag=x');
    expect(p.missing).not.toContain('design.md: API / Interface Contract');
  });

  it('nazwa z szablonu wygrywa z aliasem kontraktu', () => {
    const project = sddProject();
    const design = 'ai/changes/note-tags/design.md';
    write(project, design, read(project, design).replace('## Overview', '## Kontrakt API — notatki robocze\n\nszkic sprzed decyzji\n\n## Overview'));
    const text = buildPacket(project, 'note-tags', ['T-02']).text;
    expect(sections(text)).toContain('## Design: API / Interface Contract');
    expect(text).not.toContain('szkic sprzed decyzji');
  });

  it('brakujące sekcje i REQ są nazwane w paczce', () => {
    const project = sddProject();
    expect(buildPacket(project, 'legacy-export', ['#2']).text).toMatch(
      /\nBrak w design\.md: Affected Files, Decyzje techniczne, Odstępstwa od zasad, API \/ Interface Contract, Error Handling\n$/,
    );
    const draft = buildPacket(project, 'draft-search', ['T-01']);
    expect(draft.missing).toEqual(['delta: REQ-006', 'design.md']);
    expect(draft.text).toMatch(/\nBrak w delcie: REQ-006\nBrak pliku design\.md\n$/);
  });

  it('paczka z zarchiwizowanej zmiany; --stats: paczka mniejsza od plików, tokeny = bajty / 3,5', () => {
    const project = sddProject();
    renameSync(join(project, 'ai/changes/note-tags'), join(project, 'ai/changes/archive/2026-09-29-note-tags'));
    const p = buildPacket(project, 'note-tags', ['T-02']);
    expect(p.dir).toBe('ai/changes/archive/2026-09-29-note-tags/');
    expect(p.stats.files).toEqual(['tasks.md', 'design.md', 'specs/notes.md']);
    expect(p.stats.packetBytes).toBeLessThan(p.stats.filesBytes);
    expect(p.stats.packetTokens).toBe(tokens(p.stats.packetBytes));
    expect(tokens(3500)).toBe(1000);

    const regent = cli({ cwd: project });
    const stats = regent('task', 'packet', 'note-tags', 't-02', '--stats');
    expect(stats.code).toBe(0);
    expect(stats.out).toBe(
      [
        `Paczka note-tags T-02: ${p.stats.packetBytes} B (~${p.stats.packetTokens} tok.)`,
        `Pliki, które zastępuje (tasks.md, design.md, specs/notes.md): ${p.stats.filesBytes} B (~${p.stats.filesTokens} tok.)`,
        `Paczka to ${Math.round((100 * p.stats.packetBytes) / p.stats.filesBytes)}% plików.`,
      ].join('\n'),
    );
    expect(regent('task', 'packet', 'note-tags', 'T-02').out).toBe(p.text.trimEnd());
    expect(json(regent('task', 'packet', 'note-tags', 'T-02', '--json').out)).toMatchObject({ keys: ['T-02'], stats: p.stats });
  });

  it('błędne użycie — kod 2', () => {
    const regent = cli({ cwd: sddProject() });
    expect(regent('task', 'packet', 'note-tags').code).toBe(2);
    expect(regent('task', 'packet', 'note-tags', 'T-42').err).toMatch(/nie ma T-42 w ai\/changes\/note-tags\/tasks\.md/);
    expect(regent('task', 'packet', 'nie-ma', 'T-01').err).toMatch(/nie ma zmiany nie-ma/);
  });
});
