import { describe, expect, it } from 'vitest';
import { CLOSED, STATES, TRANSITIONS, allowedFrom, canTransition, handoffState, isReopen, requiresReason } from '../src/model.js';

describe('tabela przejść', () => {
  it('opisuje każdy stan, prowadzi tylko do znanych stanów i bez pętli w miejscu', () => {
    expect(Object.keys(TRANSITIONS).sort()).toEqual([...STATES].sort());
    for (const from of STATES) {
      for (const to of allowedFrom(from)) {
        expect(STATES).toContain(to);
        expect(to).not.toBe(from);
      }
    }
  });

  it('zakończone i porzucone wymagają powodu, a wyjść z nich można tylko ponownym otwarciem', () => {
    expect([...CLOSED].sort()).toEqual(['done', 'dropped']);
    for (const s of CLOSED) {
      expect(allowedFrom(s)).toEqual(['pending']);
      expect(isReopen(s, 'pending')).toBe(true);
      expect(requiresReason(s)).toBe(true);
    }
    expect(isReopen('done', 'dropped')).toBe(false);
    expect(isReopen('pending', 'in_progress')).toBe(false);
    for (const s of STATES.filter((x) => !CLOSED.includes(x))) expect(requiresReason(s)).toBe(false);
  });

  it('żadne zadanie nie ginie: z każdego otwartego stanu da się je porzucić z powodem', () => {
    for (const s of STATES.filter((x) => !CLOSED.includes(x))) expect(canTransition(s, 'dropped')).toBe(true);
  });

  it('przekazane i zablokowane nie kończą się bez wzięcia — tylko porzucenie', () => {
    expect(canTransition('handed_off', 'done')).toBe(false);
    expect(canTransition('blocked', 'done')).toBe(false);
    expect(canTransition('in_progress', 'in_progress')).toBe(false);
  });

  it('przekazanie do me = czeka na Ciebie, do agenta = przekazane', () => {
    expect(handoffState('me')).toBe('waiting');
    expect(handoffState('agent')).toBe('handed_off');
  });
});
