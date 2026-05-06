// Conversion DB → contrat API pour les boîtes (#86).
import type { Boite as BoiteRow } from '@piloo/db-schema';
import type { Boite as BoiteDto } from '@piloo/api-contract';

export function serializeBoite(row: BoiteRow): BoiteDto {
  return {
    id: row.id,
    officine_id: row.officineId,
    cip13: row.cip13,
    lot: row.lot,
    numero_serie: row.numeroSerie,
    peremption: row.peremption,
    unites_initiales: row.unitesInitiales,
    unites_restantes: row.unitesRestantes,
    statut: row.statut,
    notes: row.notes,
    ajoutee_par: row.ajouteePar,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
  };
}
