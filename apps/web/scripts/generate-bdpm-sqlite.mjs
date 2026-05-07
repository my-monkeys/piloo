#!/usr/bin/env node
// CLI génération SQLite BDPM mobile (#77).
//
// Usage :
//   pnpm --filter web bdpm:sqlite --out ~/Downloads/bdpm.sqlite
//
// La sortie est un fichier `.sqlite` que le mobile télécharge au 1er
// lancement (#78) ou à chaque diff mensuel (#79). À distribuer sur un
// CDN : Vercel Blob, Cloudflare R2, ou statique côté `apps/web/public/`.
import { parseArgs } from 'node:util';
import { mkdir, stat } from 'node:fs/promises';
import { dirname } from 'node:path';

import { getDb } from '../lib/db.ts';
import { generateBdpmSqlite } from '../lib/bdpm/sqlite.ts';
import { log } from '../lib/server/logger.ts';

const { values } = parseArgs({
  options: {
    out: { type: 'string' },
  },
});

if (!values.out) {
  console.error('Usage: bdpm:sqlite --out <path/to/bdpm.sqlite>');
  process.exit(1);
}

await mkdir(dirname(values.out), { recursive: true });

const db = getDb();
log.info('bdpm.sqlite.start', { out: values.out });
const result = await generateBdpmSqlite(db, values.out);
const fileStat = await stat(values.out);
const sizeMb = (fileStat.size / 1024 / 1024).toFixed(2);
log.info('bdpm.sqlite.done', { ...result, sizeBytes: fileStat.size });
process.stdout.write(`${JSON.stringify({ ...result, sizeMb }, null, 2)}\n`);
process.exit(0);
