import { appendFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { JsonlTail } from '../src/tail.js';

const tmpFile = () => join(mkdtempSync(join(tmpdir(), 'regent-tail-')), 't.jsonl');

describe('JsonlTail', () => {
  it('zwraca tylko nowe pełne linie, uciętą czeka na resztę', () => {
    const f = tmpFile();
    writeFileSync(f, '{"a":1}\n{"b":');
    const t = new JsonlTail(f);
    expect(t.read()).toEqual({ lines: ['{"a":1}'], reset: false });
    expect(t.read()).toEqual({ lines: [], reset: false });
    appendFileSync(f, '2}\n');
    expect(t.read().lines).toEqual(['{"b":2}']);
  });

  it('nie psuje znaku UTF-8 rozciętego między odczytami', () => {
    const f = tmpFile();
    const bytes = Buffer.from('{"t":"zażółć"}\n', 'utf8');
    writeFileSync(f, bytes.subarray(0, 9)); // w środku „ż"
    const t = new JsonlTail(f);
    expect(t.read().lines).toEqual([]);
    appendFileSync(f, bytes.subarray(9));
    expect(t.read().lines).toEqual(['{"t":"zażółć"}']);
  });

  it('skrócony plik → reset i czytanie od początku', () => {
    const f = tmpFile();
    writeFileSync(f, '{"a":1}\n{"b":2}\n');
    const t = new JsonlTail(f);
    t.read();
    writeFileSync(f, '{"c":3}\n');
    expect(t.read()).toEqual({ lines: ['{"c":3}'], reset: true });
  });

  it('brak pliku → pusto, bez wyjątku', () => {
    expect(new JsonlTail('/nie/ma/takiego.jsonl').read()).toEqual({ lines: [], reset: false });
  });
});
