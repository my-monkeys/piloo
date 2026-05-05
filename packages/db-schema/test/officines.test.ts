import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { officines, users, type NewOfficine, type NewUser } from '../src/schema/index.ts';
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

async function insertUser(overrides: Partial<NewUser> = {}) {
  const [u] = await env.handle.db
    .insert(users)
    .values({
      email: `u${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'hash',
      nom: 'Test',
      prenom: 'User',
      typeCompte: 'particulier',
      ...overrides,
    })
    .returning();
  if (!u) throw new Error('insert user failed');
  return u;
}

describe('officines', () => {
  it('insère une officine perso liée à un user', async () => {
    const u = await insertUser();
    const [o] = await env.handle.db
      .insert(officines)
      .values({
        nom: 'Maison',
        type: 'perso',
        proprietaireUserId: u.id,
      } satisfies NewOfficine)
      .returning();
    expect(o?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(o?.proprietaireUserId).toBe(u.id);
    expect(o?.type).toBe('perso');
    expect(o?.deletedAt).toBeNull();
  });

  it('rejette une officine sans propriétaire (FK violation)', async () => {
    await expect(
      env.handle.db.insert(officines).values({
        nom: 'Ghost',
        type: 'perso',
        proprietaireUserId: '00000000-0000-0000-0000-000000000000',
      } satisfies NewOfficine),
    ).rejects.toThrow(/foreign key|fk_officines/);
  });

  it('rejette un type invalide', async () => {
    const u = await insertUser();
    await expect(
      // @ts-expect-error enum runtime test — 'inconnu' n'est pas dans type_officine
      env.handle.db.insert(officines).values({
        nom: 'Bad',
        type: 'inconnu',
        proprietaireUserId: u.id,
      }),
    ).rejects.toThrow(/invalid input value for enum/);
  });

  it("soft-delete : la ligne reste, peut être recréée à l'identique", async () => {
    const u = await insertUser();
    const [o] = await env.handle.db
      .insert(officines)
      .values({ nom: 'A', type: 'perso', proprietaireUserId: u.id })
      .returning();
    await env.handle.client`UPDATE officines SET deleted_at = now() WHERE id = ${o!.id}`;

    // On peut recréer une autre officine du même propriétaire — pas de unique sur proprietaire_user_id.
    const [o2] = await env.handle.db
      .insert(officines)
      .values({ nom: 'A', type: 'perso', proprietaireUserId: u.id })
      .returning();
    expect(o2?.id).not.toBe(o?.id);
  });
});
