// Tests d'intégration /api/v1/officines (#70).
// Couverture : list, create, get, update, delete avec les 3 rôles
// (owner, editor, viewer) et les cas d'erreurs (401, 403, 404, 400).
//
// On invoque les handlers Next directement avec un Request — pas de
// dev server à lancer. L'override de `getDb()` se fait via DATABASE_URL
// pointé vers le testcontainer ; l'override de `getAuth()` est plus
// délicat (singleton) donc on ne teste pas via le handler Better Auth
// ici, on simule la session en créant un cookie via createAuth().
import { officines, partages } from '@piloo/db-schema';
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

  // Override de l'auth singleton + de la connexion DB pour que les
  // handlers Next utilisent notre testcontainer + auth de test.
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
      partages, officines, sessions, accounts, verifications, users
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

async function signup(email: string, type: 'particulier' | 'pro' = 'pro'): Promise<SignUpResult> {
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
        typeCompte: type,
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup failed: ${String(res.status)}`);
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie };
}

async function importHandlers() {
  // Re-import dynamique pour bénéficier des `vi.doMock` (les mocks ne
  // s'appliquent qu'aux modules importés APRÈS leur déclaration).
  return {
    list: await import('@/app/api/v1/officines/route'),
    item: await import('@/app/api/v1/officines/[id]/route'),
  };
}

async function makeOfficine(userId: string, nom = 'Maison'): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom, type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('insert returned no row');
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

describe('GET /api/v1/officines', () => {
  it('renvoie 401 sans credential', async () => {
    const { list } = await importHandlers();
    const res = await list.GET(new Request(`${BASE_URL}/api/v1/officines`));
    expect(res.status).toBe(401);
  });

  it('liste les officines accessibles avec leur rôle', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineA = await makeOfficine(owner.userId, 'A');
    await grant(owner.userId, officineA, 'owner');
    // Officine sur laquelle owner n'a aucun rôle → ne doit pas apparaître.
    const stranger = await signup('stranger@piloo.fr');
    await makeOfficine(stranger.userId, 'Stranger');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      items: { id: string; nom: string; role: string }[];
    };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.id).toBe(officineA);
    expect(body.items[0]?.role).toBe('owner');
  });

  it('exclut les officines soft-deleted', async () => {
    const owner = await signup('owner@piloo.fr');
    const id = await makeOfficine(owner.userId);
    await grant(owner.userId, id, 'owner');
    await env.handle.db
      .update(officines)
      .set({ deletedAt: new Date() })
      .where(eq(officines.id, id));

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/officines`, {
        headers: { cookie: owner.cookie },
      }),
    );
    const body = (await res.json()) as { items: unknown[] };
    expect(body.items).toHaveLength(0);
  });
});

describe('POST /api/v1/officines', () => {
  it('crée une officine + un partage owner pour le user courant', async () => {
    const me = await signup('me@piloo.fr');

    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ nom: 'Mme Dubois', type: 'patient' }),
      }),
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      nom: string;
      type: string;
      role: string;
    };
    expect(body.nom).toBe('Mme Dubois');
    expect(body.type).toBe('patient');
    expect(body.role).toBe('owner');

    const inserted = await env.handle.db
      .select()
      .from(partages)
      .where(eq(partages.officineId, body.id));
    expect(inserted).toHaveLength(1);
    expect(inserted[0]?.role).toBe('owner');
    expect(inserted[0]?.userId).toBe(me.userId);
  });

  it('renvoie 400 si nom vide', async () => {
    const me = await signup('me@piloo.fr');
    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ nom: '', type: 'patient' }),
      }),
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('validation_error');
  });

  it('renvoie 401 sans credential', async () => {
    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/officines`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ nom: 'X', type: 'perso' }),
      }),
    );
    expect(res.status).toBe(401);
  });
});

describe('GET /api/v1/officines/:id', () => {
  it('autorise les 3 rôles à lire', async () => {
    const o = await signup('o@piloo.fr');
    const officineId = await makeOfficine(o.userId);

    for (const role of ['owner', 'editor', 'viewer'] as const) {
      const u = await signup(`${role}@piloo.fr`);
      await grant(u.userId, officineId, role);

      const { item } = await importHandlers();
      const res = await item.GET(
        new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ id: officineId }) },
      );
      expect(res.status).toBe(200);
      const body = (await res.json()) as { role: string };
      expect(body.role).toBe(role);
    }
  });

  it('renvoie 404 si pas de partage actif', async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);

    const { item } = await importHandlers();
    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
        headers: { cookie: stranger.cookie },
      }),
      { params: Promise.resolve({ id: officineId }) },
    );
    expect(res.status).toBe(404);
  });

  it("renvoie 400 si id n'est pas un uuid", async () => {
    const me = await signup('me@piloo.fr');
    const { item } = await importHandlers();
    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/officines/not-a-uuid`, {
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: 'not-a-uuid' }) },
    );
    expect(res.status).toBe(400);
  });
});

describe('PATCH /api/v1/officines/:id', () => {
  it('owner peut renommer', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ nom: 'Renommée' }),
      }),
      { params: Promise.resolve({ id: officineId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { nom: string };
    expect(body.nom).toBe('Renommée');
  });

  it('viewer ne peut pas updater (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: viewer.cookie },
        body: JSON.stringify({ nom: 'Hacked' }),
      }),
      { params: Promise.resolve({ id: officineId }) },
    );
    expect(res.status).toBe(403);
  });
});

describe('DELETE /api/v1/officines/:id', () => {
  it('owner peut soft-delete', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: officineId }) },
    );
    expect(res.status).toBe(204);

    const [row] = await env.handle.db
      .select({ deletedAt: officines.deletedAt })
      .from(officines)
      .where(eq(officines.id, officineId));
    expect(row?.deletedAt).not.toBeNull();
  });

  it('editor ne peut pas delete (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(editor.userId, officineId, 'editor');

    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}`, {
        method: 'DELETE',
        headers: { cookie: editor.cookie },
      }),
      { params: Promise.resolve({ id: officineId }) },
    );
    expect(res.status).toBe(403);
  });
});
