// Génération du fichier SQLite mobile (#77).
//
// Le mobile (Drift) attache une DB séparée read-only contenant la BDPM.
// Cette fonction la génère depuis Postgres : on lit toutes les lignes
// de `medicaments_bdpm`, on crée un fichier SQLite local optimisé pour
// les lookups par CIP13 (chemin critique post-scan) et la recherche par
// dénomination.
//
// Format du fichier produit :
//
//   TABLE bdpm_metadata(key TEXT PRIMARY KEY, value TEXT)
//     'version'      → date de la BDPM (YYYY-MM-DD)
//     'total_cis'    → nombre de lignes inscrites (gardé pour compat
//                       affichage Settings, équivaut au nombre de
//                       présentations depuis le fix CIP-keyed)
//     'generated_at' → ISO timestamp de génération
//
//   TABLE medicaments(
//     cip13 TEXT PRIMARY KEY,
//     cip7 TEXT,
//     cis TEXT NOT NULL,
//     denomination TEXT NOT NULL,
//     forme TEXT, dosage TEXT,
//     voie_administration TEXT,
//     titulaire TEXT,
//     statut_amm TEXT,
//     taux_remboursement INTEGER,
//     ai_summary TEXT,       -- résumé IA pré-généré (#167), peut être null
//     version_bdpm TEXT NOT NULL
//   )
//
//   INDEX idx_cis          (lookup "toutes les présentations d'un médicament")
//   INDEX idx_denomination (recherche fuzzy)
//
// Le fichier est VACUUMé en fin de génération pour compacter et
// activer le mode `journal_mode=DELETE` (compatible read-only mobile).
import { DatabaseSync } from 'node:sqlite';

import { medicamentsBdpm, type Db } from '@piloo/db-schema';

export interface GenerateBdpmSqliteResult {
  outputPath: string;
  totalCis: number;
  version: string | null;
  durationMs: number;
}

export async function generateBdpmSqlite(
  db: Db,
  outputPath: string,
): Promise<GenerateBdpmSqliteResult> {
  const t0 = Date.now();

  // Lecture en streaming via select() ; le dataset complet (~37k lignes,
  // ~6 Mo en mémoire après le passage à 1-ligne-par-CIP) tient sans
  // souci, donc on charge tout en mémoire pour ne pas avoir à gérer
  // cursor + transaction Postgres.
  const rows = await db.select().from(medicamentsBdpm).orderBy(medicamentsBdpm.cip13);

  const sqlite = new DatabaseSync(outputPath);
  try {
    // Pragmas pour un fichier mobile read-only optimisé.
    sqlite.exec('PRAGMA journal_mode = DELETE');
    sqlite.exec('PRAGMA synchronous = NORMAL');
    sqlite.exec('PRAGMA page_size = 4096');

    sqlite.exec(`
      CREATE TABLE bdpm_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      ) WITHOUT ROWID;

      CREATE TABLE medicaments (
        cip13 TEXT PRIMARY KEY,
        cip7 TEXT,
        cis TEXT NOT NULL,
        denomination TEXT NOT NULL,
        forme TEXT,
        dosage TEXT,
        voie_administration TEXT,
        titulaire TEXT,
        statut_amm TEXT,
        taux_remboursement INTEGER,
        ai_summary TEXT,
        version_bdpm TEXT NOT NULL
      ) WITHOUT ROWID;

      CREATE INDEX idx_cis ON medicaments(cis);
      CREATE INDEX idx_denomination ON medicaments(denomination COLLATE NOCASE);
    `);

    // Insert batch dans une transaction pour ne pas fsync à chaque ligne.
    const insert = sqlite.prepare(`
      INSERT INTO medicaments (
        cip13, cip7, cis, denomination, forme, dosage,
        voie_administration, titulaire, statut_amm,
        taux_remboursement, ai_summary, version_bdpm
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    sqlite.exec('BEGIN');
    for (const r of rows) {
      insert.run(
        r.cip13,
        r.cip7,
        r.cis,
        r.denomination,
        r.forme,
        r.dosage,
        r.voieAdministration,
        r.titulaire,
        r.statutAmm,
        r.tauxRemboursement,
        r.aiSummary,
        r.versionBdpm,
      );
    }
    sqlite.exec('COMMIT');

    const version = rows.length > 0 ? maxVersion(rows.map((r) => r.versionBdpm)) : null;
    const insertMeta = sqlite.prepare('INSERT INTO bdpm_metadata (key, value) VALUES (?, ?)');
    insertMeta.run('version', version ?? '');
    insertMeta.run('total_cis', String(rows.length));
    insertMeta.run('generated_at', new Date().toISOString());

    // VACUUM compacte le fichier (utile après bulk insert) et reconstruit
    // les index pour qu'ils soient denses → meilleure compression à la
    // distribution gzip/brotli sur CDN.
    sqlite.exec('VACUUM');

    return {
      outputPath,
      totalCis: rows.length,
      version,
      durationMs: Date.now() - t0,
    };
  } finally {
    sqlite.close();
  }
}

function maxVersion(versions: readonly string[]): string {
  // Format YYYY-MM-DD → tri lexicographique = tri chronologique.
  // Précondition : la fonction n'est appelée que si versions.length > 0.
  let max = versions[0] ?? '';
  for (const v of versions) {
    if (v > max) max = v;
  }
  return max;
}
