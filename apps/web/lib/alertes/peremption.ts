// Cron quotidien : alertes de péremption à J-30 et J-7 (#143).
//
// Contrat : on génère AU PLUS UNE alerte par (user, boite, type). Si le
// cron passe deux fois le même jour, ou si l'utilisateur a déjà reçu
// l'alerte 30j hier et qu'on repasse aujourd'hui, on ne crée pas de
// doublon.
//
// Destinataires : le `proprietaire` de l'officine + tous les partages
// `owner|editor` actifs (pas les viewers — ils ne peuvent pas agir
// dessus).
//
// Le cron est exposé via `app/api/v1/cron/peremption/route.ts`. Pour
// tester sans cron réel, on appelle `runPeremptionCron(db, today)`
// directement avec une date contrôlée.
import { alertes, boites, officines, partages, type Db } from '@piloo/db-schema';
import { and, eq, exists, inArray, isNull, lte, ne, not, or, sql } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

export type PeremptionAlerteType = 'peremption_30j' | 'peremption_7j';

export interface PeremptionCronResult {
  candidates: number; // boîtes éligibles toutes thresholds confondues
  alertsCreated: number;
}

/// Exécute le scan complet pour la date `today` (par défaut now).
/// Retourne le nombre de boîtes inspectées et d'alertes créées.
export async function runPeremptionCron(
  db: Db,
  today: Date = new Date(),
): Promise<PeremptionCronResult> {
  const isoToday = isoDate(today);
  const iso30 = isoDate(addDays(today, 30));
  const iso7 = isoDate(addDays(today, 7));

  let alertsCreated = 0;
  let candidates = 0;

  // 30j d'abord, puis 7j. L'ordre n'a pas d'importance fonctionnelle
  // (les deux types coexistent par boîte), mais il rend les logs plus
  // lisibles.
  alertsCreated += await scanThreshold(db, 'peremption_30j', isoToday, iso30, (n) => {
    candidates += n;
  });
  alertsCreated += await scanThreshold(db, 'peremption_7j', isoToday, iso7, (n) => {
    candidates += n;
  });

  log.info('cron.peremption.done', { candidates, alertsCreated });
  return { candidates, alertsCreated };
}

async function scanThreshold(
  db: Db,
  type: PeremptionAlerteType,
  isoToday: string,
  isoLimit: string,
  onCandidates: (n: number) => void,
): Promise<number> {
  // Boîtes encore actives (statut != perimee, deletedAt null) dont la
  // péremption tombe entre aujourd'hui et la limite. On exclut les
  // boîtes déjà périmées car elles relèvent d'un autre flux (tri à
  // la poubelle, hors scope MVP de ce cron).
  const eligibles = await db
    .select({
      boiteId: boites.id,
      officineId: boites.officineId,
      cip13: boites.cip13,
      peremption: boites.peremption,
    })
    .from(boites)
    .where(
      and(
        isNull(boites.deletedAt),
        ne(boites.statut, 'perimee'),
        lte(boites.peremption, isoLimit),
        // peremption >= aujourd'hui (sinon c'est déjà périmé)
        sql`${boites.peremption} >= ${isoToday}`,
      ),
    );
  onCandidates(eligibles.length);
  if (eligibles.length === 0) return 0;

  let created = 0;
  for (const b of eligibles) {
    // Destinataires : owner officine + partages owner/editor actifs.
    const recipients = await getRecipients(db, b.officineId);
    if (recipients.length === 0) continue;

    // Idempotence : on évite de recréer si une alerte (officine,
    // type, boite_id) existe déjà pour le même user.
    const existing = await db
      .select({ userId: alertes.userId })
      .from(alertes)
      .where(
        and(
          eq(alertes.officineId, b.officineId),
          eq(alertes.type, type),
          isNull(alertes.deletedAt),
          inArray(alertes.userId, recipients),
          sql`${alertes.payload}->>'boite_id' = ${b.boiteId}`,
        ),
      );
    const alreadyAlerted = new Set(existing.map((r) => r.userId));
    const toAlert = recipients.filter((u) => !alreadyAlerted.has(u));
    if (toAlert.length === 0) continue;

    await db.insert(alertes).values(
      toAlert.map((userId) => ({
        officineId: b.officineId,
        userId,
        type,
        payload: {
          boite_id: b.boiteId,
          cip13: b.cip13,
          peremption: b.peremption,
        },
      })),
    );
    created += toAlert.length;
  }
  return created;
}

async function getRecipients(db: Db, officineId: string): Promise<string[]> {
  // Owner explicite + partages actifs en rôles owner/editor (le
  // proprietaireUserId peut ou non avoir un partage explicite — on
  // dédoublonne via Set).
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

function addDays(d: Date, days: number): Date {
  const copy = new Date(d);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function isoDate(d: Date): string {
  // Format YYYY-MM-DD pour matcher la colonne `date` Postgres.
  return d.toISOString().slice(0, 10);
}

// `exists` / `not` / `or` exportés pour le typage d'arguments du
// helper drizzle. Les imports inutilisés sont supprimés par tree-shake.
void exists;
void not;
