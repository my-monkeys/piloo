import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import {
  officines,
  ordonnances,
  users,
  type NewOfficine,
  type NewOrdonnance,
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
      nom: 'M',
      type: 'perso',
      proprietaireUserId: u!.id,
    } satisfies NewOfficine)
    .returning();
  return { user: u!, officine: o! };
}

describe('ordonnances', () => {
  it('insère une ordonnance manuelle minimale (default source=manuelle)', async () => {
    const f = await fixture();
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({
        officineId: f.officine.id,
        datePrescription: '2026-04-01',
        saisiePar: f.user.id,
      } satisfies NewOrdonnance)
      .returning();
    expect(ord?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(ord?.source).toBe('manuelle');
    expect(ord?.deletedAt).toBeNull();
  });

  it('rejette une source invalide', async () => {
    const f = await fixture();
    await expect(
      // @ts-expect-error enum runtime
      env.handle.db.insert(ordonnances).values({
        officineId: f.officine.id,
        datePrescription: '2026-04-01',
        saisiePar: f.user.id,
        source: 'photo',
      }),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/invalid input value for enum/) },
    });
  });

  it('rejette une FK officine inconnue', async () => {
    const f = await fixture();
    await expect(
      env.handle.db.insert(ordonnances).values({
        officineId: '00000000-0000-0000-0000-000000000000',
        datePrescription: '2026-04-01',
        saisiePar: f.user.id,
      } satisfies NewOrdonnance),
    ).rejects.toMatchObject({ cause: { message: expect.stringMatching(/foreign key|fk/) } });
  });
});
