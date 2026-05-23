// packages/db-schema/src/schema/substances_actives_bdpm.ts
// Compositions actives des médicaments BDPM (#101).
//
// Source : CIS_COMPO_bdpm.txt (data.gouv.fr). Une ligne par substance
// (1 médoc CIS peut en avoir N — typique des combinaisons type
// Augmentin = amoxicilline + acide clavulanique).
//
// On filtre `nature_composant = 'SA'` (Substance Active) au moment
// de l'import — les excipients ne nous intéressent pas pour le
// regroupement par molécule.
import { date, index, pgTable, text, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

export const substancesActivesBdpm = pgTable(
  'substances_actives_bdpm',
  {
    id: uuid()
      .primaryKey()
      .$defaultFn(() => crypto.randomUUID()),
    /// CIS du médoc parent (FK logique vers medicaments_bdpm.cis,
    /// mais pas de contrainte hard car on import les 2 tables
    /// indépendamment et on accepte des orphelins transitoires).
    cis: text().notNull(),
    /// Code numérique stable identifiant la molécule (ex: 42215 =
    /// anastrozole). C'est la clé de groupement la plus fiable.
    codeSubstance: text().notNull(),
    /// Nom imprimé (ex: "ANASTROZOLE"). Sert à l'affichage humain.
    denominationSubstance: text().notNull(),
    /// Dosage de la substance dans le médoc (ex: "1,00 mg"). Pas
    /// strictement requis pour le grouping mais utile en debug.
    dosageSubstance: text(),
    versionBdpm: date().notNull(),
  },
  (table) => [
    // Évite les doublons en cas de ré-import partiel.
    uniqueIndex('substances_actives_bdpm_cis_code_unique').on(table.cis, table.codeSubstance),
    index('idx_substances_actives_cis').on(table.cis),
  ],
);

export type SubstanceActiveBdpm = typeof substancesActivesBdpm.$inferSelect;
export type NewSubstanceActiveBdpm = typeof substancesActivesBdpm.$inferInsert;
