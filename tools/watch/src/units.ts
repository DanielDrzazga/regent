// Jednostki wspólne dla modelu widoku i UI.

/** Tokeny jak w session-tokens.sh: 950, 12k, 1.2M. */
export function fmtTokens(n: number): string {
  if (n >= 1_000_000) return `${(Math.floor(n / 100_000) / 10).toFixed(1)}M`;
  if (n >= 1000) return `${Math.round(n / 1000)}k`;
  return String(n);
}

export function fmtDuration(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min`;
  return `${Math.floor(m / 60)} h ${m % 60} min`;
}

export const fmtCost = (usd: number | undefined): string => (usd === undefined ? '?' : `$${usd.toFixed(2)}`);
