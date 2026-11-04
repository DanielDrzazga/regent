/** Tokeny jak w session-tokens.sh: 950, 12k, 1.2M. */
export function fmtTokens(n: number): string {
  if (n >= 1_000_000) return `${(Math.floor(n / 100_000) / 10).toFixed(1)}M`;
  if (n >= 1000) return `${Math.round(n / 1000)}k`;
  return String(n);
}
