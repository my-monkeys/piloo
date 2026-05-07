// Construction de la réponse pull (#93).
//
// Stratégie :
//  1. Lister les officines accessibles via partages.
//  2. Filtrer les boîtes par `officine_id IN (...)` AND `updated_at > since`
//     (si fourni) AND `id > cursor` (si fourni).
//  3. Séparer les soft-deleted en `deleted[]`, les autres dans `entities[]`.
//
// Pagination cursor (ID-only) :
//  - L'ordre est `ORDER BY id ASC` — déterministe, indexé via PK.
//  - On n'ordonne PAS par updated_at à cause d'un piège de précision :
//    Postgres stocke `updated_at` en microsecondes, JS Date en
//    millisecondes ; un cursor (updated_at, id) sérialisé via toISOString()
//    perd les microsecondes et fait re-matcher la dernière ligne au
//    passage suivant ("> cursor.updated_at" reste vrai côté DB).
//  - Le client passe `cursor=base64url({id})` jusqu'à `next_cursor=null`.
//  - L'ordre `id ASC` n'est pas chronologique mais c'est sans
//    conséquence pour la sync : le client a besoin de TOUTES les
//    modifs depuis `since`, pas dans un ordre particulier.
import { boites, partages, type Db } from '@piloo/db-schema';
import { and, asc, eq, gt, inArray, isNull } from 'drizzle-orm';

import { serializeBoite } from '@/lib/boites/serialize';

interface BuildPullArgs {
  db: Db;
  userId: string;
  since: Date | null;
  cursor: PullCursor | null;
  limit: number;
}

export interface PullCursor {
  id: string;
}

export interface PullResponse {
  entities: { boites: ReturnType<typeof serializeBoite>[] };
  deleted: { boites: string[] };
  serverTime: string;
  nextCursor: string | null;
}

export function encodeCursor(c: PullCursor): string {
  return Buffer.from(JSON.stringify(c), 'utf8').toString('base64url');
}

export function decodeCursor(s: string): PullCursor | null {
  try {
    const json = Buffer.from(s, 'base64url').toString('utf8');
    const parsed = JSON.parse(json) as Partial<PullCursor>;
    if (typeof parsed.id !== 'string') return null;
    return { id: parsed.id };
  } catch {
    return null;
  }
}

export async function buildPullResponse({
  db,
  userId,
  since,
  cursor,
  limit,
}: BuildPullArgs): Promise<PullResponse> {
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
      nextCursor: null,
    };
  }

  const conditions = [inArray(boites.officineId, officineIds)];
  if (since) conditions.push(gt(boites.updatedAt, since));
  if (cursor) conditions.push(gt(boites.id, cursor.id));

  const rows = await db
    .select()
    .from(boites)
    .where(and(...conditions))
    .orderBy(asc(boites.id))
    .limit(limit);

  const aliveBoites = rows.filter((b) => b.deletedAt === null);
  const deletedIds = rows.filter((b) => b.deletedAt !== null).map((b) => b.id);

  const last = rows.at(-1);
  const nextCursor = rows.length === limit && last ? encodeCursor({ id: last.id }) : null;

  return {
    entities: { boites: aliveBoites.map(serializeBoite) },
    deleted: { boites: deletedIds },
    serverTime: new Date().toISOString(),
    nextCursor,
  };
}
