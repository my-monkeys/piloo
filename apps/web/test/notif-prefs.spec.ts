// Tests /api/v1/me/preferences/notifications (#138).
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

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
      sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

async function signup(email: string): Promise<{ cookie: string }> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: 'T',
        nom: 'N',
        prenom: 'P',
        typeCompte: 'pro',
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup ${String(res.status)}`);
  return { cookie: res.headers.get('set-cookie') ?? '' };
}

async function importHandler() {
  return import('@/app/api/v1/me/preferences/notifications/route');
}

const allOff = {
  rappel_prise: { push: false, email: false, sms: false },
  peremption: { push: false, email: false, sms: false },
  stock_bas: { push: false, email: false, sms: false },
  partage: { push: false, email: false, sms: false },
  manque_signale: { push: false, email: false, sms: false },
};

describe('GET /me/preferences/notifications', () => {
  it('renvoie les défauts produit si jamais customisé', async () => {
    const me = await signup('me@piloo.fr');
    const { GET } = await importHandler();
    const res = await GET(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        headers: { cookie: me.cookie },
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { rappel_prise: { push: boolean } };
    expect(body.rappel_prise.push).toBe(true);
  });

  it('renvoie 401 sans credential', async () => {
    const { GET } = await importHandler();
    const res = await GET(new Request(`${BASE_URL}/api/v1/me/preferences/notifications`));
    expect(res.status).toBe(401);
  });
});

describe('PUT /me/preferences/notifications', () => {
  it('persiste les préférences puis le GET les ressort identiques', async () => {
    const me = await signup('me@piloo.fr');
    const { PUT, GET } = await importHandler();

    const putRes = await PUT(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        method: 'PUT',
        headers: { cookie: me.cookie, 'Content-Type': 'application/json' },
        body: JSON.stringify(allOff),
      }),
    );
    expect(putRes.status).toBe(200);

    const getRes = await GET(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        headers: { cookie: me.cookie },
      }),
    );
    const body = (await getRes.json()) as typeof allOff;
    expect(body).toEqual(allOff);
  });

  it('rejette un body partiel (PUT = remplacement complet)', async () => {
    const me = await signup('me@piloo.fr');
    const { PUT } = await importHandler();
    const res = await PUT(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        method: 'PUT',
        headers: { cookie: me.cookie, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rappel_prise: { push: false, email: false, sms: false } }),
      }),
    );
    expect(res.status).toBe(400);
  });

  it("isolation : un user ne peut pas écraser les préférences d'un autre", async () => {
    const a = await signup('a@piloo.fr');
    const b = await signup('b@piloo.fr');
    const { PUT, GET } = await importHandler();

    await PUT(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        method: 'PUT',
        headers: { cookie: a.cookie, 'Content-Type': 'application/json' },
        body: JSON.stringify(allOff),
      }),
    );

    const resB = await GET(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        headers: { cookie: b.cookie },
      }),
    );
    const bodyB = (await resB.json()) as { rappel_prise: { push: boolean } };
    // B garde les défauts (true), A a passé tout en false.
    expect(bodyB.rappel_prise.push).toBe(true);
  });

  it('renvoie 401 sans credential', async () => {
    const { PUT } = await importHandler();
    const res = await PUT(
      new Request(`${BASE_URL}/api/v1/me/preferences/notifications`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(allOff),
      }),
    );
    expect(res.status).toBe(401);
  });
});
