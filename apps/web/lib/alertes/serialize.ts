// Sérialisation Alerte DB → réponse API (snake_case + ISO dates).
import type { Alerte as AlerteRow } from '@piloo/db-schema';
import type { Alerte as AlerteDto } from '@piloo/api-contract';

export function serializeAlerte(row: AlerteRow): AlerteDto {
  return {
    id: row.id,
    officine_id: row.officineId,
    user_id: row.userId,
    type: row.type,
    payload: row.payload,
    lue_a: row.lueA?.toISOString() ?? null,
    created_at: row.createdAt.toISOString(),
  };
}
