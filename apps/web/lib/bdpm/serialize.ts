// Sérialisation MedicamentBdpm DB → réponse API (snake_case).
import type { MedicamentBdpm } from '@piloo/db-schema';
import type { BdpmMedicament } from '@piloo/api-contract';

export function serializeBdpmMedicament(row: MedicamentBdpm): BdpmMedicament {
  return {
    cis: row.cis,
    cip13: row.cip13,
    cip7: row.cip7,
    denomination: row.denomination,
    forme: row.forme,
    dosage: row.dosage,
    voie_administration: row.voieAdministration,
    titulaire: row.titulaire,
    statut_amm: row.statutAmm,
    taux_remboursement: row.tauxRemboursement,
    version_bdpm: row.versionBdpm,
  };
}
