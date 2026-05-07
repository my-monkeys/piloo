#!/usr/bin/env node
// CLI d'import BDPM (#75).
//
// Usage :
//   pnpm --filter web bdpm:import \
//     --cis ~/Downloads/CIS_bdpm.txt \
//     --cip ~/Downloads/CIS_CIP_bdpm.txt \
//     --version 2026-05-01
//
// La date de version doit correspondre à celle du dump (visible sur
// https://base-donnees-publique.medicaments.gouv.fr/telechargement.php).
// Elle sert de tag pour la table mobile SQLite (#77/#79).
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';

import { getDb } from '../lib/db.ts';
import { importBdpm } from '../lib/bdpm/import.ts';
import { log } from '../lib/server/logger.ts';

const { values } = parseArgs({
  options: {
    cis: { type: 'string' },
    cip: { type: 'string' },
    version: { type: 'string' },
  },
});

if (!values.cis || !values.cip || !values.version) {
  console.error('Usage: bdpm:import --cis <path> --cip <path> --version <YYYY-MM-DD>');
  process.exit(1);
}

const versionRegex = /^\d{4}-\d{2}-\d{2}$/;
if (!versionRegex.test(values.version)) {
  console.error('Version must be YYYY-MM-DD');
  process.exit(1);
}

// Lecture en mémoire — les 2 fichiers font ensemble ~30 Mo, OK.
const [cisContent, cipContent] = await Promise.all([
  readFile(values.cis, 'utf8'),
  readFile(values.cip, 'utf8'),
]);

const db = getDb();
log.info('bdpm.import.start', { version: values.version });
const result = await importBdpm(db, { cisContent, cipContent, versionBdpm: values.version });
log.info('bdpm.import.done', result);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.exit(0);
