// Tests d'intégration /api/v1/officines/:id/boites + /api/v1/boites/:id (#86).
import { boites, officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
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
  vi.doMock('@/lib/db', () => ({ getDb: () => env.handle.db }));
}, 90_000);

afterAll(async () => {
  vi.doUnmock('@/lib/db');
  vi.doUnmock('@/lib/auth/server');
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      boites, partages, officines, sessions, accounts, verifications, users
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

async function signup(email: string): Promise<SignUpResult> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: 'Test',
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
    list: await import('@/app/api/v1/officines/[officineId]/boites/route'),
    item: await import('@/app/api/v1/boites/[id]/route'),
  };
}

async function makeOfficine(userId: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('officine insert returned no row');
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

async function makeBoite(
  officineId: string,
  ajouteePar: string,
  cip13 = '3400930000019',
): Promise<string> {
  const [row] = await env.handle.db
    .insert(boites)
    .values({
      officineId,
      cip13,
      lot: 'LOT-X',
      peremption: '2027-01-01',
      ajouteePar,
    })
    .returning({ id: boites.id });
  if (!row) throw new Error('boite insert returned no row');
  return row.id;
}

const validCreate = {
  cip13: '3400930000019',
  lot: 'LOT-A',
  peremption: '2027-01-01',
  unites_initiales: 16,
  unites_restantes: 12,
};

describe('GET /api/v1/officines/:officineId/boites', () => {
  it('liste les boîtes pour les 3 rôles, exclut les soft-deleted', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    await makeBoite(officineId, owner.userId, '3400930000019');
    const deleted = await makeBoite(officineId, owner.userId, '3400930000026');
    await env.handle.db.update(boites).set({ deletedAt: new Date() }).where(eq(boites.id, deleted));

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`, {
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: { id: string }[] };
    expect(body.items).toHaveLength(1);
  });

  it('renvoie 404 si pas de partage actif', async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`, {
        headers: { cookie: stranger.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(404);
  });

  it('renvoie 401 sans credential', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);

    const { list } = await importHandlers();
    const res = await list.GET(new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(401);
  });
});

describe('POST /api/v1/officines/:officineId/boites', () => {
  it('owner peut créer', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as { cip13: string; statut: string; ajoutee_par: string };
    expect(body.cip13).toBe('3400930000019');
    expect(body.statut).toBe('active');
    expect(body.ajoutee_par).toBe(me.userId);
  });

  it('viewer ne peut pas créer (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');

    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: viewer.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(403);
  });

  it('rejette un cip13 invalide (400 validation_error)', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/boites`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ ...validCreate, cip13: 'short' }),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('validation_error');
  });
});

describe('GET /api/v1/boites/:id', () => {
  it('autorise les 3 rôles à lire', async () => {
    const proprio = await signup('proprio@piloo.fr');
    const officineId = await makeOfficine(proprio.userId);
    const boiteId = await makeBoite(officineId, proprio.userId);

    for (const role of ['owner', 'editor', 'viewer'] as const) {
      const u = await signup(`role-${role}@piloo.fr`);
      await grant(u.userId, officineId, role);

      const { item } = await importHandlers();
      const res = await item.GET(
        new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ id: boiteId }) },
      );
      expect(res.status).toBe(200);
    }
  });

  it('renvoie 404 si la boîte est soft-deleted', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const boiteId = await makeBoite(officineId, me.userId);
    await env.handle.db.update(boites).set({ deletedAt: new Date() }).where(eq(boites.id, boiteId));

    const { item } = await importHandlers();
    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(404);
  });

  it("renvoie 404 si pas de partage sur l'officine de la boîte", async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    const boiteId = await makeBoite(officineId, owner.userId);

    const { item } = await importHandlers();
    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        headers: { cookie: stranger.cookie },
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(404);
  });
});

describe('PATCH /api/v1/boites/:id', () => {
  it('editor peut update statut + unites_restantes', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(editor.userId, officineId, 'editor');
    const boiteId = await makeBoite(officineId, owner.userId);

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: editor.cookie },
        body: JSON.stringify({ statut: 'vide', unites_restantes: 0 }),
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { statut: string; unites_restantes: number };
    expect(body.statut).toBe('vide');
    expect(body.unites_restantes).toBe(0);
  });

  it('viewer ne peut pas update (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');
    const boiteId = await makeBoite(officineId, owner.userId);

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: viewer.cookie },
        body: JSON.stringify({ statut: 'vide' }),
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(403);
  });
});

describe('DELETE /api/v1/boites/:id', () => {
  it('editor peut soft-delete', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(editor.userId, officineId, 'editor');
    const boiteId = await makeBoite(officineId, owner.userId);

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        method: 'DELETE',
        headers: { cookie: editor.cookie },
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(204);

    const [row] = await env.handle.db
      .select({ deletedAt: boites.deletedAt })
      .from(boites)
      .where(eq(boites.id, boiteId));
    expect(row?.deletedAt).not.toBeNull();
  });

  it('viewer ne peut pas delete (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');
    const boiteId = await makeBoite(officineId, owner.userId);

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/boites/${boiteId}`, {
        method: 'DELETE',
        headers: { cookie: viewer.cookie },
      }),
      { params: Promise.resolve({ id: boiteId }) },
    );
    expect(res.status).toBe(403);
  });
});
