// Tests d'intégration pour le flow vérification email magic link 1h (#62).
//
// Vérifie le contrat côté Better Auth quand `requireEmailVerification: true` :
//   - signUp répond 200 mais ne pose pas de session (pas de set-auth-token)
//   - signIn renvoie 403 EMAIL_NOT_VERIFIED tant que verify-email n'a pas été appelé
//   - sendVerificationEmail appelle bien notre callback (qu'on intercepte
//     en stub via les logs du email/client en mode dégradé)
//   - verify-email avec le bon token bascule emailVerified=true et autorise signIn
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

const sentEmails: { to: string; url: string }[] = [];

// Capture des emails envoyés via le hook Better Auth en interceptant notre
// client `sendEmail`. vi.mock est hoisté en haut du fichier — c'est volontaire.
vi.mock('@/lib/email/client', () => ({
  sendEmail: vi.fn((input: { to: string; html: string }) => {
    const match = /href="([^"]+)"/.exec(input.html);
    const url = match?.[1] ?? '';
    sentEmails.push({ to: input.to, url });
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
    requireEmailVerification: true,
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

const signupBody = {
  email: 'bob@piloo.fr',
  password: 'pass-word-1234',
  name: 'Bob Doe',
  nom: 'Doe',
  prenom: 'Bob',
  typeCompte: 'particulier' as const,
};

describe('Email verification flow (#62)', () => {
  it('signUp ne pose pas de session, envoie un magic link', async () => {
    const res = await auth.handler(postJson('/api/auth/sign-up/email', signupBody));
    expect(res.status).toBe(200);
    // Pas de session = pas de set-auth-token côté mobile.
    expect(res.headers.get('set-auth-token')).toBeNull();
    // Un mail a été envoyé.
    expect(sentEmails).toHaveLength(1);
    expect(sentEmails[0]?.to).toBe('bob@piloo.fr');
    expect(sentEmails[0]?.url).toContain('/api/auth/verify-email');
    expect(sentEmails[0]?.url).toContain('token=');
  });

  it("signIn refuse EMAIL_NOT_VERIFIED tant que le lien n'est pas cliqué", async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', signupBody));
    const res = await auth.handler(
      postJson('/api/auth/sign-in/email', {
        email: signupBody.email,
        password: signupBody.password,
      }),
    );
    expect(res.status).toBeGreaterThanOrEqual(400);
    const body = (await res.json()) as { code?: string };
    expect(body.code).toBe('EMAIL_NOT_VERIFIED');
  });

  it('clic sur le lien magique → emailVerified, signIn fonctionne', async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', signupBody));
    const verifyUrl = sentEmails[0]?.url ?? '';
    expect(verifyUrl).not.toBe('');

    const verifyRes = await auth.handler(new Request(verifyUrl, { method: 'GET' }));
    // Better Auth peut renvoyer 200 ou 302 selon callbackURL.
    expect([200, 302]).toContain(verifyRes.status);

    const signIn = await auth.handler(
      postJson('/api/auth/sign-in/email', {
        email: signupBody.email,
        password: signupBody.password,
      }),
    );
    expect(signIn.status).toBe(200);
    expect(signIn.headers.get('set-auth-token')).toBeTruthy();
  });

  it('send-verification-email réémet un lien', async () => {
    await auth.handler(postJson('/api/auth/sign-up/email', signupBody));
    expect(sentEmails).toHaveLength(1);

    const resend = await auth.handler(
      postJson('/api/auth/send-verification-email', { email: signupBody.email }),
    );
    expect(resend.status).toBe(200);
    expect(sentEmails).toHaveLength(2);
    expect(sentEmails[1]?.to).toBe(signupBody.email);
  });
});
