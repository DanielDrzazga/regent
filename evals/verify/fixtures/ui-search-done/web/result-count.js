// Licznik wyników (REQ-051) z polską odmianą.
export function renderResultCount(n) {
  return `<p role="status">${resultCountText(n)}</p>`;
}

function resultCountText(n) {
  if (n === 0) return 'Brak wyników';
  if (n === 1) return '1 notatka';
  const lastDigit = n % 10;
  const lastTwo = n % 100;
  const few = lastDigit >= 2 && lastDigit <= 4 && (lastTwo < 12 || lastTwo > 14);
  return `${n} ${few ? 'notatki' : 'notatek'}`;
}
