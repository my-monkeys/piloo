// Serializers DB → wire format pour /v1/prises (#114, #343).
//
// Pour les prises issues d'un rappel rapide (rappelId != null), on
// construit une "prescription synthétique" portant les infos du rappel.
// Choix pragmatique : éviter de modifier le contrat PriseTimelineItem
// (rendre `prescription` nullable casse le client Dart généré qui ne
// supporte pas bien `.nullable()` sur les $ref). À refactorer le jour
// où on veut vraiment distinguer les deux sources côté mobile.
import type { PriseTimelineItem } from '@piloo/api-contract';
import type { PrisePlanifiee, Prescription, Rappel } from '@piloo/db-schema';

/// Mappe l'heure d'une prise (UTC, HH) sur le moment du rappel pour
/// remonter la quantité correspondante. Le rappel a 4 colonnes
/// quantite_matin/midi/soir/coucher ; on choisit selon la fourchette
/// horaire UTC qui correspond aux defaults (08/12/19/22).
function rappelQuantityForDatetime(prise: PrisePlanifiee, rappel: Rappel): number | null {
  const hour = prise.datetimePrevue.getUTCHours();
  if (hour < 10) return rappel.quantiteMatin;
  if (hour < 16) return rappel.quantiteMidi;
  if (hour < 21) return rappel.quantiteSoir;
  return rappel.quantiteCoucher;
}

function buildSyntheticPrescriptionFromRappel(
  prise: PrisePlanifiee,
  rappel: Rappel,
): PriseTimelineItem['prescription'] {
  const qty = rappelQuantityForDatetime(prise, rappel);
  return {
    id: rappel.id,
    // ordonnance_id requiert un UUID valide. On réutilise rappel.id —
    // le mobile ne navigue pas vers /ordonnances/{id} depuis les
    // prises rappel pour l'instant.
    ordonnance_id: rappel.id,
    nom_texte: rappel.nomTexte,
    cip13: rappel.cip13,
    indication: null,
    posologie: {
      unitesParPrise: qty ?? 1,
      unite: rappel.unite,
      frequence: 'quotidien',
      // Pas de `moments`/`horaires` exposés : la timeline n'a besoin
      // que du nom + unité + dosage par prise.
    },
  };
}

export function serializePriseTimelineItem(
  prise: PrisePlanifiee,
  prescription: Prescription | null,
  rappel: Rappel | null = null,
): PriseTimelineItem {
  const presPayload: PriseTimelineItem['prescription'] = prescription
    ? {
        id: prescription.id,
        ordonnance_id: prescription.ordonnanceId,
        nom_texte: prescription.nomTexte,
        cip13: prescription.cip13,
        indication: prescription.indication,
        // Le `posologie` JSONB est passé tel quel — la forme évolue produit
        // et le mobile la rend avec ses propres règles d'affichage.
        posologie: prescription.posologie as unknown as Record<string, unknown>,
      }
    : rappel
      ? buildSyntheticPrescriptionFromRappel(prise, rappel)
      : (() => {
          throw new Error(
            `Prise ${prise.id} sans source (ni prescription ni rappel) — bug d'invariant.`,
          );
        })();
  return {
    id: prise.id,
    officine_id: prise.officineId,
    datetime_prevue: prise.datetimePrevue.toISOString(),
    datetime_validation: prise.datetimeValidation?.toISOString() ?? null,
    statut: prise.statut,
    notes: prise.notes,
    prescription: presPayload,
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
