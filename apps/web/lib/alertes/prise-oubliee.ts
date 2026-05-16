// Cron : flip prevue → oubliee + alerte prise_oubliee (#118).
//
// Règle métier : une prise reste `prevue` jusqu'à 1h après son heure
// prévue. Au-delà, on la flag `oubliee` et on crée une alerte pour les
// recipients de l'officine (proprio + partages owner|editor — les
// viewers ne peuvent pas agir donc on ne les sollicite pas).
//
// Idempotence : si le cron passe plusieurs fois, on ne re-crée pas
// d'alerte pour une prise déjà flaggée. L'update SQL `WHERE statut =
// 'prevue'` garantit aussi qu'on ne re-flag pas une prise que
// l'utilisateur a marqué entre-temps `prise` ou `sautee`.
//
// Notifs push/email : le ticket fournit l'AC "Trigger email/push si
// activé". Le pipeline FCM (#122) et Brevo (#16/#17) ne sont pas encore
// branchés — pour l'instant on log l'event ; les notifs seront envoyées
// par un worker qui pollera les alertes non-lues quand ces stacks
// seront prêtes.
import {
  alertes,
  officines,
  partages,
  prescriptions,
  prisesPlanifiees,
  type Db,
} from '@piloo/db-schema';
import { and, eq, inArray, isNull, lt, or, sql } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

export interface OublieeCronResult {
  /** Nombre de prises éligibles (statut prevue + datetime_prevue < cutoff). */
  candidates: number;
  /** Nombre de prises effectivement passées à `oubliee`. */
  transitioned: number;
  /** Nombre d'alertes prise_oubliee créées (somme sur tous les destinataires). */
  alertsCreated: number;
}

/** Grace period entre `datetime_prevue` et flip `oubliee`. Voir AC #118. */
const GRACE_MS = 60 * 60 * 1000;

export async function runPriseOublieeCron(
  db: Db,
  now: Date = new Date(),
): Promise<OublieeCronResult> {
  const cutoff = new Date(now.getTime() - GRACE_MS);

  // 1. Sélection des candidats AVANT mutation (besoin des IDs +
  //    données dénormalisées pour les payloads d'alerte).
  const candidates = await db
    .select({
      priseId: prisesPlanifiees.id,
      officineId: prisesPlanifiees.officineId,
      prescriptionId: prisesPlanifiees.prescriptionId,
      datetimePrevue: prisesPlanifiees.datetimePrevue,
      nomTexte: prescriptions.nomTexte,
    })
    .from(prisesPlanifiees)
    .innerJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .where(
      and(
        eq(prisesPlanifiees.statut, 'prevue'),
        lt(prisesPlanifiees.datetimePrevue, cutoff),
        isNull(prisesPlanifiees.deletedAt),
        isNull(prescriptions.deletedAt),
      ),
    );

  if (candidates.length === 0) {
    log.info('cron.prise_oubliee.done', { candidates: 0, transitioned: 0, alertsCreated: 0 });
    return { candidates: 0, transitioned: 0, alertsCreated: 0 };
  }

  // 2. Flip atomique vers `oubliee`. Le filtre `statut = 'prevue'`
  //    protège des races : si un user a marqué la prise entre-temps,
  //    l'update ignore cette ligne.
  const candidateIds = candidates.map((c) => c.priseId);
  const transitioned = await db
    .update(prisesPlanifiees)
    .set({ statut: 'oubliee', updatedAt: now })
    .where(
      and(
        inArray(prisesPlanifiees.id, candidateIds),
        eq(prisesPlanifiees.statut, 'prevue'),
        isNull(prisesPlanifiees.deletedAt),
      ),
    )
    .returning({ id: prisesPlanifiees.id });
  const transitionedSet = new Set(transitioned.map((r) => r.id));

  // 3. Pour chaque prise transitée → 1 alerte par destinataire (avec
  //    dedup sur les éventuels reruns).
  let alertsCreated = 0;
  for (const c of candidates) {
    if (!transitionedSet.has(c.priseId)) continue;

    const recipients = await getRecipients(db, c.officineId);
    if (recipients.length === 0) continue;

    // Dédup au niveau (officine, type, prise) × user — pattern aligné
    // sur peremption.ts qui filtre via `payload->>'boite_id'`.
    const existing = await db
      .select({ userId: alertes.userId })
      .from(alertes)
      .where(
        and(
          eq(alertes.officineId, c.officineId),
          eq(alertes.type, 'prise_oubliee'),
          isNull(alertes.deletedAt),
          inArray(alertes.userId, recipients),
          sql`${alertes.payload}->>'prise_id' = ${c.priseId}`,
        ),
      );
    const alreadyAlerted = new Set(existing.map((r) => r.userId));
    const toAlert = recipients.filter((u) => !alreadyAlerted.has(u));
    if (toAlert.length === 0) continue;

    await db.insert(alertes).values(
      toAlert.map((userId) => ({
        officineId: c.officineId,
        userId,
        type: 'prise_oubliee' as const,
        payload: {
          prise_id: c.priseId,
          prescription_id: c.prescriptionId,
          nom_texte: c.nomTexte,
          datetime_prevue: c.datetimePrevue.toISOString(),
        },
      })),
    );
    alertsCreated += toAlert.length;
  }

  log.info('cron.prise_oubliee.done', {
    candidates: candidates.length,
    transitioned: transitionedSet.size,
    alertsCreated,
  });
  return {
    candidates: candidates.length,
    transitioned: transitionedSet.size,
    alertsCreated,
  };
}

async function getRecipients(db: Db, officineId: string): Promise<string[]> {
  // Proprio explicite + partages actifs owner/editor. Les viewers ne
  // reçoivent pas — ils ne peuvent pas agir sur la prise oubliée.
  const [officineRow] = await db
    .select({ proprietaireUserId: officines.proprietaireUserId })
    .from(officines)
    .where(and(eq(officines.id, officineId), isNull(officines.deletedAt)))
    .limit(1);
  if (!officineRow) return [];

  const partageRows = await db
    .select({ userId: partages.userId })
    .from(partages)
    .where(
      and(
        eq(partages.officineId, officineId),
        isNull(partages.deletedAt),
        or(eq(partages.role, 'owner'), eq(partages.role, 'editor')),
      ),
    );

  const set = new Set<string>([officineRow.proprietaireUserId]);
  for (const p of partageRows) set.add(p.userId);
  return [...set];
}
