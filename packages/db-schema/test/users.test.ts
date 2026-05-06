import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { users, type NewUser } from '../src/schema/index.ts';
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

const baseUser = (overrides: Partial<NewUser> = {}): NewUser => ({
  email: 'a@b.fr',
  name: 'Test User',
  nom: 'Dupont',
  prenom: 'Marie',
  typeCompte: 'particulier',
  ...overrides,
});

describe('users', () => {
  it('insère un user particulier minimal', async () => {
    const [row] = await env.handle.db.insert(users).values(baseUser()).returning();
    expect(row?.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(row?.email).toBe('a@b.fr');
    expect(row?.preferences).toEqual({});
    expect(row?.deletedAt).toBeNull();
    expect(row?.createdAt).toBeInstanceOf(Date);
  });

  it('rejette un email dupliqué (unique)', async () => {
    await env.handle.db.insert(users).values(baseUser({ email: 'dup@b.fr' }));
    await expect(
      env.handle.db.insert(users).values(baseUser({ email: 'dup@b.fr' })),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/duplicate key|users_email/) },
    });
  });

  it('rejette un type_compte invalide (enum)', async () => {
    await expect(
      // @ts-expect-error type narrowed by enum, on teste runtime
      env.handle.db.insert(users).values(baseUser({ typeCompte: 'admin' })),
    ).rejects.toMatchObject({
      cause: { message: expect.stringMatching(/invalid input value for enum/) },
    });
  });

  it('soft-delete : la ligne reste visible avec deletedAt non null', async () => {
    const [inserted] = await env.handle.db.insert(users).values(baseUser()).returning();
    const id = inserted?.id;
    if (!id) throw new Error('insert failed');
    await env.handle.client`UPDATE users SET deleted_at = now() WHERE id = ${id}`;
    const rows = await env.handle.client`SELECT id, deleted_at FROM users WHERE id = ${id}`;
    expect(rows[0]?.['deleted_at']).toBeInstanceOf(Date);
  });
});
