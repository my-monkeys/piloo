// Accès DB pour les alertes (#140).
//
// Pagination cursor-based : le cursor encode `${createdAt}|${id}` en
// base64url pour rester opaque côté client. L'ordre est strict
// (createdAt DESC, id DESC) — déterministe en cas de timestamps égaux.
import { alertes, type Alerte } from '@piloo/db-schema';
import type { Db } from '@piloo/db-schema';
import { and, desc, eq, isNull, lt, or, sql } from 'drizzle-orm';

export interface ListAlertesOptions {
  userId: string;
  limit: number;
  cursor: string | null;
  type: Alerte['type'] | null;
  unreadOnly: boolean;
}

export interface AlertesPage {
  items: Alerte[];
  nextCursor: string | null;
}

export async function listAlertesForUser(db: Db, opts: ListAlertesOptions): Promise<AlertesPage> {
  const conditions = [eq(alertes.userId, opts.userId), isNull(alertes.deletedAt)];

  if (opts.type !== null) {
    conditions.push(eq(alertes.type, opts.type));
  }
  if (opts.unreadOnly) {
    conditions.push(isNull(alertes.lueA));
  }
  if (opts.cursor !== null) {
    const decoded = decodeCursor(opts.cursor);
    if (decoded !== null) {
      // (createdAt < cursor.createdAt) OR (createdAt = cursor.createdAt AND id < cursor.id)
      const cursorCondition = or(
        lt(alertes.createdAt, decoded.createdAt),
        and(eq(alertes.createdAt, decoded.createdAt), lt(alertes.id, decoded.id)),
      );
      if (cursorCondition !== undefined) {
        conditions.push(cursorCondition);
      }
    }
  }

  // On lit limit+1 pour savoir s'il y a une page suivante.
  const rows = await db
    .select()
    .from(alertes)
    .where(and(...conditions))
    .orderBy(desc(alertes.createdAt), desc(alertes.id))
    .limit(opts.limit + 1);

  if (rows.length <= opts.limit) {
    return { items: rows, nextCursor: null };
  }
  const items = rows.slice(0, opts.limit);
  const last = items[items.length - 1];
  return {
    items,
    nextCursor: last ? encodeCursor(last.createdAt, last.id) : null,
  };
}

/// Marque une alerte comme lue (idempotent). Retourne false si l'alerte
/// n'existe pas ou n'appartient pas à l'utilisateur.
export async function markAlerteRead(db: Db, userId: string, alerteId: string): Promise<boolean> {
  const [row] = await db
    .select({ id: alertes.id, lueA: alertes.lueA })
    .from(alertes)
    .where(and(eq(alertes.id, alerteId), eq(alertes.userId, userId), isNull(alertes.deletedAt)))
    .limit(1);
  if (!row) return false;
  if (row.lueA !== null) return true; // déjà lue, idempotent

  await db
    .update(alertes)
    .set({ lueA: sql`now()` })
    .where(eq(alertes.id, alerteId));
  return true;
}

function encodeCursor(createdAt: Date, id: string): string {
  const raw = `${createdAt.toISOString()}|${id}`;
  return Buffer.from(raw, 'utf8').toString('base64url');
}

function decodeCursor(cursor: string): { createdAt: Date; id: string } | null {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const [iso, id] = raw.split('|');
    if (!iso || !id) return null;
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    return { createdAt: d, id };
  } catch {
    return null;
  }
}
