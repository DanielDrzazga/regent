import { describe, expect, it } from 'vitest';
import { costOf, priceFor, shortModel, totalTokens, usageFromRecord } from '../src/parse/pricing.js';

describe('pricing', () => {
  it('liczy koszt Haiku z zapisem cache 1h jak Claude Code (cost-state członka ze spike’a)', () => {
    const u = { input: 1237, cacheWrite5m: 0, cacheWrite1h: 23999, cacheRead: 1_089_616, output: 2928 };
    expect(costOf('claude-haiku-4-5-20251001', u)).toBeCloseTo(0.1728366, 7);
  });

  it('wybiera najdłuższy prefiks modelu', () => {
    expect(priceFor('claude-opus-5-5')?.input).toBe(4);
    expect(priceFor('claude-opus-5')?.input).toBe(5);
    expect(priceFor('claude-fable-5-1')?.cacheRead).toBe(0.25);
    expect(priceFor('claude-fable-5')?.cacheRead).toBe(1);
  });

  it('model spoza cennika → brak kosztu; tryb fast → 2×', () => {
    const u = { input: 1_000_000, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 0, output: 0 };
    expect(costOf('claude-nieznany-1', u)).toBeUndefined();
    expect(costOf('claude-opus-5-5', u, true)).toBe(8);
  });

  it('usage bez podziału cache_creation liczy zapis jako 5m', () => {
    const u = usageFromRecord({ input_tokens: 1, cache_creation_input_tokens: 10, cache_read_input_tokens: 100, output_tokens: 5 });
    expect(u).toEqual({ input: 1, cacheWrite5m: 10, cacheWrite1h: 0, cacheRead: 100, output: 5 });
    expect(totalTokens(u)).toBe(116);
  });

  it('pomija śmieci w usage', () => {
    expect(usageFromRecord({ input_tokens: 'x', output_tokens: null })).toEqual({ input: 0, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 0, output: 0 });
  });

  it('skraca nazwę modelu', () => {
    expect(shortModel('claude-haiku-4-5-20251001')).toBe('haiku-4-5');
    expect(shortModel('claude-opus-5-5')).toBe('opus-5-5');
  });
});
