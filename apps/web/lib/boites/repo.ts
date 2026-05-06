// Repository des boîtes (#86). Centralise les queries Drizzle.
// Toutes les fonctions filtrent `deleted_at IS NULL`.
import { boites, type Boite, type Db } from '@piloo/db-schema';
import { and, desc, eq, isNull } from 'drizzle-orm';

export async function listBoitesByOfficine(db: Db, officineId: string): Promise<Boite[]> {
  return db
    .select()
    .from(boites)
    .where(and(eq(boites.officineId, officineId), isNull(boites.deletedAt)))
    .orderBy(desc(boites.createdAt));
}

export async function findBoiteById(db: Db, id: string): Promise<Boite | undefined> {
  const [row] = await db
    .select()
    .from(boites)
    .where(and(eq(boites.id, id), isNull(boites.deletedAt)))
    .limit(1);
  return row;
}

export async function createBoite(
  db: Db,
  input: {
    officineId: string;
    cip13: string;
    lot: string | null;
    numeroSerie: string | null;
    peremption: string;
    unitesInitiales: number | null;
    unitesRestantes: number | null;
    notes: string | null;
    ajouteePar: string;
  },
): Promise<Boite> {
  const [row] = await db.insert(boites).values(input).returning();
  if (!row) throw new Error('createBoite: insert returned no row');
  return row;
}

export async function updateBoite(
  db: Db,
  id: string,
  patch: {
    statut?: 'active' | 'vide' | 'perimee';
    unitesRestantes?: number | null;
    notes?: string | null;
  },
): Promise<Boite | undefined> {
  if (Object.keys(patch).length === 0) {
    return findBoiteById(db, id);
  }
  const [row] = await db
    .update(boites)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(boites.id, id), isNull(boites.deletedAt)))
    .returning();
  return row;
}

export async function softDeleteBoite(db: Db, id: string): Promise<boolean> {
  const [row] = await db
    .update(boites)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(boites.id, id), isNull(boites.deletedAt)))
    .returning({ id: boites.id });
  return Boolean(row);
}
