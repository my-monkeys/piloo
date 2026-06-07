// apps/web/lib/rappels/reconcile.ts
// Réconciliation des prises_planifiees lors de la gestion d'un rappel
// (pause / édition / suppression). Mirror de cancelFuturePrises côté rappels.
import { prisesPlanifiees, rappels, type Db, type Rappel } from '@piloo/db-schema';
import { and, eq, gte, isNull } from 'drizzle-orm';

import { generatePrisesForRappel } from '@/lib/prises/generate';

/** Fenêtre initiale de génération inline (jours). Identique au POST. */
export const INITIAL_WINDOW_DAYS = 30;

/** Soft-delete les prises `prevue` futures (datetime >= now) d'un rappel.
 *  Les prises passées ou déjà `prise`/`sautee` sont préservées (historique). */
export async function cancelFutureRappelPrises(
  db: Db,
  rappelId: string,
  now: Date = new Date(),
): Promise<number> {
  const result = await db
    .update(prisesPlanifiees)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(prisesPlanifiees.rappelId, rappelId),
        eq(prisesPlanifiees.statut, 'prevue'),
        gte(prisesPlanifiees.datetimePrevue, now),
        isNull(prisesPlanifiees.deletedAt),
      ),
    )
    .returning({ id: prisesPlanifiees.id });
  return result.length;
}

/** Calcule (pur) les prises de la fenêtre initiale — extrait du POST. */
export function buildInitialRappelPrises(rappel: Rappel, now: Date = new Date()) {
  const todayUtc = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const debutUtc = new Date(`${rappel.dateDebut}T00:00:00.000Z`);
  const windowStart = debutUtc.getTime() > todayUtc.getTime() ? debutUtc : todayUtc;
  let windowDays = INITIAL_WINDOW_DAYS;
  if (rappel.dateFin) {
    const finUtc = new Date(`${rappel.dateFin}T00:00:00.000Z`);
    const remaining = Math.floor((finUtc.getTime() - windowStart.getTime()) / 86_400_000) + 1;
    if (remaining < windowDays) windowDays = Math.max(0, remaining);
  }
  if (windowDays <= 0) return [];
  return generatePrisesForRappel(rappel, {
    officineId: rappel.officineId,
    windowStart,
    windowDays,
  });
}

/** Régénère les prises de la fenêtre initiale pour un rappel actif.
 *  N'efface PAS l'existant — le caller appelle cancelFutureRappelPrises avant
 *  si nécessaire. Retourne le nombre de prises insérées. */
export async function regenerateRappelPrises(
  db: Db,
  rappelId: string,
  now: Date = new Date(),
): Promise<number> {
  const [rappel] = await db.select().from(rappels).where(eq(rappels.id, rappelId)).limit(1);
  if (!rappel || rappel.deletedAt || !rappel.actif) return 0;
  const prises = buildInitialRappelPrises(rappel, now);
  if (prises.length === 0) return 0;
  await db.insert(prisesPlanifiees).values(prises);
  return prises.length;
}
