// Tests d'intégration GET /api/v1/me/invitations (#129).
//
// Couvre :
//  - 401 sans cookie
//  - Filtre par email : ne retourne que les invitations adressées à l'user
//  - Filtre pending : exclut acceptées, expirées, supprimées
//  - Format de retour conforme à PendingInvitationsListSchema
import { invitations, officines } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
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
      invitations, partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

afterEach(() => {
  vi.resetModules();
});

async function signup(email: string): Promise<{ userId: string; cookie: string; email: string }> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: `User ${email}`,
        nom: 'Test',
        prenom: 'User',
        typeCompte: 'particulier',
      }),
    }),
  );
  if (res.status !== 200) throw new Error(`signup failed: ${String(res.status)}`);
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie, email };
}

async function makeOfficine(userId: string, nom: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom, type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('insert officine returned no row');
  return row.id;
}

interface MkInvite {
  officineId: string;
  invitedBy: string;
  email: string | null;
  role: 'owner' | 'editor' | 'viewer';
  expiresAt: Date;
  acceptedAt?: Date | null;
  deletedAt?: Date | null;
}

async function makeInvitation(p: MkInvite): Promise<string> {
  const [row] = await env.handle.db
    .insert(invitations)
    .values({
      officineId: p.officineId,
      invitedByUserId: p.invitedBy,
      role: p.role,
      email: p.email,
      expiresAt: p.expiresAt,
      acceptedAt: p.acceptedAt ?? null,
      deletedAt: p.deletedAt ?? null,
    })
    .returning({ id: invitations.id });
  if (!row) throw new Error('insert invitation returned no row');
  return row.id;
}

async function callHandler(cookie?: string): Promise<Response> {
  const { GET } = await import('@/app/api/v1/me/invitations/route');
  return GET(
    new Request(`${BASE_URL}/api/v1/me/invitations`, {
      headers: cookie ? { cookie } : {},
    }),
  );
}

describe('GET /api/v1/me/invitations', () => {
  it('renvoie 401 sans credential', async () => {
    const res = await callHandler();
    expect(res.status).toBe(401);
  });

  it('liste uniquement les invitations adressées à mon email + pending', async () => {
    const inviter = await signup('inviter@piloo.fr');
    const me = await signup('me@piloo.fr');
    const other = await signup('other@piloo.fr');
    const officineId = await makeOfficine(inviter.userId, 'Maison');
    const future = new Date(Date.now() + 24 * 3600_000);
    const past = new Date(Date.now() - 3600_000);

    // Adressée à moi, pending → DOIT apparaître
    const inviteForMe = await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: me.email,
      role: 'editor',
      expiresAt: future,
    });
    // Adressée à quelqu'un d'autre → exclue
    await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: other.email,
      role: 'viewer',
      expiresAt: future,
    });
    // Sans email (lien partagé non personnalisé) → exclue
    await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: null,
      role: 'viewer',
      expiresAt: future,
    });
    // À moi mais expirée → exclue
    await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: me.email,
      role: 'viewer',
      expiresAt: past,
    });
    // À moi mais déjà acceptée → exclue
    await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: me.email,
      role: 'viewer',
      expiresAt: future,
      acceptedAt: new Date(),
    });
    // À moi mais soft-deleted → exclue
    await makeInvitation({
      officineId,
      invitedBy: inviter.userId,
      email: me.email,
      role: 'viewer',
      expiresAt: future,
      deletedAt: new Date(),
    });

    const res = await callHandler(me.cookie);
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      items: {
        token: string;
        officine_id: string;
        officine_nom: string;
        role: string;
        invited_by_name: string;
        expires_at: string;
      }[];
    };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.token).toBe(inviteForMe);
    expect(body.items[0]?.officine_nom).toBe('Maison');
    expect(body.items[0]?.role).toBe('editor');
    expect(body.items[0]?.invited_by_name).toContain('inviter');
  });

  it('retourne une liste vide si rien de pending', async () => {
    const me = await signup('empty@piloo.fr');
    const res = await callHandler(me.cookie);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: unknown[] };
    expect(body.items).toEqual([]);
  });
});
