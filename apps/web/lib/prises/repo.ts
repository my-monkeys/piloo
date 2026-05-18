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
  type Db,
  type PrisePlanifiee,
  type Prescription,
} from '@piloo/db-schema';
import { and, asc, eq, gte, isNull, lt } from 'drizzle-orm';

export interface PriseWithPrescription {
  prise: PrisePlanifiee;
  prescription: Prescription;
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
): Promise<PriseWithPrescription[]> {
  const rows = await db
    .select({ prise: prisesPlanifiees, prescription: prescriptions })
    .from(prisesPlanifiees)
    .innerJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .where(
      and(
        eq(prisesPlanifiees.officineId, params.officineId),
        gte(prisesPlanifiees.datetimePrevue, params.dayStart),
        lt(prisesPlanifiees.datetimePrevue, params.dayEnd),
        isNull(prisesPlanifiees.deletedAt),
        isNull(prescriptions.deletedAt),
      ),
    )
    .orderBy(asc(prisesPlanifiees.datetimePrevue));

  return rows.map((r) => ({ prise: r.prise, prescription: r.prescription }));
}

export async function findPriseById(db: Db, id: string): Promise<PriseWithPrescription | null> {
  const [row] = await db
    .select({ prise: prisesPlanifiees, prescription: prescriptions })
    .from(prisesPlanifiees)
    .innerJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .where(and(eq(prisesPlanifiees.id, id), isNull(prisesPlanifiees.deletedAt)))
    .limit(1);
  return row ? { prise: row.prise, prescription: row.prescription } : null;
}

export interface UpdatePriseParams {
  statut: 'prevue' | 'prise' | 'sautee';
  notes?: string | null;
  /** Auteur de la validation, écrit dans `valideePar`. */
  userId: string;
}

/// Marque ou démarque une prise. `prise`/`sautee` posent
/// `datetimeValidation` = maintenant ; `prevue` la remet à null pour
/// signifier "non validée". On NE supporte PAS la transition vers
/// `oubliee` côté API (terminal, posé par cron #118).
export async function updatePrise(
  db: Db,
  id: string,
  params: UpdatePriseParams,
): Promise<PriseWithPrescription | null> {
  const now = new Date();
  const validation = params.statut === 'prevue' ? null : now;
  const valideePar = params.statut === 'prevue' ? null : params.userId;

  const updated = await db
    .update(prisesPlanifiees)
    .set({
      statut: params.statut,
      datetimeValidation: validation,
      valideePar,
      ...(params.notes !== undefined && { notes: params.notes }),
      updatedAt: now,
    })
    .where(and(eq(prisesPlanifiees.id, id), isNull(prisesPlanifiees.deletedAt)))
    .returning();
  if (updated.length === 0) return null;
  return findPriseById(db, id);
}
