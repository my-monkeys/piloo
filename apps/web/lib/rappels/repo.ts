// Repository des rappels (#327). Toutes les queries sont scopées
// au user_id du caller — un user ne voit que ses rappels.
import { rappels, type Db, type Rappel } from '@piloo/db-schema';
import { and, desc, eq, isNull } from 'drizzle-orm';

export interface CreateRappelParams {
  userId: string;
  label: string;
  heure: string; // HH:MM:SS
  officineId?: string | null;
  boiteId?: string | null;
  recurrenceType?: 'daily';
  notes?: string | null;
}

export async function listRappelsForUser(db: Db, userId: string): Promise<Rappel[]> {
  return db
    .select()
    .from(rappels)
    .where(and(eq(rappels.userId, userId), isNull(rappels.deletedAt)))
    .orderBy(desc(rappels.createdAt));
}

export async function getRappelForUser(
  db: Db,
  params: { userId: string; rappelId: string },
): Promise<Rappel | null> {
  const [row] = await db
    .select()
    .from(rappels)
    .where(
      and(
        eq(rappels.id, params.rappelId),
        eq(rappels.userId, params.userId),
        isNull(rappels.deletedAt),
      ),
    )
    .limit(1);
  return row ?? null;
}

export async function createRappel(db: Db, params: CreateRappelParams): Promise<Rappel> {
  const [row] = await db
    .insert(rappels)
    .values({
      userId: params.userId,
      label: params.label,
      heure: params.heure,
      officineId: params.officineId ?? null,
      boiteId: params.boiteId ?? null,
      recurrenceType: params.recurrenceType ?? 'daily',
      notes: params.notes ?? null,
    })
    .returning();
  if (!row) throw new Error('createRappel: insert returned no row');
  return row;
}

export interface UpdateRappelPatch {
  label?: string;
  heure?: string;
  actif?: boolean;
  boiteId?: string | null;
  notes?: string | null;
}

export async function updateRappelForUser(
  db: Db,
  params: { userId: string; rappelId: string; patch: UpdateRappelPatch },
): Promise<Rappel | null> {
  const now = new Date();
  const patch = params.patch;
  if (Object.keys(patch).length === 0) {
    // Pas de changement → renvoie la row courante (no-op).
    return getRappelForUser(db, { userId: params.userId, rappelId: params.rappelId });
  }
  const [row] = await db
    .update(rappels)
    .set({
      ...(patch.label !== undefined ? { label: patch.label } : {}),
      ...(patch.heure !== undefined ? { heure: patch.heure } : {}),
      ...(patch.actif !== undefined ? { actif: patch.actif } : {}),
      ...(patch.boiteId !== undefined ? { boiteId: patch.boiteId } : {}),
      ...(patch.notes !== undefined ? { notes: patch.notes } : {}),
      updatedAt: now,
    })
    .where(
      and(
        eq(rappels.id, params.rappelId),
        eq(rappels.userId, params.userId),
        isNull(rappels.deletedAt),
      ),
    )
    .returning();
  return row ?? null;
}

export async function softDeleteRappelForUser(
  db: Db,
  params: { userId: string; rappelId: string },
): Promise<boolean> {
  const now = new Date();
  const [row] = await db
    .update(rappels)
    .set({ deletedAt: now, updatedAt: now })
    .where(
      and(
        eq(rappels.id, params.rappelId),
        eq(rappels.userId, params.userId),
        isNull(rappels.deletedAt),
      ),
    )
    .returning({ id: rappels.id });
  return Boolean(row);
}
