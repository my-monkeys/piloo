// Serializers DB → wire format pour /v1/prises (#114).
import type { PriseTimelineItem } from '@piloo/api-contract';
import type { PrisePlanifiee, Prescription } from '@piloo/db-schema';

export function serializePriseTimelineItem(
  prise: PrisePlanifiee,
  prescription: Prescription,
): PriseTimelineItem {
  return {
    id: prise.id,
    officine_id: prise.officineId,
    datetime_prevue: prise.datetimePrevue.toISOString(),
    datetime_validation: prise.datetimeValidation?.toISOString() ?? null,
    statut: prise.statut,
    notes: prise.notes,
    prescription: {
      id: prescription.id,
      ordonnance_id: prescription.ordonnanceId,
      nom_texte: prescription.nomTexte,
      cip13: prescription.cip13,
      indication: prescription.indication,
      // Le `posologie` JSONB est passé tel quel — la forme évolue produit
      // et le mobile la rend avec ses propres règles d'affichage.
      posologie: prescription.posologie as unknown as Record<string, unknown>,
    },
  };
}

/**
 * Bornes UTC d'un jour ISO YYYY-MM-DD (00:00 → 24:00).
 *
 * Note fuseau : on travaille en UTC ici. Pour le MVP les prises sont
 * planifiées dans la timezone serveur (`Europe/Paris`). Un futur ticket
 * gérera la tz côté officine (#TODO support multi-tz).
 */
export function dayBoundsUtc(isoDate: string): { dayStart: Date; dayEnd: Date } {
  const dayStart = new Date(`${isoDate}T00:00:00.000Z`);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
  return { dayStart, dayEnd };
}

/**
 * Date ISO (YYYY-MM-DD) du jour courant, calculée en UTC.
 *
 * On utilise UTC volontairement pour éviter les surprises liées à la tz
 * du process Node (Vercel = UTC, dev local = local). Le mobile envoie
 * souvent une date explicite via /v1/prises?date=...
 */
export function todayIso(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}
