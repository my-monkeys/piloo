// Tests d'intégration forget-password / reset-password (#63).
//
// Vérifie le contrat Better Auth :
//  - forget-password renvoie 200 même si l'email n'existe pas (anti-énumération)
//  - sendResetPassword appelé avec une URL contenant un token
//  - reset-password avec le bon token bascule le mdp, signIn fonctionne
//  - sessions actives invalidées après reset (revokeSessionsOnPasswordReset)
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

const sentEmails: { to: string; url: string; tag: string }[] = [];

vi.mock('@/lib/email/client', () => ({
  sendEmail: vi.fn((input: { to: string; html: string; tag: string }) => {
    const match = /href="([^"]+)"/.exec(input.html);
    const url = match?.[1] ?? '';
    sentEmails.push({ to: input.to, url, tag: input.tag });
    return Promise.resolve({ ok: true, stubbed: false });
  }),
}));

let env: TestDb;
let auth: AuthInstance;

beforeAll(async () => {
  env = await setupTestDb();
  auth = createAuth({
    db: env.handle.db,
    secret: TEST_SECRET,
    baseURL: BASE_URL,
    // On désactive la vérif email obligatoire pour pouvoir signIn
    // immédiatement après signUp dans les tests.
    requireEmailVerification: false,
  });
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  sentEmails.length = 0;
  await env.handle.client`
    TRUNCATE TABLE sessions, accounts, verifications, users RESTART IDENTITY CASCADE
  `;
});

function postJson(path: string, body: unknown): Request {
  return new Request(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const userBody = {
  email: 'alice@piloo.fr',
  password: 'pass-word-old-123',
  name: 'Alice',
  nom: 'Doe',
  prenom: 'Alice',
  typeCompte: 'particulier' as const,
};

async function signupAndSignin(): Promise<string> {
  await auth.handler(postJson('/api/auth/sign-up/email', userBody));
  const signIn = await auth.handler(
    postJson('/api/auth/sign-in/email', { email: userBody.email, password: userBody.password }),
  );
  const token = signIn.headers.get('set-auth-token');
  if (!token) throw new Error('signin sans bearer token');
  return token;
}

describe('Forget password / reset (#63)', () => {
  it('forget-password renvoie 200 + envoie un mail avec token', async () => {
    await signupAndSignin();
    const res = await auth.handler(
      postJson('/api/auth/request-password-reset', {
        email: userBody.email,
        redirectTo: 'http://localhost:3000/reset-password',
      }),
    );
    expect(res.status).toBe(200);
    const resetMails = sentEmails.filter((e) => e.tag === 'reset-password');
    expect(resetMails).toHaveLength(1);
    expect(resetMails[0]?.to).toBe(userBody.email);
    // BA construit /api/auth/reset-password/{token}?callbackURL=... — token en path.
    expect(resetMails[0]?.url).toMatch(/\/reset-password\/[A-Za-z0-9_-]+\?callbackURL=/);
  });

  it("request-password-reset renvoie 200 même si l'email n'existe pas (anti-énumération)", async () => {
    const res = await auth.handler(
      postJson('/api/auth/request-password-reset', {
        email: 'ghost@piloo.fr',
        redirectTo: 'http://localhost:3000/reset-password',
      }),
    );
    expect(res.status).toBe(200);
    expect(sentEmails.filter((e) => e.tag === 'reset-password')).toHaveLength(0);
  });

  it('reset-password change le mdp et invalide les sessions actives', async () => {
    const oldToken = await signupAndSignin();

    // Sanity : oldToken donne accès à get-session.
    const sessionBefore = await auth.handler(
      new Request(`${BASE_URL}/api/auth/get-session`, {
        headers: { Authorization: `Bearer ${oldToken}` },
      }),
    );
    expect(sessionBefore.status).toBe(200);

    await auth.handler(
      postJson('/api/auth/request-password-reset', {
        email: userBody.email,
        redirectTo: 'http://localhost:3000/reset-password',
      }),
    );
    const resetUrl = sentEmails.find((e) => e.tag === 'reset-password')?.url ?? '';
    expect(resetUrl).not.toBe('');
    // BA met le token en path segment : .../reset-password/{token}?callbackURL=...
    const tokenMatch = /\/reset-password\/([A-Za-z0-9_-]+)/.exec(resetUrl);
    const token = tokenMatch?.[1];
    expect(token).toBeTruthy();

    const newPassword = 'brand-new-pass-456';
    const reset = await auth.handler(
      postJson('/api/auth/reset-password', { token: token!, newPassword }),
    );
    expect(reset.status).toBe(200);

    // L'ancien token de session est invalide.
    const sessionAfter = await auth.handler(
      new Request(`${BASE_URL}/api/auth/get-session`, {
        headers: { Authorization: `Bearer ${oldToken}` },
      }),
    );
    const sessionAfterBody = (await sessionAfter.json()) as { user?: unknown } | null;
    expect(sessionAfterBody?.user).toBeFalsy();

    // SignIn avec le nouveau mdp marche.
    const signInNew = await auth.handler(
      postJson('/api/auth/sign-in/email', { email: userBody.email, password: newPassword }),
    );
    expect(signInNew.status).toBe(200);
    expect(signInNew.headers.get('set-auth-token')).toBeTruthy();

    // SignIn avec l'ancien mdp échoue.
    const signInOld = await auth.handler(
      postJson('/api/auth/sign-in/email', { email: userBody.email, password: userBody.password }),
    );
    expect(signInOld.status).toBeGreaterThanOrEqual(400);
  });
});
