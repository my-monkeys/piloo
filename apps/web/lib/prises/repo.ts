// Repository des prises planifiées (#114). Cible la timeline mobile/web :
// renvoie les prises d'un jour donné pour une officine, prescription jointe.
//
// Performance : l'index `idx_prises_officine_datetime` couvre le filtre
// (officineId + datetime_prevue range). Un seul join sur prescriptions
// + un order by sur la même colonne indexée = plan stable < 100ms même
// avec milliers de prises (cf. AC < 100ms).
import {
  prescriptions,
  prisesPlanifiees,
  rappels,
  type Db,
  type PrisePlanifiee,
  type Prescription,
  type Rappel,
} from '@piloo/db-schema';
import { and, asc, eq, gte, isNull, lt, or } from 'drizzle-orm';

/// Item de timeline : exactement un des deux champs source est non-null
/// (cf. CHECK constraint `prises_source_xor`). Les consumers doivent
/// gérer les deux cas.
export interface PriseWithSource {
  prise: PrisePlanifiee;
  prescription: Prescription | null;
  rappel: Rappel | null;
}

export interface ListPrisesForDayParams {
  officineId: string;
  /** Bornes inclusive-exclusive en UTC (calculées côté caller). */
  dayStart: Date;
  dayEnd: Date;
}

export async function listPrisesForDay(
  db: Db,
  params: ListPrisesForDayParams,
): Promise<PriseWithSource[]> {
  const rows = await db
    .select({
      prise: prisesPlanifiees,
      prescription: prescriptions,
      rappel: rappels,
    })
    .from(prisesPlanifiees)
    .leftJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .leftJoin(rappels, eq(prisesPlanifiees.rappelId, rappels.id))
    .where(
      and(
        eq(prisesPlanifiees.officineId, params.officineId),
        gte(prisesPlanifiees.datetimePrevue, params.dayStart),
        lt(prisesPlanifiees.datetimePrevue, params.dayEnd),
        isNull(prisesPlanifiees.deletedAt),
        // Filtre soft-delete sur la source applicable.
        or(
          and(isNull(prisesPlanifiees.rappelId), isNull(prescriptions.deletedAt)),
          and(isNull(prisesPlanifiees.prescriptionId), isNull(rappels.deletedAt)),
        ),
      ),
    )
    .orderBy(asc(prisesPlanifiees.datetimePrevue));

  return rows.map((r) => ({
    prise: r.prise,
    prescription: r.prescription,
    rappel: r.rappel,
  }));
}

export async function findPriseById(db: Db, id: string): Promise<PriseWithSource | null> {
  const [row] = await db
    .select({
      prise: prisesPlanifiees,
      prescription: prescriptions,
      rappel: rappels,
    })
    .from(prisesPlanifiees)
    .leftJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .leftJoin(rappels, eq(prisesPlanifiees.rappelId, rappels.id))
    .where(and(eq(prisesPlanifiees.id, id), isNull(prisesPlanifiees.deletedAt)))
    .limit(1);
  return row ? { prise: row.prise, prescription: row.prescription, rappel: row.rappel } : null;
}

export interface UpdatePriseParams {
  statut?: 'prevue' | 'prise' | 'sautee';
  notes?: string | null;
  /// Nouvel horaire prévu (#120). Sert à déplacer ponctuellement une
  /// prise — ne touche pas à la posologie de l'ordo (qui reste source
  /// de vérité pour les futures occurrences).
  datetimePrevue?: Date;
  /** Auteur de la validation, écrit dans `valideePar`. */
  userId: string;
}

/// Marque ou démarque une prise. `prise`/`sautee` posent
/// `datetimeValidation` = maintenant ; `prevue` la remet à null pour
/// signifier "non validée". On NE supporte PAS la transition vers
/// `oubliee` côté API (terminal, posé par cron #118). `statut` est
/// optionnel : on peut PATCHer juste `notes` ou `datetime_prevue`.
export async function updatePrise(
  db: Db,
  id: string,
  params: UpdatePriseParams,
): Promise<PriseWithPrescription | null> {
  const now = new Date();
  const patch: Partial<typeof prisesPlanifiees.$inferInsert> & {
    updatedAt: Date;
  } = { updatedAt: now };
  if (params.statut !== undefined) {
    patch.statut = params.statut;
    patch.datetimeValidation = params.statut === 'prevue' ? null : now;
    patch.valideePar = params.statut === 'prevue' ? null : params.userId;
  }
  if (params.notes !== undefined) patch.notes = params.notes;
  if (params.datetimePrevue !== undefined) {
    patch.datetimePrevue = params.datetimePrevue;
  }

  const updated = await db
    .update(prisesPlanifiees)
    .set(patch)
    .where(and(eq(prisesPlanifiees.id, id), isNull(prisesPlanifiees.deletedAt)))
    .returning();
  if (updated.length === 0) return null;
  return findPriseById(db, id);
}

// Alias rétrocompatible pour les callers historiques qui n'ont pas
// encore migré vers PriseWithSource. À retirer quand tout est migré.
export type PriseWithPrescription = PriseWithSource;
