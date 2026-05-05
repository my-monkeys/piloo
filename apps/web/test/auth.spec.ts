// Tests d'intégration Better Auth (#40, AC "Tests d'intégration").
// Exécute le handler Better Auth contre un Postgres jetable (testcontainers)
// pour couvrir les flux signup / signin / get-session / signout via cookie web
// ET via bearer token mobile (plugin `bearer()` activé).
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';

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
    TRUNCATE TABLE sessions, accounts, verifications, users RESTART IDENTITY CASCADE
  `;
});

interface SignUpBody {
  email: string;
  password: string;
  name: string;
  nom: string;
  prenom: string;
  typeCompte: 'particulier' | 'pro';
  telephone?: string;
}

function postJson(path: string, body: unknown, headers: Record<string, string> = {}): Request {
  return new Request(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

const validSignUp = (overrides: Partial<SignUpBody> = {}): SignUpBody => ({
  email: 'alice@piloo.fr',
  password: 'pass-word-1234',
  name: 'Alice Doe',
  nom: 'Doe',
  prenom: 'Alice',
  typeCompte: 'particulier',
  ...overrides,
});

describe('POST /api/auth/sign-up/email', () => {
  it('crée un user + session, renvoie cookie + bearer token', async () => {
    const res = await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));

    expect(res.status).toBe(200);
    const setCookie = res.headers.get('set-cookie');
    expect(setCookie).toMatch(/better-auth\.session_token=/);
    expect(res.headers.get('set-auth-token')).toBeTruthy();

    const json = (await res.json()) as { user: { email: string; nom: string } };
    expect(json.user.email).toBe('alice@piloo.fr');
    expect(json.user.nom).toBe('Doe');
  });

  it('rejette un signup sans champ requis (validation_error)', async () => {
    const res = await auth.handler(
      postJson('/api/auth/sign-up/email', { email: 'bob@piloo.fr', password: 'short' }),
    );
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(res.status).toBeLessThan(500);
  });

  it('rejette un email déjà utilisé', async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    const second = await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    expect(second.status).toBeGreaterThanOrEqual(400);
    expect(second.status).toBeLessThan(500);
  });
});

describe('POST /api/auth/sign-in/email', () => {
  it('connecte un user existant et renvoie une session', async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));

    const res = await auth.handler(
      postJson('/api/auth/sign-in/email', {
        email: 'alice@piloo.fr',
        password: 'pass-word-1234',
      }),
    );

    expect(res.status).toBe(200);
    expect(res.headers.get('set-cookie')).toMatch(/better-auth\.session_token=/);
    expect(res.headers.get('set-auth-token')).toBeTruthy();
  });

  it('rejette un mauvais mot de passe', async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    const res = await auth.handler(
      postJson('/api/auth/sign-in/email', {
        email: 'alice@piloo.fr',
        password: 'wrong-password',
      }),
    );
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(res.status).toBeLessThan(500);
  });
});

describe('GET /api/auth/get-session', () => {
  it('résout la session via cookie (web)', async () => {
    const signup = await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    const cookie = signup.headers.get('set-cookie') ?? '';

    const res = await auth.handler(
      new Request(`${BASE_URL}/api/auth/get-session`, { headers: { cookie } }),
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as { user: { email: string } } | null;
    expect(json?.user.email).toBe('alice@piloo.fr');
  });

  it('résout la session via bearer token (mobile)', async () => {
    const signup = await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    const token = signup.headers.get('set-auth-token');
    expect(token).toBeTruthy();

    const res = await auth.handler(
      new Request(`${BASE_URL}/api/auth/get-session`, {
        headers: { authorization: `Bearer ${token ?? ''}` },
      }),
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as { user: { email: string } } | null;
    expect(json?.user.email).toBe('alice@piloo.fr');
  });

  it('renvoie null sans credential', async () => {
    const res = await auth.handler(new Request(`${BASE_URL}/api/auth/get-session`));
    expect(res.status).toBe(200);
    const json: unknown = await res.json();
    expect(json).toBeNull();
  });
});

describe('POST /api/auth/sign-out', () => {
  it('invalide la session courante', async () => {
    const signup = await auth.handler(postJson('/api/auth/sign-up/email', validSignUp()));
    const cookie = signup.headers.get('set-cookie') ?? '';

    const signout = await auth.handler(postJson('/api/auth/sign-out', {}, { cookie }));
    expect(signout.status).toBe(200);

    const after = await auth.handler(
      new Request(`${BASE_URL}/api/auth/get-session`, { headers: { cookie } }),
    );
    expect(after.status).toBe(200);
    const json: unknown = await after.json();
    expect(json).toBeNull();
  });
});
