// Tests d'intégration /api/v1/rappels (#327).
import { rappels } from '@piloo/db-schema';
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
    TRUNCATE TABLE rappels, partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

async function signup(email: string): Promise<{ userId: string; cookie: string }> {
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

async function handlers() {
  return {
    list: await import('@/app/api/v1/rappels/route'),
    item: await import('@/app/api/v1/rappels/[id]/route'),
  };
}

function jsonReq(url: string, cookie: string, method: string, body?: unknown): Request {
  return new Request(url, {
    method,
    headers: {
      cookie,
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

describe('POST /api/v1/rappels', () => {
  it('crée un rappel avec heure normalisée HH:MM → HH:MM:SS', async () => {
    const { cookie, userId } = await signup('me@piloo.fr');
    const { list } = await handlers();
    const res = await list.POST(
      jsonReq(`${BASE_URL}/api/v1/rappels`, cookie, 'POST', {
        label: 'Pilule',
        heure: '08:00',
      }),
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      heure: string;
      user_id: string;
      actif: boolean;
    };
    expect(body.heure).toBe('08:00:00');
    expect(body.user_id).toBe(userId);
    expect(body.actif).toBe(true);
  });

  it('rejette body invalide (heure mal formée)', async () => {
    const { cookie } = await signup('me@piloo.fr');
    const { list } = await handlers();
    const res = await list.POST(
      jsonReq(`${BASE_URL}/api/v1/rappels`, cookie, 'POST', {
        label: 'Pilule',
        heure: '25:99',
      }),
    );
    expect(res.status).toBe(400);
  });

  it('rejette si non authentifié', async () => {
    const { list } = await handlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/rappels`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ label: 'X', heure: '08:00' }),
      }),
    );
    expect(res.status).toBe(401);
  });
});

describe('GET /api/v1/rappels', () => {
  it('liste les rappels du user, masque ceux des autres', async () => {
    const a = await signup('a@piloo.fr');
    const b = await signup('b@piloo.fr');
    const { list } = await handlers();

    await list.POST(
      jsonReq(`${BASE_URL}/api/v1/rappels`, a.cookie, 'POST', { label: 'A1', heure: '08:00' }),
    );
    await list.POST(
      jsonReq(`${BASE_URL}/api/v1/rappels`, a.cookie, 'POST', { label: 'A2', heure: '20:00' }),
    );
    await list.POST(
      jsonReq(`${BASE_URL}/api/v1/rappels`, b.cookie, 'POST', { label: 'B1', heure: '12:00' }),
    );

    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/rappels`, { headers: { cookie: a.cookie } }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: { label: string }[] };
    expect(body.items.map((r) => r.label).sort()).toEqual(['A1', 'A2']);
  });
});

describe('PATCH /api/v1/rappels/{id}', () => {
  it('toggle actif false → true', async () => {
    const { cookie } = await signup('me@piloo.fr');
    const { list, item } = await handlers();
    const created = (await (
      await list.POST(
        jsonReq(`${BASE_URL}/api/v1/rappels`, cookie, 'POST', { label: 'P', heure: '08:00' }),
      )
    ).json()) as { id: string };

    const res = await item.PATCH(
      jsonReq(`${BASE_URL}/api/v1/rappels/${created.id}`, cookie, 'PATCH', { actif: false }),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { actif: boolean };
    expect(body.actif).toBe(false);
  });

  it('404 si le rappel appartient à un autre user', async () => {
    const a = await signup('a@piloo.fr');
    const b = await signup('b@piloo.fr');
    const { list, item } = await handlers();
    const created = (await (
      await list.POST(
        jsonReq(`${BASE_URL}/api/v1/rappels`, a.cookie, 'POST', { label: 'A', heure: '08:00' }),
      )
    ).json()) as { id: string };

    const res = await item.PATCH(
      jsonReq(`${BASE_URL}/api/v1/rappels/${created.id}`, b.cookie, 'PATCH', { actif: false }),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res.status).toBe(404);
  });
});

describe('DELETE /api/v1/rappels/{id}', () => {
  it('soft-delete : la row reste en DB avec deleted_at posé', async () => {
    const { cookie } = await signup('me@piloo.fr');
    const { list, item } = await handlers();
    const created = (await (
      await list.POST(
        jsonReq(`${BASE_URL}/api/v1/rappels`, cookie, 'POST', { label: 'P', heure: '08:00' }),
      )
    ).json()) as { id: string };

    const res = await item.DELETE(
      jsonReq(`${BASE_URL}/api/v1/rappels/${created.id}`, cookie, 'DELETE'),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res.status).toBe(204);

    const rows = await env.handle.db.select().from(rappels).where(eq(rappels.id, created.id));
    expect(rows).toHaveLength(1);
    expect(rows[0]?.deletedAt).not.toBeNull();

    // Re-DELETE → 404 (soft-deleted = invisible).
    const res2 = await item.DELETE(
      jsonReq(`${BASE_URL}/api/v1/rappels/${created.id}`, cookie, 'DELETE'),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res2.status).toBe(404);
  });
});
