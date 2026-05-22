// Conversion DB → contrat API pour les rappels rapides (#98).
import type { Rappel as RappelRow } from '@piloo/db-schema';
import type { Rappel as RappelDto } from '@piloo/api-contract';

export function serializeRappel(row: RappelRow): RappelDto {
  return {
    id: row.id,
    officine_id: row.officineId,
    cip13: row.cip13,
    nom_texte: row.nomTexte,
    unite: row.unite,
    quantite_matin: row.quantiteMatin,
    quantite_midi: row.quantiteMidi,
    quantite_soir: row.quantiteSoir,
    quantite_coucher: row.quantiteCoucher,
    date_debut: row.dateDebut,
    date_fin: row.dateFin,
    actif: row.actif,
    notes: row.notes,
    cree_par_user_id: row.creeParUserId,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
  };
}
