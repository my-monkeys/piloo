// Accès DB pour les endpoints BDPM (#76).
import { medicamentsBdpm, type Db, type MedicamentBdpm } from '@piloo/db-schema';
import { count, desc, eq, gt, ilike, or, sql } from 'drizzle-orm';

export interface BdpmStats {
  /** Date du dump le plus récent en base, ou null si table vide. */
  version: string | null;
  /** Nombre total de CIS en base (toutes versions confondues). */
  totalCis: number;
}

export async function getBdpmStats(db: Db): Promise<BdpmStats> {
  // 1 round-trip pour la version max + un autre pour le count — table
  // read-only, indexée sur la PK, donc rapide même sur 14k+ lignes.
  const [latest] = await db
    .select({ versionBdpm: medicamentsBdpm.versionBdpm })
    .from(medicamentsBdpm)
    .orderBy(desc(medicamentsBdpm.versionBdpm))
    .limit(1);
  const [{ value: total } = { value: 0 }] = await db
    .select({ value: count() })
    .from(medicamentsBdpm);
  return {
    version: latest?.versionBdpm ?? null,
    totalCis: total,
  };
}

/// Médicaments dont `version_bdpm > from`. Tri par CIP13 (PK) pour
/// stabilité du résultat à des fins de tests et caching éventuel.
export async function getBdpmDiffSince(db: Db, from: string): Promise<MedicamentBdpm[]> {
  return db
    .select()
    .from(medicamentsBdpm)
    .where(gt(medicamentsBdpm.versionBdpm, from))
    .orderBy(medicamentsBdpm.cip13);
}

const SEARCH_LIMIT = 20;

/// Recherche pour saisie manuelle (formulaire création boîte web).
/// Heuristique : si q n'est que des chiffres ≥ 7 caractères, on suppose un
/// CIP et on filtre dessus (égalité). Sinon ILIKE sur la dénomination
/// (préfixe + contains, préfixe d'abord pour pertinence).
export async function searchBdpm(db: Db, q: string): Promise<MedicamentBdpm[]> {
  const trimmed = q.trim();
  const isCip = /^\d{7,13}$/.test(trimmed);

  if (isCip) {
    return db
      .select()
      .from(medicamentsBdpm)
      .where(or(eq(medicamentsBdpm.cip13, trimmed), eq(medicamentsBdpm.cip7, trimmed)))
      .limit(SEARCH_LIMIT);
  }

  // Pertinence : un nom qui commence par q passe avant ceux qui le
  // contiennent. Pas de full-text Postgres pour rester portable ; ILIKE
  // + index trigram serait l'évolution (post-MVP).
  const prefixPattern = `${trimmed}%`;
  const containsPattern = `%${trimmed}%`;
  return db
    .select()
    .from(medicamentsBdpm)
    .where(ilike(medicamentsBdpm.denomination, containsPattern))
    .orderBy(
      sql`CASE WHEN ${medicamentsBdpm.denomination} ILIKE ${prefixPattern} THEN 0 ELSE 1 END`,
      medicamentsBdpm.denomination,
    )
    .limit(SEARCH_LIMIT);
}
