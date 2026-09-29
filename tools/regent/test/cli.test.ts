import { describe, expect, it } from 'vitest';
import { regent } from './helpers.js';

describe('regent — użycie', () => {
  it('--help na stdout, kod 0', () => {
    const r = regent(['--help']);
    expect(r.code).toBe(0);
    expect(r.out).toMatch(/^regent — /);
  });

  it('bez polecenia albo z nieznanym — pomoc na stderr, kod 2', () => {
    expect(regent([]).code).toBe(2);
    const r = regent(['foo']);
    expect(r.code).toBe(2);
    expect(r.err).toMatch(/nieznane polecenie: foo/);
  });
});
