// Conversion DB → contrat API (#70). Centralise la sérialisation pour
// rester cohérent avec le schéma Zod `OfficineSchema` (snake_case,
// timestamps ISO 8601).
import type { Officine as OfficineRow } from '@piloo/db-schema';
import type { Officine as OfficineDto } from '@piloo/api-contract';

export function serializeOfficine(
  row: OfficineRow,
  role: 'owner' | 'editor' | 'viewer',
): OfficineDto {
  return {
    id: row.id,
    nom: row.nom,
    type: row.type,
    proprietaire_user_id: row.proprietaireUserId,
    date_naissance: row.dateNaissance,
    notes: row.notes,
    timezone: row.timezone,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
    role,
  };
}
