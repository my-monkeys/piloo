// Tests d'intégration envoi email invitation (#127).
//
// Vérifie que :
//  - POST /v1/officines/{officineId}/invitations avec email envoie un mail
//  - Sans email, pas de mail (lien partagé manuellement)
//  - Le mail contient bien officineNom, inviteur, rôle, lien token
import { officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';
import type * as AuthServerModule from '@/lib/auth/server';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

const sentEmails: { to: string; tag: string; html: string; subject: string }[] = [];

vi.mock('@/lib/email/client', () => ({
  sendEmail: vi.fn((input: { to: string; tag: string; html: string; subject: string }) => {
    sentEmails.push(input);
    return Promise.resolve({ ok: true, stubbed: false });
  }),
}));

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
  sentEmails.length = 0;
  await env.handle.client`
    TRUNCATE TABLE
      invitations, partages, officines, sessions, accounts, verifications, users
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
        name: `User ${email}`,
        nom: 'Doe',
        prenom: 'User',
        typeCompte: 'particulier',
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup failed: ${String(res.status)}`);
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie };
}

async function makeOfficine(userId: string, nom: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom, type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('insert officine returned no row');
  await env.handle.db.insert(partages).values({
    userId,
    officineId: row.id,
    role: 'owner',
    invitedAt: new Date(),
    acceptedAt: new Date(),
  });
  return row.id;
}

async function postInvitation(
  cookie: string,
  officineId: string,
  body: { role: 'owner' | 'editor' | 'viewer'; email?: string | null },
): Promise<Response> {
  const { POST } = await import('@/app/api/v1/officines/[officineId]/invitations/route');
  return POST(
    new Request(`${BASE_URL}/api/v1/officines/${officineId}/invitations`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', cookie },
      body: JSON.stringify(body),
    }),
    { params: Promise.resolve({ officineId }) },
  );
}

describe('Email invitation (#127)', () => {
  it("envoie un mail à l'invité quand l'email est fourni", async () => {
    const owner = await signup('maxime@piloo.fr');
    const officineId = await makeOfficine(owner.userId, 'Maison');

    const res = await postInvitation(owner.cookie, officineId, {
      role: 'editor',
      email: 'partner@piloo.fr',
    });
    expect(res.status).toBe(201);

    // Le sendEmail est en void (best-effort) → on attend qu'il flush.
    await new Promise((r) => setTimeout(r, 50));

    const invitationMails = sentEmails.filter((e) => e.tag === 'invitation');
    expect(invitationMails).toHaveLength(1);
    const mail = invitationMails[0]!;
    expect(mail.to).toBe('partner@piloo.fr');
    expect(mail.subject).toContain('Maison');
    expect(mail.html).toContain('éditeur');
    expect(mail.html).toMatch(/\/invitations\/[a-f0-9-]{36}/);
  });

  it("n'envoie pas de mail si email absent (lien partagé manuellement)", async () => {
    const owner = await signup('solo@piloo.fr');
    const officineId = await makeOfficine(owner.userId, 'Cabane');

    const res = await postInvitation(owner.cookie, officineId, { role: 'viewer', email: null });
    expect(res.status).toBe(201);
    await new Promise((r) => setTimeout(r, 50));

    expect(sentEmails.filter((e) => e.tag === 'invitation')).toHaveLength(0);
  });
});
