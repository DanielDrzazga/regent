#!/usr/bin/env node
// regent-apply-tokens — pierwsza tura subagentów apply z transkryptów; logika w apply-tokens.ts.

import { main } from './apply-tokens.js';

process.exitCode = main({
  argv: process.argv.slice(2),
  env: process.env,
  cwd: process.cwd(),
  out: (text) => process.stdout.write(`${text}\n`),
  err: (text) => process.stderr.write(`${text}\n`),
});
