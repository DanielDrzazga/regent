// Szacunek kosztu z message.usage. Claude Code zapisuje dokładny koszt (rekord cost-state)
// dopiero przy zamknięciu sesji — do tego czasu widok liczy go sam z cennika API.
// Szacunek jest dolną granicą: zapytania poboczne (tytuł, podpowiedzi) nie trafiają do transkryptu.

export interface Usage {
  input: number;
  cacheWrite5m: number;
  cacheWrite1h: number;
  cacheRead: number;
  output: number;
}

export const emptyUsage = (): Usage => ({ input: 0, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 0, output: 0 });

export function addUsage(a: Usage, b: Usage): Usage {
  return {
    input: a.input + b.input,
    cacheWrite5m: a.cacheWrite5m + b.cacheWrite5m,
    cacheWrite1h: a.cacheWrite1h + b.cacheWrite1h,
    cacheRead: a.cacheRead + b.cacheRead,
    output: a.output + b.output,
  };
}

export const totalTokens = (u: Usage): number => u.input + u.cacheWrite5m + u.cacheWrite1h + u.cacheRead + u.output;

const num = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

/** message.usage z transkryptu → Usage. Bez podziału cache_creation cały zapis liczony jako 5m. */
export function usageFromRecord(raw: unknown): Usage {
  const u = (raw ?? {}) as Record<string, unknown>;
  const split = (u.cache_creation ?? null) as Record<string, unknown> | null;
  const write = num(u.cache_creation_input_tokens);
  const w1h = split ? num(split.ephemeral_1h_input_tokens) : 0;
  const w5m = split ? num(split.ephemeral_5m_input_tokens) : write;
  return {
    input: num(u.input_tokens),
    cacheWrite5m: w5m,
    cacheWrite1h: w1h,
    cacheRead: num(u.cache_read_input_tokens),
    output: num(u.output_tokens),
  };
}

interface Price {
  input: number;
  output: number;
  cacheWrite5m: number;
  cacheWrite1h: number;
  cacheRead: number;
}

// USD za 1M tokenów, stawki API Anthropic (2026-09). Zapis cache: 1,25× (5m) i 2× (1h) ceny
// wejścia; odczyt cache 0,1× — poza Fable 5.1 (0,025×) i Opus 5.5 (0,05×).
const p = (input: number, output: number, cacheRead: number): Price => ({
  input,
  output,
  cacheWrite5m: input * 1.25,
  cacheWrite1h: input * 2,
  cacheRead,
});

const PRICES: Array<[prefix: string, price: Price]> = [
  ['claude-fable-5-1', p(10, 50, 0.25)],
  ['claude-fable-5', p(10, 50, 1)],
  ['claude-opus-5-5', p(4, 20, 0.2)],
  ['claude-opus-5', p(5, 25, 0.5)],
  ['claude-opus-4-8', p(5, 25, 0.5)],
  ['claude-opus-4-7', p(5, 25, 0.5)],
  ['claude-opus-4-6', p(5, 25, 0.5)],
  ['claude-sonnet-5', p(2, 10, 0.2)],
  ['claude-sonnet-4-6', p(3, 15, 0.3)],
  ['claude-haiku-4-5', p(1, 5, 0.1)],
];
// Najdłuższy prefiks wygrywa: claude-opus-5-5 przed claude-opus-5.
PRICES.sort((a, b) => b[0].length - a[0].length);

export function priceFor(model: string): Price | undefined {
  return PRICES.find(([prefix]) => model.startsWith(prefix))?.[1];
}

/** Koszt w USD albo undefined, gdy model spoza cennika. Tryb fast (Opus 5 / 5.5) kosztuje 2×. */
export function costOf(model: string, u: Usage, fast = false): number | undefined {
  const pr = priceFor(model);
  if (!pr) return undefined;
  const usd =
    (u.input * pr.input +
      u.cacheWrite5m * pr.cacheWrite5m +
      u.cacheWrite1h * pr.cacheWrite1h +
      u.cacheRead * pr.cacheRead +
      u.output * pr.output) /
    1_000_000;
  return fast ? usd * 2 : usd;
}

/** Krótka nazwa modelu do tabeli: claude-haiku-4-5-20251001 → haiku-4-5. */
export function shortModel(model: string): string {
  return model.replace(/^claude-/, '').replace(/-\d{8}$/, '');
}

/**
 * Okno kontekstu wg modelu. Transkrypt go nie zapisuje, więc to szacunek z tabeli modeli:
 * Haiku 4.5 — 200k, pozostałe bieżące modele — 1M. Sesja z wariantem 200k pokaże zaniżony procent.
 */
export function contextWindow(model: string | undefined): number | undefined {
  if (!model || model === '<synthetic>') return undefined;
  if (model.startsWith('claude-haiku-4-5')) return 200_000;
  return priceFor(model) ? 1_000_000 : undefined;
}
