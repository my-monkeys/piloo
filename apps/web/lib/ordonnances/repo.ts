// Repository ordonnances + prescriptions (#106).
// Toutes les queries filtrent `deleted_at IS NULL`. Le soft-delete d'une
// ordonnance cascade en soft-delete sur ses prescriptions (les FKs sont
// `RESTRICT` côté Postgres, donc la cascade est applicative).
import {
  ordonnances,
  prescriptions,
  type Db,
  type NewPrescription,
  type Ordonnance,
  type Posologie,
  type Prescription,
} from '@piloo/db-schema';
import { and, asc, desc, eq, isNull } from 'drizzle-orm';

export async function listOrdonnancesByOfficine(db: Db, officineId: string): Promise<Ordonnance[]> {
  return db
    .select()
    .from(ordonnances)
    .where(and(eq(ordonnances.officineId, officineId), isNull(ordonnances.deletedAt)))
    .orderBy(desc(ordonnances.datePrescription), desc(ordonnances.createdAt));
}

export async function findOrdonnanceById(db: Db, id: string): Promise<Ordonnance | undefined> {
  const [row] = await db
    .select()
    .from(ordonnances)
    .where(and(eq(ordonnances.id, id), isNull(ordonnances.deletedAt)))
    .limit(1);
  return row;
}

export async function listPrescriptionsByOrdonnance(
  db: Db,
  ordonnanceId: string,
): Promise<Prescription[]> {
  return db
    .select()
    .from(prescriptions)
    .where(and(eq(prescriptions.ordonnanceId, ordonnanceId), isNull(prescriptions.deletedAt)))
    .orderBy(asc(prescriptions.createdAt));
}

export async function findPrescriptionById(db: Db, id: string): Promise<Prescription | undefined> {
  const [row] = await db
    .select()
    .from(prescriptions)
    .where(and(eq(prescriptions.id, id), isNull(prescriptions.deletedAt)))
    .limit(1);
  return row;
}

export interface CreateOrdonnanceInput {
  officineId: string;
  prescripteur: string | null;
  datePrescription: string;
  source: 'manuelle' | 'ocr';
  photoUrl: string | null;
  notes: string | null;
  saisiePar: string;
}

export interface CreatePrescriptionRowInput {
  ordonnanceId: string;
  cip13: string | null;
  cis: string | null;
  nomTexte: string;
  posologie: Posologie;
  dureeJours: number | null;
  indication: string | null;
  notes: string | null;
}

/** Crée l'ordonnance et ses prescriptions atomiquement. */
export async function createOrdonnanceWithPrescriptions(
  db: Db,
  input: CreateOrdonnanceInput,
  prescs: readonly Omit<CreatePrescriptionRowInput, 'ordonnanceId'>[],
): Promise<{ ordonnance: Ordonnance; prescriptions: Prescription[] }> {
  return db.transaction(async (tx) => {
    const [ord] = await tx.insert(ordonnances).values(input).returning();
    if (!ord) throw new Error('createOrdonnance: insert returned no row');
    if (prescs.length === 0) {
      return { ordonnance: ord, prescriptions: [] };
    }
    const rows: NewPrescription[] = prescs.map((p) => ({ ...p, ordonnanceId: ord.id }));
    const created = await tx.insert(prescriptions).values(rows).returning();
    return { ordonnance: ord, prescriptions: created };
  });
}

export async function createPrescription(
  db: Db,
  input: CreatePrescriptionRowInput,
): Promise<Prescription> {
  const [row] = await db.insert(prescriptions).values(input).returning();
  if (!row) throw new Error('createPrescription: insert returned no row');
  return row;
}

export async function updateOrdonnance(
  db: Db,
  id: string,
  patch: {
    prescripteur?: string | null;
    datePrescription?: string;
    photoUrl?: string | null;
    notes?: string | null;
  },
): Promise<Ordonnance | undefined> {
  if (Object.keys(patch).length === 0) {
    return findOrdonnanceById(db, id);
  }
  const [row] = await db
    .update(ordonnances)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(ordonnances.id, id), isNull(ordonnances.deletedAt)))
    .returning();
  return row;
}

export async function updatePrescription(
  db: Db,
  id: string,
  patch: Partial<Omit<CreatePrescriptionRowInput, 'ordonnanceId'>>,
): Promise<Prescription | undefined> {
  if (Object.keys(patch).length === 0) {
    return findPrescriptionById(db, id);
  }
  const [row] = await db
    .update(prescriptions)
    .set({ ...patch, updatedAt: new Date() })
    .where(and(eq(prescriptions.id, id), isNull(prescriptions.deletedAt)))
    .returning();
  return row;
}

/** Soft-delete l'ordonnance et toutes ses prescriptions actives. */
export async function softDeleteOrdonnance(db: Db, id: string): Promise<boolean> {
  return db.transaction(async (tx) => {
    const now = new Date();
    const [row] = await tx
      .update(ordonnances)
      .set({ deletedAt: now, updatedAt: now })
      .where(and(eq(ordonnances.id, id), isNull(ordonnances.deletedAt)))
      .returning({ id: ordonnances.id });
    if (!row) return false;
    await tx
      .update(prescriptions)
      .set({ deletedAt: now, updatedAt: now })
      .where(and(eq(prescriptions.ordonnanceId, id), isNull(prescriptions.deletedAt)));
    return true;
  });
}

export async function softDeletePrescription(db: Db, id: string): Promise<boolean> {
  const [row] = await db
    .update(prescriptions)
    .set({ deletedAt: new Date(), updatedAt: new Date() })
    .where(and(eq(prescriptions.id, id), isNull(prescriptions.deletedAt)))
    .returning({ id: prescriptions.id });
  return Boolean(row);
}
