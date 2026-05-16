// Tests d'intégration /api/v1/devices (#124).
import { devices } from '@piloo/db-schema';
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
      devices, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

afterEach(() => {
  vi.resetModules();
});

interface SignUpResult {
  userId: string;
  cookie: string;
}

async function signup(email: string): Promise<SignUpResult> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password: 'pass-word-1234',
        name: 'Test',
        nom: 'T',
        prenom: 'U',
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
  return {
    list: await import('@/app/api/v1/devices/route'),
    item: await import('@/app/api/v1/devices/[id]/route'),
  };
}

const sampleToken = 'fcm-token-' + 'a'.repeat(40);

function postBody(cookie: string, body: unknown): Request {
  return new Request(`${BASE_URL}/api/v1/devices`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', cookie },
    body: JSON.stringify(body),
  });
}

describe('POST /api/v1/devices', () => {
  it('renvoie 401 sans credential', async () => {
    const { list } = await importHandlers();
    const res = await list.POST(
      new Request(`${BASE_URL}/api/v1/devices`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: sampleToken, platform: 'ios' }),
      }),
    );
    expect(res.status).toBe(401);
  });

  it('renvoie 400 si token trop court', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    const res = await list.POST(postBody(me.cookie, { token: 'short', platform: 'ios' }));
    expect(res.status).toBe(400);
  });

  it('crée un nouveau device → 201 + body Device', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    const res = await list.POST(
      postBody(me.cookie, { token: sampleToken, platform: 'ios', app_version: '0.1.0' }),
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      user_id: string;
      platform: string;
      app_version: string | null;
    };
    expect(body.user_id).toBe(me.userId);
    expect(body.platform).toBe('ios');
    expect(body.app_version).toBe('0.1.0');
  });

  it('réenregistrer le même token → 200 + même id (idempotent)', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    const first = await list.POST(postBody(me.cookie, { token: sampleToken, platform: 'ios' }));
    const firstBody = (await first.json()) as { id: string; last_seen_at: string };

    // 100ms de délai pour différencier les timestamps.
    await new Promise((r) => setTimeout(r, 100));

    const second = await list.POST(
      postBody(me.cookie, { token: sampleToken, platform: 'ios', app_version: '0.2.0' }),
    );
    expect(second.status).toBe(200);
    const secondBody = (await second.json()) as {
      id: string;
      app_version: string | null;
      last_seen_at: string;
    };
    expect(secondBody.id).toBe(firstBody.id);
    expect(secondBody.app_version).toBe('0.2.0');
    expect(secondBody.last_seen_at).not.toBe(firstBody.last_seen_at);
  });

  it('un user → N devices (différents tokens) sans collision', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    await list.POST(postBody(me.cookie, { token: sampleToken + '-1', platform: 'ios' }));
    await list.POST(postBody(me.cookie, { token: sampleToken + '-2', platform: 'android' }));

    const listRes = await list.GET(
      new Request(`${BASE_URL}/api/v1/devices`, { headers: { cookie: me.cookie } }),
    );
    expect(listRes.status).toBe(200);
    const body = (await listRes.json()) as { items: { platform: string }[] };
    expect(body.items).toHaveLength(2);
    expect(body.items.map((i) => i.platform).sort()).toEqual(['android', 'ios']);
  });

  it('réenregistrer un token soft-deleted → undelete (re-login depuis le device)', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    const created = await list.POST(postBody(me.cookie, { token: sampleToken, platform: 'ios' }));
    const { id } = (await created.json()) as { id: string };

    // Soft-delete manuel (simule un FCM UNREGISTERED).
    await env.handle.db.update(devices).set({ deletedAt: new Date() }).where(eq(devices.id, id));

    const reregister = await list.POST(
      postBody(me.cookie, { token: sampleToken, platform: 'ios' }),
    );
    expect(reregister.status).toBe(200); // pas 201 — ligne existante
    const body = (await reregister.json()) as { id: string };
    expect(body.id).toBe(id);

    const [row] = await env.handle.db
      .select({ deletedAt: devices.deletedAt })
      .from(devices)
      .where(eq(devices.id, id));
    expect(row?.deletedAt).toBeNull();
  });
});

describe('GET /api/v1/devices', () => {
  it('renvoie 401 sans credential', async () => {
    const { list } = await importHandlers();
    const res = await list.GET(new Request(`${BASE_URL}/api/v1/devices`));
    expect(res.status).toBe(401);
  });

  it("exclut les devices d'autres users", async () => {
    const me = await signup('a@piloo.fr');
    const other = await signup('b@piloo.fr');
    const { list } = await importHandlers();
    await list.POST(postBody(me.cookie, { token: sampleToken + '-mine', platform: 'ios' }));
    await list.POST(postBody(other.cookie, { token: sampleToken + '-other', platform: 'android' }));

    const listRes = await list.GET(
      new Request(`${BASE_URL}/api/v1/devices`, { headers: { cookie: me.cookie } }),
    );
    const body = (await listRes.json()) as { items: { user_id: string }[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.user_id).toBe(me.userId);
  });

  it('exclut les devices soft-deleted', async () => {
    const me = await signup('a@piloo.fr');
    const { list } = await importHandlers();
    await list.POST(postBody(me.cookie, { token: sampleToken + '-a', platform: 'ios' }));
    const second = await list.POST(
      postBody(me.cookie, { token: sampleToken + '-b', platform: 'android' }),
    );
    const { id } = (await second.json()) as { id: string };
    await env.handle.db.update(devices).set({ deletedAt: new Date() }).where(eq(devices.id, id));

    const listRes = await list.GET(
      new Request(`${BASE_URL}/api/v1/devices`, { headers: { cookie: me.cookie } }),
    );
    const body = (await listRes.json()) as { items: unknown[] };
    expect(body.items).toHaveLength(1);
  });
});

describe('DELETE /api/v1/devices/:id', () => {
  it('soft-delete le device du user courant → 204', async () => {
    const me = await signup('a@piloo.fr');
    const { list, item } = await importHandlers();
    const created = await list.POST(postBody(me.cookie, { token: sampleToken, platform: 'ios' }));
    const { id } = (await created.json()) as { id: string };

    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/devices/${id}`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    expect(res.status).toBe(204);

    const [row] = await env.handle.db
      .select({ deletedAt: devices.deletedAt })
      .from(devices)
      .where(eq(devices.id, id));
    expect(row?.deletedAt).not.toBeNull();
  });

  it("renvoie 404 si device d'un autre user", async () => {
    const me = await signup('a@piloo.fr');
    const other = await signup('b@piloo.fr');
    const { list, item } = await importHandlers();
    const created = await list.POST(
      postBody(other.cookie, { token: sampleToken, platform: 'ios' }),
    );
    const { id } = (await created.json()) as { id: string };

    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/devices/${id}`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    expect(res.status).toBe(404);
  });

  it('renvoie 400 si id mal formé', async () => {
    const me = await signup('a@piloo.fr');
    const { item } = await importHandlers();
    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/devices/not-a-uuid`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: 'not-a-uuid' }) },
    );
    expect(res.status).toBe(400);
  });
});
