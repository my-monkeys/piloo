// Tests d'intégration des guards d'auth (#43).
// Couverture : requireAuth (avec/sans session, cookie + bearer), requireRole
// (3 rôles owner/editor/viewer, rôle absent, officine inconnue, partage
// soft-deleted).
import { officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';
import { requireAuth, requireRole, type Role } from '@/lib/auth/guards';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

let env: TestDb;
let auth: AuthInstance;

beforeAll(async () => {
  env = await setupTestDb();
  auth = createAuth({ db: env.handle.db, secret: TEST_SECRET, baseURL: BASE_URL });
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

interface Fixture {
  user: { id: string; email: string };
  officine: { id: string };
  cookie: string;
  bearer: string;
}

async function signupFixture(email = 'alice@piloo.fr'): Promise<Fixture> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: 'Alice Doe',
        nom: 'Doe',
        prenom: 'Alice',
        typeCompte: 'particulier',
      }),
    }),
  );
  if (res.status !== 200) {
    throw new Error(`signup failed: ${String(res.status)}`);
  }
  const cookie = res.headers.get('set-cookie') ?? '';
  const bearer = res.headers.get('set-auth-token') ?? '';
  const body = (await res.json()) as { user: { id: string; email: string } };

  const [officine] = await env.handle.db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: body.user.id })
    .returning();
  if (!officine) throw new Error('officine insert returned no row');

  return { user: body.user, officine: { id: officine.id }, cookie, bearer };
}

async function grantRole(userId: string, officineId: string, role: Role): Promise<void> {
  await env.handle.db.insert(partages).values({
    userId,
    officineId,
    role,
    invitedAt: new Date(),
    acceptedAt: new Date(),
  });
}

describe('requireAuth', () => {
  it('renvoie la session via cookie web', async () => {
    const f = await signupFixture();
    const result = await requireAuth(new Request(BASE_URL, { headers: { cookie: f.cookie } }), {
      auth,
    });
    expect(result).not.toBeInstanceOf(Response);
    if (result instanceof Response) return;
    expect(result.user.email).toBe(f.user.email);
    expect(result.session.id).toBeTruthy();
  });

  it('renvoie la session via bearer token mobile', async () => {
    const f = await signupFixture();
    const result = await requireAuth(
      new Request(BASE_URL, { headers: { authorization: `Bearer ${f.bearer}` } }),
      { auth },
    );
    expect(result).not.toBeInstanceOf(Response);
    if (result instanceof Response) return;
    expect(result.user.email).toBe(f.user.email);
  });

  it('renvoie 401 unauthorized sans credential', async () => {
    const result = await requireAuth(new Request(BASE_URL), { auth });
    expect(result).toBeInstanceOf(Response);
    if (!(result instanceof Response)) return;
    expect(result.status).toBe(401);
    const body = (await result.json()) as { error: { code: string } };
    expect(body.error.code).toBe('unauthorized');
  });
});

describe('requireRole', () => {
  it.each([
    ['owner', ['owner']],
    ['editor', ['editor']],
    ['viewer', ['viewer']],
  ] as const)('autorise un %s pour allowedRoles=[%s]', async (role, allowed) => {
    const f = await signupFixture();
    await grantRole(f.user.id, f.officine.id, role);

    const result = await requireRole(f.user.id, f.officine.id, allowed, {
      db: env.handle.db,
    });

    expect(result).not.toBeInstanceOf(Response);
    if (result instanceof Response) return;
    expect(result.role).toBe(role);
  });

  it('autorise un owner ou un editor (allowedRoles multi)', async () => {
    const f = await signupFixture();
    await grantRole(f.user.id, f.officine.id, 'editor');

    const result = await requireRole(f.user.id, f.officine.id, ['owner', 'editor'], {
      db: env.handle.db,
    });

    expect(result).not.toBeInstanceOf(Response);
    if (result instanceof Response) return;
    expect(result.role).toBe('editor');
  });

  it('renvoie 403 forbidden si rôle insuffisant', async () => {
    const f = await signupFixture();
    await grantRole(f.user.id, f.officine.id, 'viewer');

    const result = await requireRole(f.user.id, f.officine.id, ['owner', 'editor'], {
      db: env.handle.db,
    });

    expect(result).toBeInstanceOf(Response);
    if (!(result instanceof Response)) return;
    expect(result.status).toBe(403);
    const body = (await result.json()) as {
      error: { code: string; details: { current_role: string } };
    };
    expect(body.error.code).toBe('forbidden');
    expect(body.error.details.current_role).toBe('viewer');
  });

  it('renvoie 404 not_found si aucun partage (officine inconnue ou non partagée)', async () => {
    const f = await signupFixture();
    // Pas de partage inséré → comme si l'officine n'existait pas pour ce user.
    const result = await requireRole(f.user.id, f.officine.id, ['owner'], {
      db: env.handle.db,
    });

    expect(result).toBeInstanceOf(Response);
    if (!(result instanceof Response)) return;
    expect(result.status).toBe(404);
    const body = (await result.json()) as { error: { code: string } };
    expect(body.error.code).toBe('not_found');
  });

  it('ignore les partages soft-deleted', async () => {
    const f = await signupFixture();
    const [row] = await env.handle.db
      .insert(partages)
      .values({
        userId: f.user.id,
        officineId: f.officine.id,
        role: 'owner',
        invitedAt: new Date(),
        acceptedAt: new Date(),
        deletedAt: new Date(),
      })
      .returning();
    expect(row).toBeTruthy();

    const result = await requireRole(f.user.id, f.officine.id, ['owner'], {
      db: env.handle.db,
    });

    expect(result).toBeInstanceOf(Response);
    if (!(result instanceof Response)) return;
    expect(result.status).toBe(404);
  });
});
