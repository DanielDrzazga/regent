#!/usr/bin/env node
// regent — rdzeń zadań warstwy runtime Regenta; logika polecenia w main.ts.

import { main } from './main.js';

process.exitCode = main({
  argv: process.argv.slice(2),
  env: process.env,
  cwd: process.cwd(),
  now: Date.now,
  out: (text) => process.stdout.write(`${text}\n`),
  err: (text) => process.stderr.write(`${text}\n`),
});
