// Repository des officines (#70). Centralise les queries Drizzle pour
// éviter la duplication entre les handlers GET / POST / PATCH / DELETE.
//
// Toutes les fonctions filtrent `deleted_at IS NULL` (soft delete) et
// joignent `partages` pour l'access control. Si on a besoin de lire une
// officine soft-deleted (ex : restoration), ce sera une fonction dédiée.
import { officines, partages, type Db, type Officine, type Partage } from '@piloo/db-schema';
import { and, desc, eq, isNull } from 'drizzle-orm';

export interface OfficineWithRole extends Officine {
  role: Partage['role'];
}

export async function listAccessibleOfficines(db: Db, userId: string): Promise<OfficineWithRole[]> {
  const rows = await db
    .select({ officine: officines, role: partages.role })
    .from(partages)
    .innerJoin(officines, eq(partages.officineId, officines.id))
    .where(
      and(eq(partages.userId, userId), isNull(partages.deletedAt), isNull(officines.deletedAt)),
    )
    .orderBy(desc(officines.createdAt));

  return rows.map((r) => ({ ...r.officine, role: r.role }));
}

/** Fuseau appliqué si l'officine est introuvable (cohérent avec le défaut DB). */
export const DEFAULT_TIMEZONE = 'Europe/Paris';

/** Lit le fuseau IANA d'une officine (défaut Europe/Paris si absente). #363 */
export async function getOfficineTimezone(db: Db, officineId: string): Promise<string> {
  const [row] = await db
    .select({ timezone: officines.timezone })
    .from(officines)
    .where(eq(officines.id, officineId))
    .limit(1);
  return row?.timezone ?? DEFAULT_TIMEZONE;
}

export async function findOfficineById(db: Db, officineId: string): Promise<Officine | undefined> {
  const [row] = await db
    .select()
    .from(officines)
    .where(and(eq(officines.id, officineId), isNull(officines.deletedAt)))
    .limit(1);
  return row;
}

export async function createOfficineWithOwner(
  db: Db,
  input: {
    nom: string;
    type: 'perso' | 'patient';
    dateNaissance: string | null;
    notes: string | null;
    proprietaireUserId: string;
    /** Fuseau IANA (#363). Omis → défaut DB Europe/Paris. */
    timezone?: string;
  },
): Promise<Officine> {
  return db.transaction(async (tx) => {
    const [officine] = await tx
      .insert(officines)
      .values({
        nom: input.nom,
        type: input.type,
        dateNaissance: input.dateNaissance,
        notes: input.notes,
        proprietaireUserId: input.proprietaireUserId,
        // undefined → drizzle omet la colonne → DEFAULT 'Europe/Paris'.
        ...(input.timezone !== undefined && { timezone: input.timezone }),
      })
      .returning();
    if (!officine) {
      throw new Error('createOfficineWithOwner: officines insert returned no row');
    }
    await tx.insert(partages).values({
      officineId: officine.id,
      userId: input.proprietaireUserId,
      role: 'owner',
      invitedAt: new Date(),
      acceptedAt: new Date(),
    });
    return officine;
  });
}

export async function updateOfficine(
  db: Db,
  officineId: string,
  patch: { nom?: string; dateNaissance?: string | null; notes?: string | null; timezone?: string },
): Promise<Officine | undefined> {
  if (Object.keys(patch).length === 0) {
    return findOfficineById(db, officineId);
  }
  const [row] = await db
    .update(officines)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(officines.id, officineId), isNull(officines.deletedAt)))
    .returning();
  return row;
}

export async function softDeleteOfficine(db: Db, officineId: string): Promise<boolean> {
  const [row] = await db
    .update(officines)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(officines.id, officineId), isNull(officines.deletedAt)))
    .returning({ id: officines.id });
  return Boolean(row);
}
