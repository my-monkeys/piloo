// packages/db-schema/src/schema/bdpm.ts
// Source : docs/data-model.md §"medicaments_bdpm". Miroir de la base BDPM
// officielle (data.gouv.fr), alimentée par job cron mensuel (#74). Read-only
// côté app, donc pas de soft delete ni updatedAt — on remplace ligne à ligne
// à chaque import.
//
// PK = CIP13 (et NON CIS).
//   Un médicament (CIS) a 1 à N présentations (tailles de boîte), chacune
//   avec son propre CIP13. La scan d'une boîte renvoie le CIP13 ; on doit
//   pouvoir résoudre n'importe laquelle des présentations. Le précédent
//   choix « 1 ligne par CIS » faisait perdre ~60% des CIPs (14k au lieu
//   de ~37k publiés), d'où des miss systématiques sur les boîtes
//   « secondaires » d'un même médicament.
import { date, index, integer, pgTable, text } from 'drizzle-orm/pg-core';

export const medicamentsBdpm = pgTable(
  'medicaments_bdpm',
  {
    /// CIP13 = code à barres officiel d'une présentation (taille de boîte).
    /// Unique → PK. C'est l'identifiant scanné par mobile_scanner.
    cip13: text().primaryKey(),
    /// CIP7 hérité (compatible vieux systèmes pharma). Nullable.
    cip7: text(),
    /// CIS = code spécialité. Plusieurs CIPs peuvent partager le même CIS
    /// (ex. boîte de 28 vs boîte de 84 du même médicament). Indexé pour
    /// les requêtes « toutes les boîtes de la même spécialité ».
    cis: text().notNull(),
    denomination: text().notNull(),
    forme: text(),
    dosage: text(),
    voieAdministration: text(),
    titulaire: text(),
    statutAmm: text(),
    tauxRemboursement: integer(),
    versionBdpm: date().notNull(),
  },
  (table) => [
    index('idx_bdpm_cis').on(table.cis),
    index('idx_bdpm_denomination').on(table.denomination),
  ],
);

export type MedicamentBdpm = typeof medicamentsBdpm.$inferSelect;
export type NewMedicamentBdpm = typeof medicamentsBdpm.$inferInsert;
