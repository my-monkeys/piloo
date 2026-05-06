import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import {
  boites,
  officines,
  users,
  type NewBoite,
  type NewOfficine,
  type NewUser,
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
    } satisfies NewUser)
    .returning();
  const [o] = await env.handle.db
    .insert(officines)
    .values({
      nom: 'Maison',
      type: 'perso',
      proprietaireUserId: u!.id,
    } satisfies NewOfficine)
    .returning();
  return { user: u!, officine: o! };
}

const baseBoite = (
  officineId: string,
  ajouteePar: string,
  overrides: Partial<NewBoite> = {},
): NewBoite => ({
  officineId,
  cip13: '3400930000001',
  lot: 'LOT123',
  numeroSerie: 'SERIE-A',
  peremption: '2027-12-31',
  ajouteePar,
  ...overrides,
});

describe('boites', () => {
  it('insère une boîte minimale avec defaults', async () => {
    const f = await fixture();
    const [b] = await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id))
      .returning();
    expect(b?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(b?.statut).toBe('active');
    expect(b?.deletedAt).toBeNull();
  });

  it('rejette duplicate (officine, cip13, lot, numero_serie) actif', async () => {
    const f = await fixture();
    await env.handle.db.insert(boites).values(baseBoite(f.officine.id, f.user.id));
    await expect(
      env.handle.db.insert(boites).values(baseBoite(f.officine.id, f.user.id)),
    ).rejects.toMatchObject({
      cause: {
        message: expect.stringMatching(/duplicate key|boites_officine_cip13_lot_serie_unique/),
      },
    });
  });

  it('autorise même (officine, cip13, lot) avec serie différente', async () => {
    const f = await fixture();
    await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id, { numeroSerie: 'SERIE-A' }));
    const [b2] = await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id, { numeroSerie: 'SERIE-B' }))
      .returning();
    expect(b2?.numeroSerie).toBe('SERIE-B');
  });

  it('rejette duplicate (officine, cip13, lot) sans serie (fallback vieille boîte)', async () => {
    const f = await fixture();
    await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id, { numeroSerie: null }));
    await expect(
      env.handle.db
        .insert(boites)
        .values(baseBoite(f.officine.id, f.user.id, { numeroSerie: null })),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/duplicate key|boites_officine_cip13_lot_unique/) },
    });
  });

  it('autorise plusieurs boîtes identiques quand lot ET serie sont NULL', async () => {
    const f = await fixture();
    const v = baseBoite(f.officine.id, f.user.id, { lot: null, numeroSerie: null });
    await env.handle.db.insert(boites).values(v);
    const [b2] = await env.handle.db.insert(boites).values(v).returning();
    expect(b2?.id).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('autorise une nouvelle boîte identique après soft-delete', async () => {
    const f = await fixture();
    const [b1] = await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id))
      .returning();
    await env.handle.client`UPDATE boites SET deleted_at = now() WHERE id = ${b1!.id}`;
    const [b2] = await env.handle.db
      .insert(boites)
      .values(baseBoite(f.officine.id, f.user.id))
      .returning();
    expect(b2?.id).not.toBe(b1?.id);
  });

  it('rejette un statut invalide (enum)', async () => {
    const f = await fixture();
    await expect(
      env.handle.db.insert(boites).values(
        // @ts-expect-error enum runtime test
        baseBoite(f.officine.id, f.user.id, { statut: 'inconnu' }),
      ),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/invalid input value for enum/) },
    });
  });

  it('rejette une FK officine inconnue', async () => {
    const f = await fixture();
    await expect(
      env.handle.db
        .insert(boites)
        .values(baseBoite('00000000-0000-0000-0000-000000000000', f.user.id)),
    ).rejects.toMatchObject({ cause: { message: expect.stringMatching(/foreign key|fk/) } });
  });
});
