// Import BDPM (#75) — orchestrateur côté serveur.
//
// Charge en mémoire 2 fichiers TSV (CIS + CIP) → combine → UPSERT en
// batch dans `medicaments_bdpm`. Conçu pour tourner :
//   - en local via le script `scripts/import-bdpm.mjs`
//   - en cron mensuel (job déclenché par CI ou Vercel Cron — cf. #74)
//
// Perf cible (AC #75) : < 5 min pour un full reload (~14k CIS,
// ~60k CIP). On batch 1000 lignes par INSERT → ~14 transactions, OK.
import { medicamentsBdpm, type Db } from '@piloo/db-schema';

// Imports avec extension `.ts` : nécessaire pour le runtime Node CLI
// (`node --experimental-strip-types scripts/import-bdpm.mjs`) qui ne
// résout pas les extensions implicites en mode ESM. Next.js bundler
// l'accepte sans problème (resolveExtensions tolère le .ts explicite).
import { combine, parseCipLine, parseCisLine, parseTsv, type MedicamentBdpmRow } from './parser.ts';

export interface ImportBdpmInput {
  /** Contenu UTF-8 (ou Latin-1 décodé) de `CIS_bdpm.txt`. */
  cisContent: string;
  /** Contenu UTF-8 (ou Latin-1 décodé) de `CIS_CIP_bdpm.txt`. */
  cipContent: string;
  /** Date du dump BDPM, format `YYYY-MM-DD`. */
  versionBdpm: string;
  /** Taille des batches d'INSERT. Défaut 1000. */
  batchSize?: number;
}

export interface ImportBdpmResult {
  cisCount: number;
  cipCount: number;
  rowsInserted: number;
  durationMs: number;
}

export async function importBdpm(db: Db, opts: ImportBdpmInput): Promise<ImportBdpmResult> {
  const t0 = Date.now();

  const cisItems = [...parseTsv(opts.cisContent, parseCisLine)];
  const cipItems = [...parseTsv(opts.cipContent, parseCipLine)];
  const rows = combine(cisItems, cipItems, opts.versionBdpm);

  const batchSize = opts.batchSize ?? 1000;
  let inserted = 0;
  for (let i = 0; i < rows.length; i += batchSize) {
    const chunk = rows.slice(i, i + batchSize);
    await upsertChunk(db, chunk);
    inserted += chunk.length;
  }

  return {
    cisCount: cisItems.length,
    cipCount: cipItems.length,
    rowsInserted: inserted,
    durationMs: Date.now() - t0,
  };
}

async function upsertChunk(db: Db, rows: MedicamentBdpmRow[]): Promise<void> {
  if (rows.length === 0) return;
  // ON CONFLICT (cip13) DO UPDATE : la PK est maintenant CIP13 (1 ligne
  // par présentation). Évite un TRUNCATE qui poserait un verrou exclusif
  // et invaliderait les caches plan Postgres pour tous les autres clients.
  await db
    .insert(medicamentsBdpm)
    .values(rows)
    .onConflictDoUpdate({
      target: medicamentsBdpm.cip13,
      set: {
        cip7: sqlExcluded('cip7'),
        cis: sqlExcluded('cis'),
        denomination: sqlExcluded('denomination'),
        forme: sqlExcluded('forme'),
        dosage: sqlExcluded('dosage'),
        voieAdministration: sqlExcluded('voie_administration'),
        titulaire: sqlExcluded('titulaire'),
        statutAmm: sqlExcluded('statut_amm'),
        tauxRemboursement: sqlExcluded('taux_remboursement'),
        versionBdpm: sqlExcluded('version_bdpm'),
        libellePresentation: sqlExcluded('libelle_presentation'),
        container: sqlExcluded('container'),
        totalDoses: sqlExcluded('total_doses'),
        doseUnit: sqlExcluded('dose_unit'),
        doseUnitPlural: sqlExcluded('dose_unit_plural'),
      },
    });
}

// Helper pour le `EXCLUDED.<col>` Postgres — Drizzle n'a pas (encore) de
// raccourci direct, on passe par sql template literal.
import { sql } from 'drizzle-orm';
const sqlExcluded = (col: string) => sql.raw(`EXCLUDED.${col}`);
