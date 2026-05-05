import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { alertes, officines, users, type NewAlerte } from '../src/schema/index.ts';
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
      passwordHash: 'h',
      nom: 'T',
      prenom: 'U',
      typeCompte: 'particulier',
    })
    .returning();
  const [o] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: u!.id })
    .returning();
  return { user: u!, officine: o! };
}

const baseAlerte = (
  officineId: string,
  userId: string,
  overrides: Partial<NewAlerte> = {},
): NewAlerte => ({
  officineId,
  userId,
  type: 'peremption_30j',
  payload: { boiteId: 'abc', joursRestants: 25 },
  ...overrides,
});

describe('alertes', () => {
  it('insère une alerte non lue avec payload JSONB', async () => {
    const f = await fixture();
    const [a] = await env.handle.db
      .insert(alertes)
      .values(baseAlerte(f.officine.id, f.user.id))
      .returning();
    expect(a?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(a?.type).toBe('peremption_30j');
    expect(a?.payload).toEqual({ boiteId: 'abc', joursRestants: 25 });
    expect(a?.lueA).toBeNull();
  });

  it('accepte les 5 types métier', async () => {
    const f = await fixture();
    for (const type of [
      'peremption_30j',
      'peremption_7j',
      'stock_bas',
      'prise_oubliee',
      'manque_signale',
    ] as const) {
      const [a] = await env.handle.db
        .insert(alertes)
        .values(baseAlerte(f.officine.id, f.user.id, { type, payload: {} }))
        .returning();
      expect(a?.type).toBe(type);
    }
  });

  it('rejette un type invalide', async () => {
    const f = await fixture();
    await expect(
      env.handle.db.insert(alertes).values(
        // @ts-expect-error enum runtime
        baseAlerte(f.officine.id, f.user.id, { type: 'autre' }),
      ),
    ).rejects.toThrow(/invalid input value for enum/);
  });

  it('badge non lues : index partiel ne couvre que lue_a IS NULL et non soft-deleted', async () => {
    const f = await fixture();
    const v = baseAlerte(f.officine.id, f.user.id);
    const [a1] = await env.handle.db.insert(alertes).values(v).returning();
    const [a2] = await env.handle.db.insert(alertes).values(v).returning();
    const [a3] = await env.handle.db.insert(alertes).values(v).returning();
    await env.handle.client`UPDATE alertes SET lue_a = now() WHERE id = ${a2!.id}`;
    await env.handle.client`UPDATE alertes SET deleted_at = now() WHERE id = ${a3!.id}`;
    const rows = await env.handle.client<{ count: string }[]>`
      SELECT count(*)::text AS count
      FROM alertes
      WHERE user_id = ${f.user.id} AND lue_a IS NULL AND deleted_at IS NULL
    `;
    expect(rows[0]?.count).toBe('1');
    expect(a1?.id).not.toBe(a2?.id);
  });

  it('rejette une FK officine inconnue', async () => {
    const f = await fixture();
    await expect(
      env.handle.db
        .insert(alertes)
        .values(baseAlerte('00000000-0000-0000-0000-000000000000', f.user.id)),
    ).rejects.toThrow(/foreign key|fk/);
  });
});
