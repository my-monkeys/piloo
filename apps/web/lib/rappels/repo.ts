// Repository des rappels rapides (#98). Centralise les queries Drizzle.
// Pattern identique à `boites/repo.ts` : `deleted_at IS NULL` filtré
// partout. Pas de jointure BDPM ici — le nom est snapshotté dans
// `nom_texte` à la création pour rester offline-first et indépendant.
import { rappels, type Rappel, type Db } from '@piloo/db-schema';
import { and, desc, eq, isNull } from 'drizzle-orm';

export async function listRappelsByOfficine(db: Db, officineId: string): Promise<Rappel[]> {
  return db
    .select()
    .from(rappels)
    .where(and(eq(rappels.officineId, officineId), isNull(rappels.deletedAt)))
    .orderBy(desc(rappels.createdAt));
}

export async function findRappelById(db: Db, id: string): Promise<Rappel | undefined> {
  const [row] = await db
    .select()
    .from(rappels)
    .where(and(eq(rappels.id, id), isNull(rappels.deletedAt)))
    .limit(1);
  return row;
}

export async function createRappel(
  db: Db,
  input: {
    officineId: string;
    cip13: string;
    nomTexte: string;
    unite: string;
    quantiteMatin: number | null;
    quantiteMidi: number | null;
    quantiteSoir: number | null;
    quantiteCoucher: number | null;
    dateDebut: string;
    dateFin: string | null;
    notes: string | null;
    creeParUserId: string;
  },
): Promise<Rappel> {
  const [row] = await db.insert(rappels).values(input).returning();
  if (!row) throw new Error('createRappel: insert returned no row');
  return row;
}

export async function updateRappel(
  db: Db,
  id: string,
  patch: {
    nomTexte?: string;
    unite?: string;
    quantiteMatin?: number | null;
    quantiteMidi?: number | null;
    quantiteSoir?: number | null;
    quantiteCoucher?: number | null;
    dateDebut?: string;
    dateFin?: string | null;
    actif?: boolean;
    notes?: string | null;
  },
): Promise<Rappel | undefined> {
  if (Object.keys(patch).length === 0) {
    return findRappelById(db, id);
  }
  const [row] = await db
    .update(rappels)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(rappels.id, id), isNull(rappels.deletedAt)))
    .returning();
  return row;
}

export async function softDeleteRappel(db: Db, id: string): Promise<boolean> {
  const [row] = await db
    .update(rappels)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(rappels.id, id), isNull(rappels.deletedAt)))
    .returning({ id: rappels.id });
  return Boolean(row);
}
