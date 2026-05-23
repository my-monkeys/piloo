#!/usr/bin/env node
// CLI d'import des substances actives BDPM (#101).
//
// Usage :
//   pnpm --filter web bdpm:import-compo \
//     --compo ~/Downloads/CIS_COMPO_bdpm.txt \
//     --version 2026-05-22
//
// Le fichier CIS_COMPO_bdpm.txt contient 8 colonnes TSV :
//   cis  designation_pharma  code_substance  denomination_substance
//   dosage  reference_dosage  nature_composant  cle_composant
//
// On garde uniquement `nature_composant = 'SA'` (Substance Active),
// et on déduplique par (cis, code_substance) — l'INSERT ON CONFLICT
// gère les doublons silencieusement.
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';

import postgres from 'postgres';

import { log } from '../lib/server/logger.ts';

const { values } = parseArgs({
  options: {
    compo: { type: 'string' },
    version: { type: 'string' },
  },
});

if (!values.compo || !values.version) {
  console.error('Usage: bdpm:import-compo --compo <path> --version <YYYY-MM-DD>');
  process.exit(1);
}

const versionRegex = /^\d{4}-\d{2}-\d{2}$/;
if (!versionRegex.test(values.version)) {
  console.error('Version must be YYYY-MM-DD');
  process.exit(1);
}

// Auto-détection UTF-8 vs Latin-1 (cf. import-bdpm.mjs).
const decode = (buf) => {
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(buf);
  } catch {
    return new TextDecoder('windows-1252').decode(buf);
  }
};

const buf = await readFile(values.compo);
const content = decode(buf);

const lines = content.split('\n').filter((l) => l.trim().length > 0);
log.info('bdpm.compo.parse', { lines: lines.length });

// Map (cis|code) → row, pour dédupliquer côté JS avant l'INSERT.
const dedupe = new Map();
let skippedExcipient = 0;
let skippedMalformed = 0;
for (const line of lines) {
  const cols = line.split('\t');
  if (cols.length < 7) {
    skippedMalformed++;
    continue;
  }
  const cis = cols[0].trim();
  const codeSubstance = cols[2].trim();
  const denominationSubstance = cols[3].trim();
  const dosageSubstance = cols[4].trim() || null;
  const natureComposant = cols[6].trim();
  if (natureComposant !== 'SA') {
    skippedExcipient++;
    continue;
  }
  if (!cis || !codeSubstance || !denominationSubstance) {
    skippedMalformed++;
    continue;
  }
  const key = `${cis}|${codeSubstance}`;
  if (!dedupe.has(key)) {
    dedupe.set(key, {
      cis,
      codeSubstance,
      denominationSubstance,
      dosageSubstance,
      versionBdpm: values.version,
    });
  }
}

log.info('bdpm.compo.filtered', {
  kept: dedupe.size,
  skippedExcipient,
  skippedMalformed,
});

// Bypass Drizzle / `prepare:false` du factory mutualisé : on connecte
// directement avec postgres-js en mode prepared. Drizzle multi-row
// insert avec prepare:false (config Vercel-friendly de createDb)
// échoue silencieusement chez Neon — symptome observé 2026-05-23 :
// query qui throw sans `cause` exposable.
const databaseUrl = process.env['DATABASE_URL'];
if (!databaseUrl) {
  console.error('DATABASE_URL is not set');
  process.exit(1);
}
const sql = postgres(databaseUrl, { max: 1, prepare: true });
const rows = Array.from(dedupe.values());

// postgres-js sait insérer un array d'objets avec sql(rows) syntaxe.
// Les colonnes JS doivent être en snake_case pour matcher le schéma DB.
const CHUNK = 500;
let inserted = 0;
for (let i = 0; i < rows.length; i += CHUNK) {
  const chunk = rows.slice(i, i + CHUNK).map((r) => ({
    cis: r.cis,
    code_substance: r.codeSubstance,
    denomination_substance: r.denominationSubstance,
    dosage_substance: r.dosageSubstance,
    version_bdpm: r.versionBdpm,
  }));
  try {
    await sql`
      INSERT INTO substances_actives_bdpm
        ${sql(chunk, 'cis', 'code_substance', 'denomination_substance', 'dosage_substance', 'version_bdpm')}
      ON CONFLICT (cis, code_substance) DO NOTHING
    `;
  } catch (e) {
    console.error('chunk-failed at row', i, 'message:', e?.message);
    console.error('cause:', JSON.stringify(e, Object.getOwnPropertyNames(e)).slice(0, 500));
    throw e;
  }
  inserted += chunk.length;
  if (inserted % 5000 === 0 || inserted === rows.length) {
    log.info('bdpm.compo.progress', { inserted, total: rows.length });
  }
}

log.info('bdpm.compo.done', { inserted, version: values.version });
process.stdout.write(`${JSON.stringify({ inserted, version: values.version }, null, 2)}\n`);
await sql.end();
process.exit(0);
