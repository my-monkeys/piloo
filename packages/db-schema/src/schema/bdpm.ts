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
    /// Résumé IA pré-généré (#167 / EPIC #22). Court paragraphe de
    /// 2-3 phrases : "à quoi ça sert + précautions générales".
    /// Régénéré par le cron LLM (#165) ; les nouveaux médocs BDPM
    /// l'auront null tant que la prochaine passe n'a pas tourné.
    /// L'UI affiche un placeholder "résumé bientôt disponible" dans
    /// ce cas. Indexé dans le SQLite mobile (cf. lib/bdpm/sqlite.ts).
    aiSummary: text(),
    /// Version IA → permet de re-générer si on change le modèle ou le
    /// prompt (ex: "claude-haiku-4-5/v1"). Null tant que pas de résumé.
    aiSummaryVersion: text(),
    versionBdpm: date().notNull(),
    /// Libellé brut de la présentation côté BDPM, ex:
    /// "plaquette PVC-aluminium de 8 comprimés". Conservé pour debug
    /// et fallback affichage si le parsing structurel échoue.
    libellePresentation: text(),
    /// Contenant user-friendly extrait du libellé : "boîte", "flacon",
    /// "tube", "ampoule"… Sert à dire "Boîte de 8 comprimés" plutôt
    /// que "Plaquette PVC PVDC aluminium de 8 comprimés".
    container: text(),
    /// Nombre total de doses dans le conditionnement complet
    /// (ex: 20 récipients × 2 ml = 40 ml). Sert d'auto-fill pour le
    /// champ `unitesInitiales` à la création de boîte.
    totalDoses: integer(),
    /// Unité au singulier ("comprimé", "ml", "g", "ampoule"…) — drive
    /// le wording UI ("Comprimés restants" vs "ml restants").
    doseUnit: text(),
    /// Pluriel quand applicable (les unités physiques ml/g restent
    /// invariables). Évite une lib de pluralisation côté mobile.
    doseUnitPlural: text(),
  },
  (table) => [
    index('idx_bdpm_cis').on(table.cis),
    index('idx_bdpm_denomination').on(table.denomination),
  ],
);

export type MedicamentBdpm = typeof medicamentsBdpm.$inferSelect;
export type NewMedicamentBdpm = typeof medicamentsBdpm.$inferInsert;
