// Accès DB pour les endpoints BDPM (#76).
import { medicamentsBdpm, type Db, type MedicamentBdpm } from '@piloo/db-schema';
import { count, desc, gt } from 'drizzle-orm';

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

/// Médicaments dont `version_bdpm > from`. Le tri est par CIS pour
/// stabilité du résultat à des fins de tests et caching éventuel.
export async function getBdpmDiffSince(db: Db, from: string): Promise<MedicamentBdpm[]> {
  return db
    .select()
    .from(medicamentsBdpm)
    .where(gt(medicamentsBdpm.versionBdpm, from))
    .orderBy(medicamentsBdpm.cis);
}
