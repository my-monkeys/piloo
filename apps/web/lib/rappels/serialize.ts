// Sérialisation Rappel DB → wire (Zod schema).
import type { Rappel } from '@piloo/db-schema';
import type { Rappel as RappelWire } from '@piloo/api-contract';

export function serializeRappel(row: Rappel): RappelWire {
  return {
    id: row.id,
    user_id: row.userId,
    officine_id: row.officineId,
    boite_id: row.boiteId,
    label: row.label,
    heure: row.heure,
    recurrence_type: row.recurrenceType,
    actif: row.actif,
    notes: row.notes,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
  };
}
