// Construction de la réponse pull (#93).
//
// Stratégie :
//  1. Lister les officines accessibles via partages (cf. requireAuth +
//     `partages` actifs).
//  2. Pour chaque entité gérée (POC : boîtes uniquement), filtrer par
//     `officine_id IN (...)` AND `updated_at > since`.
//  3. Séparer les soft-deleted (`deleted_at IS NOT NULL`) en `deleted[]`,
//     les autres dans `entities[]`.
//
// Limite : on n'implémente pas encore le cursor (next_cursor). Le
// paramètre `limit` est appliqué par entité ; les retries client se font
// via un `since` plus récent au passage suivant.
import { boites, partages, type Db } from '@piloo/db-schema';
import { and, eq, gt, inArray, isNotNull, isNull } from 'drizzle-orm';

import { serializeBoite } from '@/lib/boites/serialize';

interface BuildPullArgs {
  db: Db;
  userId: string;
  since: Date | null;
  limit: number;
}

export async function buildPullResponse({ db, userId, since, limit }: BuildPullArgs): Promise<{
  entities: { boites: ReturnType<typeof serializeBoite>[] };
  deleted: { boites: string[] };
  serverTime: string;
}> {
  // 1. Officines accessibles
  const officineRows = await db
    .select({ officineId: partages.officineId })
    .from(partages)
    .where(and(eq(partages.userId, userId), isNull(partages.deletedAt)));
  const officineIds = officineRows.map((r) => r.officineId);

  if (officineIds.length === 0) {
    return {
      entities: { boites: [] },
      deleted: { boites: [] },
      serverTime: new Date().toISOString(),
    };
  }

  // 2 + 3. Boîtes (alives + soft-deleted) avec filtre updated_at
  const boitesRows = await db
    .select()
    .from(boites)
    .where(
      and(inArray(boites.officineId, officineIds), ...(since ? [gt(boites.updatedAt, since)] : [])),
    )
    .limit(limit);

  // Pour les soft-deleted, le client n'a besoin que de l'id.
  const deletedBoitesRows = await db
    .select({ id: boites.id })
    .from(boites)
    .where(
      and(
        inArray(boites.officineId, officineIds),
        isNotNull(boites.deletedAt),
        ...(since ? [gt(boites.updatedAt, since)] : []),
      ),
    )
    .limit(limit);

  const deletedIds = new Set(deletedBoitesRows.map((r) => r.id));
  const aliveBoites = boitesRows.filter((b) => !deletedIds.has(b.id));

  return {
    entities: { boites: aliveBoites.map(serializeBoite) },
    deleted: { boites: Array.from(deletedIds) },
    serverTime: new Date().toISOString(),
  };
}
