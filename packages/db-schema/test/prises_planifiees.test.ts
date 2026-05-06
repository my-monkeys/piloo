import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import {
  officines,
  ordonnances,
  prescriptions,
  prisesPlanifiees,
  users,
  type NewPrisePlanifiee,
} from '../src/schema/index.ts';
import { setupTestDb, truncateAll, type TestDb } from './setup.ts';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 60_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await truncateAll(env.handle);
});

async function fixture() {
  const [u] = await env.handle.db
    .insert(users)
    .values({
      email: `u${String(Math.random()).slice(2, 8)}@b.fr`,
      name: 'Test User',
      nom: 'T',
      prenom: 'U',
      typeCompte: 'particulier',
    })
    .returning();
  const [o] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: u!.id })
    .returning();
  const [ord] = await env.handle.db
    .insert(ordonnances)
    .values({
      officineId: o!.id,
      datePrescription: '2026-04-01',
      saisiePar: u!.id,
    })
    .returning();
  const [rx] = await env.handle.db
    .insert(prescriptions)
    .values({
      ordonnanceId: ord!.id,
      nomTexte: 'DOLIPRANE 1000mg cp',
      posologie: {
        unitesParPrise: 1,
        unite: 'comprimé',
        frequence: 'quotidien',
        moments: ['matin'],
        horaires: ['08:00'],
      },
      dureeJours: 7,
    })
    .returning();
  return { user: u!, officine: o!, prescription: rx! };
}

const basePrise = (
  prescriptionId: string,
  officineId: string,
  overrides: Partial<NewPrisePlanifiee> = {},
): NewPrisePlanifiee => ({
  prescriptionId,
  officineId,
  datetimePrevue: new Date('2026-04-02T08:00:00Z'),
  ...overrides,
});

describe('prises_planifiees', () => {
  it('insère une prise avec defaults (statut=prevue)', async () => {
    const f = await fixture();
    const [p] = await env.handle.db
      .insert(prisesPlanifiees)
      .values(basePrise(f.prescription.id, f.officine.id))
      .returning();
    expect(p?.statut).toBe('prevue');
    expect(p?.datetimeValidation).toBeNull();
    expect(p?.valideePar).toBeNull();
  });

  it('accepte les 4 statuts métier', async () => {
    const f = await fixture();
    for (const statut of ['prevue', 'prise', 'sautee', 'oubliee'] as const) {
      const [p] = await env.handle.db
        .insert(prisesPlanifiees)
        .values(basePrise(f.prescription.id, f.officine.id, { statut }))
        .returning();
      expect(p?.statut).toBe(statut);
    }
  });

  it('rejette un statut invalide', async () => {
    const f = await fixture();
    await expect(
      env.handle.db.insert(prisesPlanifiees).values(
        // @ts-expect-error enum runtime
        basePrise(f.prescription.id, f.officine.id, { statut: 'reportee' }),
      ),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/invalid input value for enum/) },
    });
  });

  it('passe valide_par à NULL si user supprimé (ON DELETE SET NULL)', async () => {
    const f = await fixture();
    const [validator] = await env.handle.db
      .insert(users)
      .values({
        email: 'v@b.fr',
        name: 'Test User',
        nom: 'V',
        prenom: 'V',
        typeCompte: 'particulier',
      })
      .returning();
    const [p] = await env.handle.db
      .insert(prisesPlanifiees)
      .values(
        basePrise(f.prescription.id, f.officine.id, {
          statut: 'prise',
          valideePar: validator!.id,
          datetimeValidation: new Date(),
        }),
      )
      .returning();
    await env.handle.client`DELETE FROM users WHERE id = ${validator!.id}`;
    const rows = await env.handle
      .client`SELECT validee_par FROM prises_planifiees WHERE id = ${p!.id}`;
    expect(rows[0]?.['validee_par']).toBeNull();
  });

  it('bloque la suppression dure de la prescription parent (RESTRICT)', async () => {
    const f = await fixture();
    await env.handle.db
      .insert(prisesPlanifiees)
      .values(basePrise(f.prescription.id, f.officine.id));
    await expect(
      env.handle.client`DELETE FROM prescriptions WHERE id = ${f.prescription.id}`,
    ).rejects.toThrow(/foreign key|violates/);
  });
});
