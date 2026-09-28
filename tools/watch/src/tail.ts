// Przyrostowe czytanie JSONL: zwraca tylko nowe, pełne linie od ostatniego odczytu.
// Ucięta ostatnia linia czeka w buforze na resztę; bajty dzielone są na granicy '\n',
// więc znak UTF-8 rozcięty między odczytami nie ulega uszkodzeniu.

import { closeSync, openSync, readSync, statSync } from 'node:fs';

export interface TailRead {
  lines: string[];
  /** Plik skrócono albo podmieniono — stan zbudowany z wcześniejszych linii jest nieaktualny. */
  reset: boolean;
}

export class JsonlTail {
  private offset = 0;
  private partial: Buffer = Buffer.alloc(0);

  constructor(readonly file: string) {}

  read(): TailRead {
    let size: number;
    try {
      size = statSync(this.file).size;
    } catch {
      return { lines: [], reset: false };
    }
    let reset = false;
    if (size < this.offset) {
      this.offset = 0;
      this.partial = Buffer.alloc(0);
      reset = true;
    }
    if (size === this.offset) return { lines: [], reset };

    const chunk = Buffer.alloc(size - this.offset);
    const fd = openSync(this.file, 'r');
    let n: number;
    try {
      n = readSync(fd, chunk, 0, chunk.length, this.offset);
    } finally {
      closeSync(fd);
    }
    this.offset += n;
    const data = Buffer.concat([this.partial, chunk.subarray(0, n)]);
    const cut = data.lastIndexOf(0x0a);
    if (cut === -1) {
      this.partial = data;
      return { lines: [], reset };
    }
    this.partial = Buffer.from(data.subarray(cut + 1)); // kopia — nie trzyma całego odczytu w pamięci
    return { lines: data.subarray(0, cut).toString('utf8').split('\n'), reset };
  }
}
