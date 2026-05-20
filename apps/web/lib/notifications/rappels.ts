// Scheduler rappels prises (#126).
//
// Tourne en cron (cf. apps/web/vercel.json). À chaque run :
//   1. Sélectionne les prises_planifiees dont datetime_prevue est
//      dans la fenêtre [now + leadMin, now + leadMin + windowMin),
//      statut='prevue', notified_at IS NULL, non soft-deleted.
//   2. Pour chaque prise : trouve les destinataires (owner + editors
//      du partage de l'officine — pas les viewers, ils n'agissent
//      pas), récupère leurs devices, envoie le push via fcm.ts.
//   3. UPDATE notified_at = now() pour éviter le double-fire au
//      prochain run.
//
// Idempotence : `notified_at IS NULL` dans le WHERE de la sélection.
// Si le cron crashe entre l'envoi FCM et l'UPDATE, on peut re-envoyer
// au prochain run — c'est un trade-off accepté (vaut mieux re-push
// qu'oublier).
import { devices, partages, prescriptions, prisesPlanifiees, type Db } from '@piloo/db-schema';
import { and, eq, gte, inArray, isNull, lt, or } from 'drizzle-orm';

import { log } from '@/lib/server/logger';
import { sendPushBatch, type PushTarget } from './fcm';

export interface RappelsCronOptions {
  /** Délai entre maintenant et la prise (en minutes). Défaut 5. */
  leadMinutes?: number;
  /** Taille de la fenêtre à scanner (en minutes). Défaut 5. */
  windowMinutes?: number;
  /** Override `now` (pour les tests). */
  now?: Date;
}

export interface RappelsCronResult {
  /** Nombre de prises trouvées dans la fenêtre. */
  candidates: number;
  /** Nombre de prises pour lesquelles au moins un push a été envoyé. */
  notified: number;
  /** Total de tokens envoyés (un user peut avoir N devices). */
  pushSent: number;
  /** Total d'erreurs FCM (tokens invalides à nettoyer côté #122). */
  pushFailed: number;
}

export async function runRappelsCron(
  db: Db,
  opts: RappelsCronOptions = {},
): Promise<RappelsCronResult> {
  const leadMs = (opts.leadMinutes ?? 5) * 60 * 1000;
  const windowMs = (opts.windowMinutes ?? 5) * 60 * 1000;
  const now = opts.now ?? new Date();
  const windowStart = new Date(now.getTime() + leadMs);
  const windowEnd = new Date(windowStart.getTime() + windowMs);

  // 1. Prises candidates jointes à leur prescription (pour le titre push).
  const candidates = await db
    .select({
      priseId: prisesPlanifiees.id,
      officineId: prisesPlanifiees.officineId,
      datetimePrevue: prisesPlanifiees.datetimePrevue,
      nomTexte: prescriptions.nomTexte,
    })
    .from(prisesPlanifiees)
    .innerJoin(prescriptions, eq(prisesPlanifiees.prescriptionId, prescriptions.id))
    .where(
      and(
        eq(prisesPlanifiees.statut, 'prevue'),
        gte(prisesPlanifiees.datetimePrevue, windowStart),
        lt(prisesPlanifiees.datetimePrevue, windowEnd),
        isNull(prisesPlanifiees.notifiedAt),
        isNull(prisesPlanifiees.deletedAt),
      ),
    );

  if (candidates.length === 0) {
    log.info('cron.rappels.no_candidates', {
      windowStart: windowStart.toISOString(),
      windowEnd: windowEnd.toISOString(),
    });
    return { candidates: 0, notified: 0, pushSent: 0, pushFailed: 0 };
  }

  // 2. Pour chaque officine concernée, trouve owner + editors + leurs devices.
  const officineIds = [...new Set(candidates.map((c) => c.officineId))];
  const recipients = await db
    .select({
      officineId: partages.officineId,
      userId: partages.userId,
    })
    .from(partages)
    .where(
      and(
        inArray(partages.officineId, officineIds),
        or(eq(partages.role, 'owner'), eq(partages.role, 'editor')),
        isNull(partages.deletedAt),
      ),
    );

  const userIdsByOfficine = new Map<string, Set<string>>();
  for (const r of recipients) {
    const set = userIdsByOfficine.get(r.officineId) ?? new Set<string>();
    set.add(r.userId);
    userIdsByOfficine.set(r.officineId, set);
  }
  const allUserIds = [...new Set(recipients.map((r) => r.userId))];

  const deviceRows =
    allUserIds.length === 0
      ? []
      : await db
          .select({
            userId: devices.userId,
            token: devices.token,
            platform: devices.platform,
          })
          .from(devices)
          .where(and(inArray(devices.userId, allUserIds), isNull(devices.deletedAt)));

  const devicesByUser = new Map<string, PushTarget[]>();
  for (const d of deviceRows) {
    const list = devicesByUser.get(d.userId) ?? [];
    list.push({ token: d.token, platform: d.platform });
    devicesByUser.set(d.userId, list);
  }

  // 3. Envoie + marque notifié.
  let totalSent = 0;
  let totalFailed = 0;
  let notifiedCount = 0;
  const notifiedIds: string[] = [];

  for (const c of candidates) {
    const userIds = userIdsByOfficine.get(c.officineId) ?? new Set<string>();
    const targets: PushTarget[] = [];
    for (const uid of userIds) {
      targets.push(...(devicesByUser.get(uid) ?? []));
    }
    if (targets.length === 0) {
      // Personne à notifier — on marque quand même `notified_at` pour
      // ne pas re-scanner cette prise à chaque cron (no-op stable).
      notifiedIds.push(c.priseId);
      continue;
    }
    const result = await sendPushBatch(targets, {
      title: 'Rappel de prise',
      body: `${c.nomTexte} dans ${String(opts.leadMinutes ?? 5)} min`,
      data: { type: 'prise_rappel', priseId: c.priseId },
    });
    totalSent += result.sent;
    totalFailed += result.failed;
    notifiedIds.push(c.priseId);
    if (result.sent > 0) notifiedCount++;
  }

  if (notifiedIds.length > 0) {
    await db
      .update(prisesPlanifiees)
      .set({ notifiedAt: now, updatedAt: now })
      .where(inArray(prisesPlanifiees.id, notifiedIds));
  }

  log.info('cron.rappels.done', {
    candidates: candidates.length,
    notified: notifiedCount,
    pushSent: totalSent,
    pushFailed: totalFailed,
  });

  return {
    candidates: candidates.length,
    notified: notifiedCount,
    pushSent: totalSent,
    pushFailed: totalFailed,
  };
}
