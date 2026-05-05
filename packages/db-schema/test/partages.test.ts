import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { officines, partages, users, type NewPartage } from '../src/schema/index.ts';
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
  const [owner] = await env.handle.db
    .insert(users)
    .values({
      email: `o${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'h',
      nom: 'O',
      prenom: 'O',
      typeCompte: 'particulier',
    })
    .returning();
  const [editor] = await env.handle.db
    .insert(users)
    .values({
      email: `e${String(Math.random()).slice(2, 8)}@b.fr`,
      passwordHash: 'h',
      nom: 'E',
      prenom: 'E',
      typeCompte: 'particulier',
    })
    .returning();
  const [officine] = await env.handle.db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: owner!.id })
    .returning();
  return { owner: owner!, editor: editor!, officine: officine! };
}

describe('partages', () => {
  it('insère un partage owner', async () => {
    const f = await fixture();
    const [p] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.owner.id,
        role: 'owner',
        invitedBy: null,
        invitedAt: new Date(),
        acceptedAt: new Date(),
      } satisfies NewPartage)
      .returning();
    expect(p?.role).toBe('owner');
  });

  it('rejette un duplicate (officine_id, user_id) actif', async () => {
    const f = await fixture();
    await env.handle.db.insert(partages).values({
      officineId: f.officine.id,
      userId: f.editor.id,
      role: 'editor',
      invitedAt: new Date(),
    });
    await expect(
      env.handle.db.insert(partages).values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'viewer',
        invitedAt: new Date(),
      }),
    ).rejects.toThrow(/duplicate key|partages_officine_user/);
  });

  it('autorise un nouveau partage après soft-delete du précédent', async () => {
    const f = await fixture();
    const [p1] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'editor',
        invitedAt: new Date(),
      })
      .returning();
    await env.handle.client`UPDATE partages SET deleted_at = now() WHERE id = ${p1!.id}`;
    // Doit fonctionner — le partial unique ne couvre que les lignes
    // WHERE deleted_at IS NULL ; la ligne soft-deletée n'est plus dans
    // l'index et ne bloque donc pas la réinvitation.
    const [p2] = await env.handle.db
      .insert(partages)
      .values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'viewer',
        invitedAt: new Date(),
      })
      .returning();
    expect(p2?.role).toBe('viewer');
  });

  it('rejette un rôle invalide', async () => {
    const f = await fixture();
    await expect(
      // @ts-expect-error — 'admin' n'est pas un role_partage valide
      env.handle.db.insert(partages).values({
        officineId: f.officine.id,
        userId: f.editor.id,
        role: 'admin',
        invitedAt: new Date(),
      }),
    ).rejects.toThrow(/invalid input value for enum/);
  });
});
