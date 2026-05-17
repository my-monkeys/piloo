// Tests d'intégration /api/v1/me (#162).
import { officines, partages, users } from '@piloo/db-schema';
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
      partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

afterEach(() => {
  vi.resetModules();
});

async function signup(email: string): Promise<{ userId: string; cookie: string }> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: 'Jane Doe',
        nom: 'Doe',
        prenom: 'Jane',
        typeCompte: 'particulier',
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup failed: ${String(res.status)}`);
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie };
}

async function importHandlers() {
  return await import('@/app/api/v1/me/route');
}

describe('GET /api/v1/me', () => {
  it("renvoie le profil de l'utilisateur authentifié", async () => {
    const me = await signup('jane@piloo.fr');
    const { GET } = await importHandlers();

    const res = await GET(new Request(`${BASE_URL}/api/v1/me`, { headers: { cookie: me.cookie } }));
    expect(res.status).toBe(200);
    const body = (await res.json()) as { id: string; email: string; nom: string; prenom: string };
    expect(body.id).toBe(me.userId);
    expect(body.email).toBe('jane@piloo.fr');
    expect(body.nom).toBe('Doe');
    expect(body.prenom).toBe('Jane');
  });

  it('renvoie 401 sans credential', async () => {
    const { GET } = await importHandlers();
    const res = await GET(new Request(`${BASE_URL}/api/v1/me`));
    expect(res.status).toBe(401);
  });
});

describe('PATCH /api/v1/me', () => {
  it('met à jour nom et prenom', async () => {
    const me = await signup('jane@piloo.fr');
    const { PATCH } = await importHandlers();

    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ nom: 'Smith', prenom: 'John' }),
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { nom: string; prenom: string };
    expect(body.nom).toBe('Smith');
    expect(body.prenom).toBe('John');

    const [row] = await env.handle.db
      .select({ nom: users.nom, prenom: users.prenom })
      .from(users)
      .where(eq(users.id, me.userId));
    expect(row?.nom).toBe('Smith');
    expect(row?.prenom).toBe('John');
  });

  it('met à jour telephone (incl. null pour effacer)', async () => {
    const me = await signup('a@piloo.fr');
    const { PATCH } = await importHandlers();
    await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ telephone: '+33612345678' }),
      }),
    );

    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ telephone: null }),
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { telephone: string | null };
    expect(body.telephone).toBeNull();
  });

  it('rejette body vide (400)', async () => {
    const me = await signup('a@piloo.fr');
    const { PATCH } = await importHandlers();
    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({}),
      }),
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('validation_error');
  });

  it("n'autorise PAS la modification du type_compte ni de l'email via PATCH", async () => {
    const me = await signup('a@piloo.fr');
    const { PATCH } = await importHandlers();
    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({
          nom: 'Updated',
          email: 'hacker@piloo.fr',
          type_compte: 'pro',
        }),
      }),
    );
    // Zod strict mode passe — les champs en trop sont ignorés par défaut.
    expect(res.status).toBe(200);

    const [row] = await env.handle.db
      .select({ email: users.email, typeCompte: users.typeCompte })
      .from(users)
      .where(eq(users.id, me.userId));
    expect(row?.email).toBe('a@piloo.fr');
    expect(row?.typeCompte).toBe('particulier');
  });

  it('renvoie 401 sans credential', async () => {
    const { PATCH } = await importHandlers();
    const res = await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ nom: 'X' }),
      }),
    );
    expect(res.status).toBe(401);
  });

  // Sanity check : la PATCH ne touche pas les officines de l'user.
  it("ne modifie pas les officines de l'utilisateur", async () => {
    const me = await signup('a@piloo.fr');
    const [off] = await env.handle.db
      .insert(officines)
      .values({ nom: 'M', type: 'perso', proprietaireUserId: me.userId })
      .returning({ id: officines.id });
    if (!off) throw new Error('off');
    await env.handle.db.insert(partages).values({
      userId: me.userId,
      officineId: off.id,
      role: 'owner',
      invitedAt: new Date(),
      acceptedAt: new Date(),
    });

    const { PATCH } = await importHandlers();
    await PATCH(
      new Request(`${BASE_URL}/api/v1/me`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ nom: 'Changed' }),
      }),
    );

    const [row] = await env.handle.db
      .select({ nom: officines.nom })
      .from(officines)
      .where(eq(officines.id, off.id));
    expect(row?.nom).toBe('M');
  });
});
