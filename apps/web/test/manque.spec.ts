// Tests POST /api/v1/officines/:id/signaler-manque (#147).
import { alertes, officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
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
      alertes, partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

interface User {
  userId: string;
  cookie: string;
}

async function signup(email: string): Promise<User> {
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
  const cookie = res.headers.get('set-cookie') ?? '';
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id, cookie };
}

async function makeOfficine(ownerUserId: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: ownerUserId })
    .returning({ id: officines.id });
  if (!row) throw new Error('officine');
  return row.id;
}

async function grant(
  userId: string,
  officineId: string,
  role: 'owner' | 'editor' | 'viewer',
): Promise<void> {
  const now = new Date();
  await env.handle.db.insert(partages).values({
    userId,
    officineId,
    role,
    invitedAt: now,
    acceptedAt: now,
  });
}

async function importHandler() {
  return import('@/app/api/v1/officines/[officineId]/signaler-manque/route');
}

function req(cookie: string, officineId: string, body: unknown): Request {
  return new Request(`${BASE_URL}/api/v1/officines/${officineId}/signaler-manque`, {
    method: 'POST',
    headers: { cookie, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

describe('POST /api/v1/officines/:id/signaler-manque', () => {
  it('viewer signale → alerte créée pour owner + editor (pas viewer, pas signaleur)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const otherViewer = await signup('viewer2@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');
    await grant(viewer.userId, officineId, 'viewer');
    await grant(otherViewer.userId, officineId, 'viewer');

    const handler = await importHandler();
    const res = await handler.POST(
      req(viewer.cookie, officineId, { cip13: '3400930000019', message: 'Plus de Doliprane' }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as { alertes_creees: number };
    expect(body.alertes_creees).toBe(2);

    const rows = await env.handle.db
      .select()
      .from(alertes)
      .where(eq(alertes.type, 'manque_signale'));
    const userIds = rows.map((r) => r.userId).sort();
    expect(userIds).toEqual([owner.userId, editor.userId].sort());
    expect(rows[0]?.payload).toMatchObject({
      signale_par: viewer.userId,
      cip13: '3400930000019',
      message: 'Plus de Doliprane',
    });
  });

  it('owner signale tout seul → 0 alerte (pas de destinataire à part lui)', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const handler = await importHandler();
    const res = await handler.POST(req(owner.cookie, officineId, { libelle: 'Doliprane' }), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(201);
    const body = (await res.json()) as { alertes_creees: number };
    expect(body.alertes_creees).toBe(0);
  });

  it('editor signale → alerte créée pour owner uniquement (pas pour lui-même)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    await grant(editor.userId, officineId, 'editor');

    const handler = await importHandler();
    const res = await handler.POST(req(editor.cookie, officineId, { cip13: '3400930000019' }), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(201);
    const body = (await res.json()) as { alertes_creees: number };
    expect(body.alertes_creees).toBe(1);
    const rows = await env.handle.db.select().from(alertes);
    expect(rows[0]?.userId).toBe(owner.userId);
  });

  it('user sans partage → 404', async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const handler = await importHandler();
    const res = await handler.POST(req(stranger.cookie, officineId, { cip13: '3400930000019' }), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(404);
  });

  it('body sans cip13 ni libelle → 400', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const handler = await importHandler();
    const res = await handler.POST(req(owner.cookie, officineId, { message: 'rien' }), {
      params: Promise.resolve({ officineId }),
    });
    expect(res.status).toBe(400);
  });

  it('renvoie 401 sans credential', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);

    const handler = await importHandler();
    const res = await handler.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/signaler-manque`, {
        method: 'POST',
        body: JSON.stringify({ cip13: '3400930000019' }),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(401);
  });
});
