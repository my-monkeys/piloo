// Backfill one-shot des prises futures après passage au fuseau par officine
// (#363). Pour chaque rappel actif, on annule les prises `prevue` futures et
// on les régénère — `regenerateRappelPrises` utilise désormais le fuseau de
// l'officine, donc les instants recalculés sont corrects. Les prises passées
// ou validées (prise/sautée/oubliée) ne sont pas touchées (historique).
//
// Idempotent : un re-run ne régénère que ce qui existe encore comme `prevue`
// future. Les prescriptions "à vie" se recalibrent via le cron génération-
// glissante (générateur déjà TZ-aware) ; ce backfill cible les rappels, seule
// source de prises créée inline aujourd'hui.
import { rappels, type Db } from '@piloo/db-schema';
import { and, eq, isNull } from 'drizzle-orm';

import { cancelFutureRappelPrises, regenerateRappelPrises } from '@/lib/rappels/reconcile';

export interface BackfillResult {
  /** Nombre de rappels actifs inspectés. */
  rappels: number;
  /** Nombre total de prises régénérées. */
  prisesRegenerated: number;
}

export async function runBackfillPrisesTimezone(
  db: Db,
  now: Date = new Date(),
): Promise<BackfillResult> {
  const actifs = await db
    .select({ id: rappels.id })
    .from(rappels)
    .where(and(eq(rappels.actif, true), isNull(rappels.deletedAt)));

  let prisesRegenerated = 0;
  for (const { id } of actifs) {
    await cancelFutureRappelPrises(db, id, now);
    prisesRegenerated += await regenerateRappelPrises(db, id, now);
  }
  return { rappels: actifs.length, prisesRegenerated };
}
