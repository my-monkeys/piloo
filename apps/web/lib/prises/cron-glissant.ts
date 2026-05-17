// Cron quotidien de génération glissante des prises (#108).
//
// Pour chaque prescription "à vie" (dureeJours = null) non soft-deleted,
// on génère les prises sur la fenêtre [today, today + WINDOW_DAYS).
//
// Idempotence : on dédup par (prescription_id, datetime_prevue). Un rerun
// dans la même journée ne crée rien de nouveau. Une exécution à J+1
// n'ajoute que les prises de la nouvelle journée en bout de fenêtre.
//
// Edge cases :
// - Prescription dont l'ordonnance ou la prescription est soft-deleted :
//   ignorée (les prises déjà créées restent en place — c'est de l'historique).
// - frequence = a_la_demande : aucune prise générée (rien à planifier).
// - Si l'utilisateur a déjà cliqué `prise`/`sautee` sur une occurrence,
//   le statut est préservé : on ne réécrit jamais une prise existante.
import {
  ordonnances,
  prescriptions,
  prisesPlanifiees,
  type Db,
  type NewPrisePlanifiee,
} from '@piloo/db-schema';
import { and, eq, gte, isNull, lt } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

import { generatePrisesForWindow } from './generate';

export const WINDOW_DAYS = 30;

export interface GenerationGlissanteResult {
  /** Nombre de prescriptions "à vie" inspectées. */
  candidates: number;
  /** Nombre total de prises créées (après dédup). */
  prisesCreated: number;
}

/** Minuit UTC du jour donné. */
function utcMidnight(d: Date): Date {
  const m = new Date(d);
  m.setUTCHours(0, 0, 0, 0);
  return m;
}

export async function runGenerationGlissanteCron(
  db: Db,
  now: Date = new Date(),
): Promise<GenerationGlissanteResult> {
  const windowStart = utcMidnight(now);
  const windowEnd = new Date(windowStart);
  windowEnd.setUTCDate(windowEnd.getUTCDate() + WINDOW_DAYS);

  // Prescriptions "à vie" actives, jointes avec leur ordonnance pour
  // récupérer officineId et exclure les ordonnances soft-deleted.
  const rows = await db
    .select({
      id: prescriptions.id,
      posologie: prescriptions.posologie,
      officineId: ordonnances.officineId,
    })
    .from(prescriptions)
    .innerJoin(
      ordonnances,
      and(eq(ordonnances.id, prescriptions.ordonnanceId), isNull(ordonnances.deletedAt)),
    )
    .where(and(isNull(prescriptions.deletedAt), isNull(prescriptions.dureeJours)));

  let prisesCreated = 0;
  for (const row of rows) {
    const generated = generatePrisesForWindow(
      { id: row.id, posologie: row.posologie },
      { officineId: row.officineId, windowStart, windowDays: WINDOW_DAYS },
    );
    if (generated.length === 0) continue;

    const toInsert = await dedupAgainstExisting(db, row.id, generated, windowStart, windowEnd);
    if (toInsert.length === 0) continue;

    await db.insert(prisesPlanifiees).values(toInsert);
    prisesCreated += toInsert.length;
  }

  log.info('cron.generation_glissante.done', { candidates: rows.length, prisesCreated });
  return { candidates: rows.length, prisesCreated };
}

async function dedupAgainstExisting(
  db: Db,
  prescriptionId: string,
  candidates: NewPrisePlanifiee[],
  windowStart: Date,
  windowEnd: Date,
): Promise<NewPrisePlanifiee[]> {
  // On charge les datetime_prevue déjà existants pour cette prescription
  // dans la fenêtre, soft-deleted exclus (les soft-deleted ne sont pas
  // candidates à la re-création — UX : si l'user a supprimé une prise,
  // c'est qu'il ne la veut plus, même si le cron repasse).
  const existing = await db
    .select({ datetimePrevue: prisesPlanifiees.datetimePrevue })
    .from(prisesPlanifiees)
    .where(
      and(
        eq(prisesPlanifiees.prescriptionId, prescriptionId),
        gte(prisesPlanifiees.datetimePrevue, windowStart),
        lt(prisesPlanifiees.datetimePrevue, windowEnd),
        isNull(prisesPlanifiees.deletedAt),
      ),
    );
  const alreadyAt = new Set(existing.map((e) => e.datetimePrevue.getTime()));
  return candidates.filter((c) => !alreadyAt.has(c.datetimePrevue.getTime()));
}

/** Hard-delete les prises futures `prevue` d'une prescription soft-deletée.
 *
 * Utile à appeler depuis le service qui soft-delete une prescription pour
 * éviter d'afficher des occurrences obsolètes dans la timeline. NB : non
 * appelé par le cron, exposé pour les API mutation prescription. */
export async function cancelFuturePrises(
  db: Db,
  prescriptionId: string,
  now: Date = new Date(),
): Promise<number> {
  const result = await db
    .update(prisesPlanifiees)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(prisesPlanifiees.prescriptionId, prescriptionId),
        eq(prisesPlanifiees.statut, 'prevue'),
        gte(prisesPlanifiees.datetimePrevue, now),
        isNull(prisesPlanifiees.deletedAt),
      ),
    )
    .returning({ id: prisesPlanifiees.id });
  return result.length;
}
