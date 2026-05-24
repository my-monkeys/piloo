// Tests d'intégration /api/v1/officines/{id}/partages (#339).
//
// Couvre :
//   GET    /partages           — RBAC (3 rôles), inclus invitations pending
//   PATCH  /partages/{userId}  — owner only, garde-fou dernier owner
//   DELETE /partages/{userId}  — revoke owner only, self-leave OK, garde-fou
import { invitations, officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { and, eq } from 'drizzle-orm';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';
import type * as AuthServerModule from '@/lib/auth/server';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

let env: TestDb;
let auth: AuthInstance;

beforeAll(async () => {
  env = await setupTestDb();
  auth = createAuth({ db: env.handle.db, secret: TEST_SECRET, baseURL: BASE_URL });

  vi.doMock('@/lib/auth/server', async () => {
    const actual = await vi.importActual<typeof AuthServerModule>('@/lib/auth/server');
    return { ...actual, getAuth: () => auth };
  });
  vi.doMock('@/lib/db', () => ({
    getDb: () => env.handle.db,
  }));
}, 90_000);

afterAll(async () => {
  vi.doUnmock('@/lib/db');
  vi.doUnmock('@/lib/auth/server');
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      invitations, partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

afterEach(() => {
  vi.resetModules();
});

interface SignUpResult {
  userId: string;
  cookie: string;
}

async function signup(email: string, name = 'Test'): Promise<SignUpResult> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name,
        nom: 'T',
        prenom: 'U',
        typeCompte: 'pro',
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup failed: ${String(res.status)}`);
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie };
}

async function importHandlers() {
  return {
    list: await import('@/app/api/v1/officines/[officineId]/partages/route'),
    item: await import('@/app/api/v1/officines/[officineId]/partages/[userId]/route'),
  };
}

async function makeOfficine(userId: string, nom = 'Maison'): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom, type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('insert officine returned no row');
  return row.id;
}

async function grant(
  userId: string,
  officineId: string,
  role: 'owner' | 'editor' | 'viewer',
): Promise<void> {
  await env.handle.db.insert(partages).values({
    userId,
    officineId,
    role,
    invitedAt: new Date(),
    acceptedAt: new Date(),
  });
}

async function makeInvitation(
  officineId: string,
  invitedByUserId: string,
  email: string,
  role: 'owner' | 'editor' | 'viewer' = 'editor',
): Promise<string> {
  const expiresAt = new Date(Date.now() + 72 * 3600 * 1000);
  const [row] = await env.handle.db
    .insert(invitations)
    .values({
      officineId,
      invitedByUserId,
      role,
      email,
      expiresAt,
    })
    .returning({ id: invitations.id });
  if (!row) throw new Error('insert invitation returned no row');
  return row.id;
}

describe('GET /api/v1/officines/:id/partages', () => {
  it('renvoie 401 sans credential', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    const { list } = await importHandlers();
    const res = await list.GET(new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages`), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(401);
  });

  it("renvoie 404 si l'user n'est pas membre", async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages`, {
        headers: { cookie: stranger.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(404);
  });

  it('autorise les 3 rôles à lister', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    for (const role of ['owner', 'editor', 'viewer'] as const) {
      const u = role === 'owner' ? owner : await signup(`${role}@piloo.fr`);
      if (role !== 'owner') await grant(u.userId, officineId, role);

      const { list } = await importHandlers();
      const res = await list.GET(
        new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ officineId }) },
      );
      expect(res.status).toBe(200);
    }
  });

  it('liste membres + invitations pending', async () => {
    const owner = await signup('owner@piloo.fr', 'Owner');
    const editor = await signup('editor@piloo.fr', 'Edith');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');
    await makeInvitation(officineId, owner.userId, 'pending@piloo.fr', 'viewer');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages`, {
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      members: { user_id: string; email: string; role: string }[];
      pending_invitations: { email: string | null; role: string }[];
    };
    expect(body.members).toHaveLength(2);
    expect(body.members.map((m) => m.email).sort()).toEqual(['editor@piloo.fr', 'owner@piloo.fr']);
    expect(body.pending_invitations).toHaveLength(1);
    expect(body.pending_invitations[0]?.email).toBe('pending@piloo.fr');
    expect(body.pending_invitations[0]?.role).toBe('viewer');
  });

  it('exclut les membres soft-deleted', async () => {
    const owner = await signup('owner@piloo.fr');
    const exMember = await signup('ex@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(exMember.userId, officineId, 'editor');
    await env.handle.db
      .update(partages)
      .set({ deletedAt: new Date() })
      .where(eq(partages.userId, exMember.userId));

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages`, {
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    const body = (await res.json()) as { members: { email: string }[] };
    expect(body.members.map((m) => m.email)).toEqual(['owner@piloo.fr']);
  });
});

describe('PATCH /api/v1/officines/:id/partages/:userId', () => {
  it('owner peut promouvoir un viewer en editor', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(viewer.userId, officineId, 'viewer');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${viewer.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: owner.cookie },
        body: JSON.stringify({ role: 'editor' }),
      }),
      { params: Promise.resolve({ officineId, userId: viewer.userId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { role: string };
    expect(body.role).toBe('editor');
  });

  it('editor ne peut pas changer un rôle (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');
    await grant(viewer.userId, officineId, 'viewer');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${viewer.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: editor.cookie },
        body: JSON.stringify({ role: 'editor' }),
      }),
      { params: Promise.resolve({ officineId, userId: viewer.userId }) },
    );
    expect(res.status).toBe(403);
  });

  it('refuse de rétrograder le dernier owner (409)', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${owner.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: owner.cookie },
        body: JSON.stringify({ role: 'editor' }),
      }),
      { params: Promise.resolve({ officineId, userId: owner.userId }) },
    );
    expect(res.status).toBe(409);
  });

  it("autorise la rétrogradation s'il reste un autre owner", async () => {
    const ownerA = await signup('owner-a@piloo.fr');
    const ownerB = await signup('owner-b@piloo.fr');
    const officineId = await makeOfficine(ownerA.userId);
    await grant(ownerA.userId, officineId, 'owner');
    await grant(ownerB.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${ownerB.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: ownerA.cookie },
        body: JSON.stringify({ role: 'editor' }),
      }),
      { params: Promise.resolve({ officineId, userId: ownerB.userId }) },
    );
    expect(res.status).toBe(200);
  });

  it("renvoie 404 si la cible n'est pas membre", async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${stranger.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: owner.cookie },
        body: JSON.stringify({ role: 'editor' }),
      }),
      { params: Promise.resolve({ officineId, userId: stranger.userId }) },
    );
    expect(res.status).toBe(404);
  });

  it('renvoie 400 si role invalide', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${editor.userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: owner.cookie },
        body: JSON.stringify({ role: 'super-admin' }),
      }),
      { params: Promise.resolve({ officineId, userId: editor.userId }) },
    );
    expect(res.status).toBe(400);
  });
});

describe('DELETE /api/v1/officines/:id/partages/:userId', () => {
  it('owner peut révoquer un editor', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${editor.userId}`, {
        method: 'DELETE',
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: editor.userId }) },
    );
    expect(res.status).toBe(204);

    const [row] = await env.handle.db
      .select({ deletedAt: partages.deletedAt })
      .from(partages)
      .where(and(eq(partages.officineId, officineId), eq(partages.userId, editor.userId)));
    expect(row?.deletedAt).not.toBeNull();
  });

  it("editor peut quitter l'officine lui-même", async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${editor.userId}`, {
        method: 'DELETE',
        headers: { cookie: editor.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: editor.userId }) },
    );
    expect(res.status).toBe(204);
  });

  it('editor ne peut pas révoquer un autre membre (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');
    await grant(viewer.userId, officineId, 'viewer');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${viewer.userId}`, {
        method: 'DELETE',
        headers: { cookie: editor.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: viewer.userId }) },
    );
    expect(res.status).toBe(403);
  });

  it('refuse le self-leave du dernier owner (409)', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${owner.userId}`, {
        method: 'DELETE',
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: owner.userId }) },
    );
    expect(res.status).toBe(409);
  });

  it("autorise le self-leave d'un owner s'il reste un autre owner", async () => {
    const ownerA = await signup('owner-a@piloo.fr');
    const ownerB = await signup('owner-b@piloo.fr');
    const officineId = await makeOfficine(ownerA.userId);
    await grant(ownerA.userId, officineId, 'owner');
    await grant(ownerB.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${ownerA.userId}`, {
        method: 'DELETE',
        headers: { cookie: ownerA.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: ownerA.userId }) },
    );
    expect(res.status).toBe(204);
  });

  it("renvoie 404 si la cible n'est pas membre", async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/partages/${stranger.userId}`, {
        method: 'DELETE',
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId, userId: stranger.userId }) },
    );
    expect(res.status).toBe(404);
  });
});
