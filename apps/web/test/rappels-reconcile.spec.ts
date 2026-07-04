// Tests d'intégration du module de réconciliation des prises_planifiees
// lors de la gestion d'un rappel (pause / édition / suppression).
// Tâche A1+A2 du plan gestion-rappels (#355).
import { officines, rappels, prisesPlanifiees, users } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { eq } from 'drizzle-orm';

import { cancelFutureRappelPrises, regenerateRappelPrises } from '@/lib/rappels/reconcile';

let env: TestDb;
beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);
afterAll(async () => {
  await env.teardown();
});
beforeEach(async () => {
  await env.handle
    .client`TRUNCATE TABLE prises_planifiees, rappels, partages, officines, users RESTART IDENTITY CASCADE`;
});

async function seedRappel(): Promise<{ officineId: string; rappelId: string; userId: string }> {
  const db = env.handle.db;
  const [u] = await db
    .insert(users)
    .values({ email: 'a@test.fr', name: 'A', nom: 'A', prenom: 'A', typeCompte: 'particulier' })
    .returning();
  const [o] = await db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: u!.id })
    .returning();
  const [r] = await db
    .insert(rappels)
    .values({
      officineId: o!.id,
      cip13: '3400930000000',
      nomTexte: 'Doliprane',
      quantiteMatin: 1,
      dateDebut: '2026-06-01',
      creeParUserId: u!.id,
    })
    .returning();
  return { officineId: o!.id, rappelId: r!.id, userId: u!.id };
}

describe('cancelFutureRappelPrises', () => {
  it('soft-delete les prises prevue futures, garde passées et déjà prises', async () => {
    const db = env.handle.db;
    const { officineId, rappelId } = await seedRappel();
    const now = new Date('2026-06-10T08:00:00.000Z');
    await db.insert(prisesPlanifiees).values([
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-09T08:00:00.000Z'),
        statut: 'prevue',
      },
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-11T08:00:00.000Z'),
        statut: 'prevue',
      },
      {
        rappelId,
        officineId,
        datetimePrevue: new Date('2026-06-12T08:00:00.000Z'),
        statut: 'prise',
      },
    ]);
    const cancelled = await cancelFutureRappelPrises(db, rappelId, now);
    expect(cancelled).toBe(1);
    const rows = await db.select().from(prisesPlanifiees);
    const future = rows.find(
      (p) => p.datetimePrevue.getTime() === new Date('2026-06-11T08:00:00.000Z').getTime(),
    );
    const past = rows.find(
      (p) => p.datetimePrevue.getTime() === new Date('2026-06-09T08:00:00.000Z').getTime(),
    );
    const taken = rows.find((p) => p.statut === 'prise');
    expect(future!.deletedAt).not.toBeNull();
    expect(past!.deletedAt).toBeNull();
    expect(taken!.deletedAt).toBeNull();
  });
});

describe('regenerateRappelPrises', () => {
  it('génère la fenêtre initiale (30j) à partir de max(today, dateDebut)', async () => {
    const db = env.handle.db;
    const { rappelId } = await seedRappel();
    const now = new Date('2026-06-10T09:00:00.000Z');
    const created = await regenerateRappelPrises(db, rappelId, now);
    expect(created).toBe(30);
    const rows = await db.select().from(prisesPlanifiees);
    expect(rows).toHaveLength(30);
    const first = rows.map((r) => r.datetimePrevue.getTime()).sort((a, b) => a - b)[0];
    // Officine sans fuseau → défaut Europe/Paris. Matin 08:00 mural en juin
    // (été, +2) → 06:00Z (#363).
    expect(new Date(first!).toISOString()).toBe('2026-06-10T06:00:00.000Z');
  });

  it('borne la fenêtre à dateFin (incluse)', async () => {
    const db = env.handle.db;
    const { rappelId } = await seedRappel();
    await db.update(rappels).set({ dateFin: '2026-06-12' }).where(eq(rappels.id, rappelId));
    const now = new Date('2026-06-10T09:00:00.000Z');
    const created = await regenerateRappelPrises(db, rappelId, now);
    expect(created).toBe(3);
  });
});
