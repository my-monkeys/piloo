import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import {
  officines,
  ordonnances,
  prescriptions,
  users,
  type NewPrescription,
  type Posologie,
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
  return { user: u!, officine: o!, ordonnance: ord! };
}

const baseRx = (
  ordonnanceId: string,
  overrides: Partial<NewPrescription> = {},
): NewPrescription => {
  const posologie: Posologie = {
    unitesParPrise: 1,
    unite: 'comprimé',
    frequence: 'quotidien',
    moments: ['matin', 'soir'],
    horaires: ['08:00', '20:00'],
    avecRepas: true,
  };
  return {
    ordonnanceId,
    nomTexte: 'DOLIPRANE 1000mg cp',
    posologie,
    dureeJours: 7,
    ...overrides,
  };
};

describe('prescriptions', () => {
  it('insère une prescription avec posologie JSONB', async () => {
    const f = await fixture();
    const [rx] = await env.handle.db
      .insert(prescriptions)
      .values(baseRx(f.ordonnance.id))
      .returning();
    expect(rx?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(rx?.posologie.unitesParPrise).toBe(1);
    expect(rx?.posologie.frequence).toBe('quotidien');
    expect(rx?.posologie.moments).toEqual(['matin', 'soir']);
    expect(rx?.dureeJours).toBe(7);
  });

  it('autorise duree_jours NULL (traitement à vie)', async () => {
    const f = await fixture();
    const [rx] = await env.handle.db
      .insert(prescriptions)
      .values(baseRx(f.ordonnance.id, { dureeJours: null }))
      .returning();
    expect(rx?.dureeJours).toBeNull();
  });

  it('rejette FK ordonnance inconnue', async () => {
    await expect(
      env.handle.db.insert(prescriptions).values(baseRx('00000000-0000-0000-0000-000000000000')),
    ).rejects.toMatchObject({ cause: { message: expect.stringMatching(/foreign key|fk/) } });
  });

  it("la suppression dure d'une ordonnance avec prescription est bloquée (RESTRICT)", async () => {
    const f = await fixture();
    await env.handle.db.insert(prescriptions).values(baseRx(f.ordonnance.id));
    await expect(
      env.handle.client`DELETE FROM ordonnances WHERE id = ${f.ordonnance.id}`,
    ).rejects.toThrow(/foreign key|violates/);
  });

  it("le soft-delete d'une ordonnance n'affecte pas la ligne prescription (cascade applicative)", async () => {
    const f = await fixture();
    const [rx] = await env.handle.db
      .insert(prescriptions)
      .values(baseRx(f.ordonnance.id))
      .returning();
    await env.handle
      .client`UPDATE ordonnances SET deleted_at = now() WHERE id = ${f.ordonnance.id}`;
    const rows = await env.handle
      .client`SELECT id, deleted_at FROM prescriptions WHERE id = ${rx!.id}`;
    expect(rows[0]?.['deleted_at']).toBeNull();
  });
});
