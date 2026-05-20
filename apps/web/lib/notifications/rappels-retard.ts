// Cron rappels prises en retard (#130).
//
// IMPORTANT — fréquence cible : toutes les 15 min pour rattraper
// finement entre +30 min et +1 h après l'heure prévue. Vercel Hobby
// limite les crons au quotidien (l'expression `*/15 * * * *` est
// rejetée). En attendant un upgrade Pro OU un scheduler externe
// (cookie-server cron, GitHub Actions), le cron Vercel tourne juste
// 1× par jour à 12:00 — l'usage réel passe par un curl externe :
//
//   curl -H "Authorization: Bearer $CRON_SECRET" \
//     https://piloo.vercel.app/api/v1/cron/rappels-retard
//
// À chaque run :
//   1. Sélectionne les prises_planifiees dont datetime_prevue est
//      dans la fenêtre [now - 45min, now - 30min[, statut='prevue',
//      late_reminded_at IS NULL, non soft-deleted.
//   2. Push "Tu as oublié ta prise" aux destinataires (mêmes règles
//      que les rappels pré-prise : owner + editors, pas les viewers).
//   3. UPDATE late_reminded_at = now() pour éviter le double-fire.
//
// Distinct du cron `prise-oubliee` (#118) qui flip statut → oubliee
// à +1h : ici on est encore en "rattrapable", la prise reste `prevue`.
//
// Idempotence : `late_reminded_at IS NULL` dans le WHERE. Si le cron
// crashe entre push et UPDATE, double-fire possible au prochain run
// (préférable à un oubli).
import { devices, partages, prescriptions, prisesPlanifiees, type Db } from '@piloo/db-schema';
import { and, eq, gte, inArray, isNull, lt, or } from 'drizzle-orm';

import { log } from '@/lib/server/logger';
import { sendPushBatch, type PushTarget } from './fcm';

export interface RappelsRetardOptions {
  /** Délai minimal après la prise pour déclencher le rappel (minutes). Défaut 30. */
  retardMinutes?: number;
  /** Taille de la fenêtre à scanner (minutes). Défaut 15 (= fréquence cron). */
  windowMinutes?: number;
  /** Override `now` (pour les tests). */
  now?: Date;
}

export interface RappelsRetardResult {
  candidates: number;
  notified: number;
  pushSent: number;
  pushFailed: number;
}

export async function runRappelsRetardCron(
  db: Db,
  opts: RappelsRetardOptions = {},
): Promise<RappelsRetardResult> {
  const retardMs = (opts.retardMinutes ?? 30) * 60 * 1000;
  const windowMs = (opts.windowMinutes ?? 15) * 60 * 1000;
  const now = opts.now ?? new Date();
  // Fenêtre : datetime_prevue ∈ [now - retardMs - windowMs, now - retardMs)
  // = "il y a 30 à 45 min" pour la valeur par défaut.
  const windowEnd = new Date(now.getTime() - retardMs);
  const windowStart = new Date(windowEnd.getTime() - windowMs);

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
        isNull(prisesPlanifiees.lateRemindedAt),
        isNull(prisesPlanifiees.deletedAt),
        isNull(prescriptions.deletedAt),
      ),
    );

  if (candidates.length === 0) {
    log.info('cron.rappels_retard.done', { candidates: 0, notified: 0 });
    return { candidates: 0, notified: 0, pushSent: 0, pushFailed: 0 };
  }

  // Pour chaque candidat : résoudre les destinataires (owner/editor du partage).
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

  const userIds = [...new Set(recipients.map((r) => r.userId))];
  const userDevices =
    userIds.length === 0
      ? []
      : await db
          .select({
            userId: devices.userId,
            token: devices.token,
            platform: devices.platform,
          })
          .from(devices)
          .where(and(inArray(devices.userId, userIds), isNull(devices.deletedAt)));

  // Map userId → devices[]
  const devicesByUser = new Map<string, typeof userDevices>();
  for (const d of userDevices) {
    const list = devicesByUser.get(d.userId) ?? [];
    list.push(d);
    devicesByUser.set(d.userId, list);
  }
  // Map officineId → userIds[]
  const usersByOfficine = new Map<string, string[]>();
  for (const r of recipients) {
    const list = usersByOfficine.get(r.officineId) ?? [];
    list.push(r.userId);
    usersByOfficine.set(r.officineId, list);
  }

  let pushSent = 0;
  let pushFailed = 0;
  let notified = 0;
  for (const c of candidates) {
    const users = usersByOfficine.get(c.officineId) ?? [];
    const targets: PushTarget[] = [];
    for (const uid of users) {
      for (const d of devicesByUser.get(uid) ?? []) {
        targets.push({ token: d.token, platform: d.platform });
      }
    }
    if (targets.length === 0) {
      // Pas de device : on marque quand même late_reminded_at pour
      // ne pas retenter en boucle.
      continue;
    }
    const minutesLate = Math.round((now.getTime() - new Date(c.datetimePrevue).getTime()) / 60000);
    const result = await sendPushBatch(targets, {
      title: 'Prise en retard',
      body: `${c.nomTexte} — prévue il y a ${String(minutesLate)} min. Valide ou saute.`,
      data: { type: 'prise_retard', prise_id: c.priseId },
    });
    pushSent += result.sent;
    pushFailed += result.failed;
    if (result.sent > 0) notified++;
  }

  // Marque tous les candidats comme rappelés — y compris ceux sans
  // device (sinon on retry chaque cron jusqu'au flip oubliee).
  const ids = candidates.map((c) => c.priseId);
  await db
    .update(prisesPlanifiees)
    .set({ lateRemindedAt: now, updatedAt: now })
    .where(inArray(prisesPlanifiees.id, ids));

  log.info('cron.rappels_retard.done', {
    candidates: candidates.length,
    notified,
    pushSent,
    pushFailed,
  });
  return { candidates: candidates.length, notified, pushSent, pushFailed };
}
