// Cron : alerte stock_bas quand un médicament prescrit a moins de
// 7 jours estimés de stock restant (#145).
//
// Algorithme par prescription (NB : pas par cip13, car la posologie
// vit côté prescription) :
//   1. Pour chaque prescription active d'une officine :
//      - Si frequence == 'a_la_demande' → skip (pas de signal de
//        consommation prévisible).
//      - Calcule la conso quotidienne : `unitesParPrise * (moments|1)`,
//        divisée par 7 si hebdomadaire.
//      - Si conso == 0 → skip.
//   2. Cherche les boîtes actives (statut='active') de la même cip13
//      dans la même officine. Total stock = somme `unites_restantes`
//      (ignore les boîtes sans stock renseigné — null).
//   3. days_remaining = totalStock / dailyConsumption.
//   4. Si days_remaining < 7 → alerte aux owner+editor de l'officine.
//
// Idempotence : dédup via `payload->>'prescription_id'` — un seul
// alerte (officine, type, prescription) × user par cycle de stock.
// Quand l'utilisateur réapprovisionne (ajoute une boîte → days passe
// au-dessus de 7), aucune alerte active n'est créée. Quand on
// redescend sous 7, le dédup empêche un re-flag tant que l'ancien
// alerte n'est pas lu+archivé — sera affiné quand on aura une logique
// "alert closed" plus fine (suit #17 alertes système).
import {
  alertes,
  boites,
  officines,
  partages,
  prescriptions,
  type Db,
  type Prescription,
} from '@piloo/db-schema';
import { and, eq, inArray, isNull, or, sql } from 'drizzle-orm';

import { log } from '@/lib/server/logger';

export interface StockBasCronResult {
  /** Nombre de prescriptions inspectées (avec conso prédictible). */
  candidates: number;
  /** Nombre passant sous le seuil 7 jours. */
  lowStock: number;
  /** Alertes créées (somme sur destinataires, après dédup). */
  alertsCreated: number;
}

/** Seuil sous lequel on alerte. Exprimé en jours. */
const THRESHOLD_DAYS = 7;

interface PosologieShape {
  unitesParPrise?: number;
  frequence?: 'quotidien' | 'hebdomadaire' | 'a_la_demande';
  moments?: readonly string[];
}

/**
 * Calcule la conso quotidienne d'une prescription. Retourne 0 si
 * `a_la_demande` ou posologie incomplète → l'appelant skippe.
 */
export function dailyConsumption(posologie: unknown): number {
  if (typeof posologie !== 'object' || posologie === null) return 0;
  const p = posologie as PosologieShape;
  if (p.frequence === 'a_la_demande' || !p.frequence) return 0;
  const unitsPerPrise = p.unitesParPrise ?? 0;
  if (unitsPerPrise <= 0) return 0;
  // `moments` absent ou vide = 1 prise/cycle (cycle = jour ou semaine).
  const momentsLen = p.moments?.length ?? 0;
  const prisesPerCycle = momentsLen > 0 ? momentsLen : 1;
  const unitsPerCycle = unitsPerPrise * prisesPerCycle;
  if (p.frequence === 'hebdomadaire') return unitsPerCycle / 7;
  return unitsPerCycle;
}

export async function runStockBasCron(db: Db): Promise<StockBasCronResult> {
  // 1. Toutes les prescriptions actives, avec leur officine (via
  //    ordonnance.officineId). On JOIN ordonnances pour récupérer
  //    officine_id.
  const prescs = await db
    .select({
      prescription: prescriptions,
      officineId: sql<string>`ordonnances.officine_id`,
    })
    .from(prescriptions)
    .innerJoin(
      sql`ordonnances`,
      sql`ordonnances.id = ${prescriptions.ordonnanceId} AND ordonnances.deleted_at IS NULL`,
    )
    .where(and(isNull(prescriptions.deletedAt)));

  let candidates = 0;
  let lowStock = 0;
  let alertsCreated = 0;

  for (const row of prescs) {
    const conso = dailyConsumption(row.prescription.posologie);
    if (conso === 0) continue;
    candidates += 1;

    const cip13 = row.prescription.cip13;
    if (!cip13) continue; // sans cip13 on ne peut pas matcher de boîte

    // Stock total des boîtes actives matchant la cip13 dans la même officine.
    const stockRows = await db
      .select({
        sum: sql<string>`COALESCE(SUM(${boites.unitesRestantes}), 0)::text`,
      })
      .from(boites)
      .where(
        and(
          eq(boites.officineId, row.officineId),
          eq(boites.cip13, cip13),
          eq(boites.statut, 'active'),
          isNull(boites.deletedAt),
        ),
      );
    const totalStock = Number(stockRows[0]?.sum ?? '0');
    if (totalStock <= 0) continue; // pas de boîte, pas d'estimation utile

    const daysRemaining = totalStock / conso;
    if (daysRemaining >= THRESHOLD_DAYS) continue;
    lowStock += 1;

    alertsCreated += await emitAlertes(db, {
      officineId: row.officineId,
      prescription: row.prescription,
      totalStock,
      daysRemaining: Math.floor(daysRemaining),
    });
  }

  log.info('cron.stock_bas.done', { candidates, lowStock, alertsCreated });
  return { candidates, lowStock, alertsCreated };
}

interface EmitParams {
  officineId: string;
  prescription: Prescription;
  totalStock: number;
  daysRemaining: number;
}

async function emitAlertes(db: Db, params: EmitParams): Promise<number> {
  const recipients = await getRecipients(db, params.officineId);
  if (recipients.length === 0) return 0;

  // Dédup par (officine, type, prescription_id) × user.
  const existing = await db
    .select({ userId: alertes.userId })
    .from(alertes)
    .where(
      and(
        eq(alertes.officineId, params.officineId),
        eq(alertes.type, 'stock_bas'),
        isNull(alertes.deletedAt),
        inArray(alertes.userId, recipients),
        sql`${alertes.payload}->>'prescription_id' = ${params.prescription.id}`,
      ),
    );
  const alerted = new Set(existing.map((r) => r.userId));
  const toAlert = recipients.filter((u) => !alerted.has(u));
  if (toAlert.length === 0) return 0;

  await db.insert(alertes).values(
    toAlert.map((userId) => ({
      officineId: params.officineId,
      userId,
      type: 'stock_bas' as const,
      payload: {
        prescription_id: params.prescription.id,
        cip13: params.prescription.cip13,
        nom_texte: params.prescription.nomTexte,
        total_stock: params.totalStock,
        days_remaining: params.daysRemaining,
      },
    })),
  );
  return toAlert.length;
}

async function getRecipients(db: Db, officineId: string): Promise<string[]> {
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
