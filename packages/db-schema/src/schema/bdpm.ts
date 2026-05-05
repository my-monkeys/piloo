// packages/db-schema/src/schema/bdpm.ts
// Source : docs/data-model.md §"medicaments_bdpm". Miroir de la base BDPM
// officielle (data.gouv.fr), alimentée par job cron mensuel (#74). Read-only
// côté app, donc pas de soft delete ni updatedAt — on remplace ligne à ligne
// à chaque import. La PK est CIS (code de spécialité).
import { date, index, integer, pgTable, text } from 'drizzle-orm/pg-core';

export const medicamentsBdpm = pgTable(
  'medicaments_bdpm',
  {
    cis: text().primaryKey(),
    cip13: text(),
    cip7: text(),
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
    index('idx_bdpm_cip13').on(table.cip13),
    index('idx_bdpm_denomination').on(table.denomination),
  ],
);

export type MedicamentBdpm = typeof medicamentsBdpm.$inferSelect;
export type NewMedicamentBdpm = typeof medicamentsBdpm.$inferInsert;
