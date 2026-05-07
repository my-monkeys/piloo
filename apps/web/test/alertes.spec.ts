// Tests d'intégration /api/v1/alertes (#140).
import { alertes, officines } from '@piloo/db-schema';
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

interface Ctx {
  userId: string;
  cookie: string;
  officineId: string;
}

async function signupAndOfficine(email: string): Promise<Ctx> {
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

  const [off] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: json.user.id })
    .returning({ id: officines.id });
  if (!off) throw new Error('officine');
  return { userId: json.user.id, cookie, officineId: off.id };
}

async function seedAlerte(
  ctx: Ctx,
  type: 'peremption_30j' | 'peremption_7j' | 'stock_bas',
  daysAgo = 0,
): Promise<string> {
  const createdAt = new Date(Date.now() - daysAgo * 86400_000);
  const [a] = await env.handle.db
    .insert(alertes)
    .values({
      officineId: ctx.officineId,
      userId: ctx.userId,
      type,
      payload: { boite_id: crypto.randomUUID() },
      createdAt,
    })
    .returning({ id: alertes.id });
  if (!a) throw new Error('alerte');
  return a.id;
}

async function importHandlers() {
  return {
    list: await import('@/app/api/v1/alertes/route'),
    read: await import('@/app/api/v1/alertes/[id]/read/route'),
  };
}

function listReq(cookie: string, query = ''): Request {
  return new Request(`${BASE_URL}/api/v1/alertes${query}`, { headers: { cookie } });
}

describe('GET /api/v1/alertes', () => {
  it('liste les alertes du user (3 types confondus, ordre récent en tête)', async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    await seedAlerte(ctx, 'peremption_30j', 2);
    await seedAlerte(ctx, 'peremption_7j', 1);
    await seedAlerte(ctx, 'stock_bas', 0);

    const { list } = await importHandlers();
    const res = await list.GET(listReq(ctx.cookie));
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: { type: string }[]; next_cursor: string | null };
    expect(body.items.map((a) => a.type)).toEqual(['stock_bas', 'peremption_7j', 'peremption_30j']);
    expect(body.next_cursor).toBeNull();
  });

  it('filtre par type=stock_bas', async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    await seedAlerte(ctx, 'peremption_30j');
    await seedAlerte(ctx, 'stock_bas');
    await seedAlerte(ctx, 'stock_bas');

    const { list } = await importHandlers();
    const res = await list.GET(listReq(ctx.cookie, '?type=stock_bas'));
    const body = (await res.json()) as { items: { type: string }[] };
    expect(body.items).toHaveLength(2);
    expect(body.items.every((a) => a.type === 'stock_bas')).toBe(true);
  });

  it('filtre unread_only=true exclut les alertes lues', async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    const aLu = await seedAlerte(ctx, 'peremption_30j');
    await seedAlerte(ctx, 'peremption_7j');
    await env.handle.db.update(alertes).set({ lueA: new Date() }).where(eq(alertes.id, aLu));

    const { list } = await importHandlers();
    const res = await list.GET(listReq(ctx.cookie, '?unread_only=true'));
    const body = (await res.json()) as { items: { type: string }[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.type).toBe('peremption_7j');
  });

  it('pagination cursor : limit=2 sur 3 items, page suivante via next_cursor', async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    await seedAlerte(ctx, 'peremption_30j', 2);
    await seedAlerte(ctx, 'peremption_7j', 1);
    await seedAlerte(ctx, 'stock_bas', 0);

    const { list } = await importHandlers();
    const res1 = await list.GET(listReq(ctx.cookie, '?limit=2'));
    const body1 = (await res1.json()) as { items: { type: string }[]; next_cursor: string };
    expect(body1.items.map((a) => a.type)).toEqual(['stock_bas', 'peremption_7j']);
    expect(body1.next_cursor).not.toBeNull();

    const res2 = await list.GET(
      listReq(ctx.cookie, `?limit=2&cursor=${encodeURIComponent(body1.next_cursor)}`),
    );
    const body2 = (await res2.json()) as { items: { type: string }[]; next_cursor: string | null };
    expect(body2.items.map((a) => a.type)).toEqual(['peremption_30j']);
    expect(body2.next_cursor).toBeNull();
  });

  it('isolation : un user ne voit que ses propres alertes', async () => {
    const a = await signupAndOfficine('a@piloo.fr');
    const b = await signupAndOfficine('b@piloo.fr');
    await seedAlerte(a, 'peremption_30j');
    await seedAlerte(b, 'peremption_7j');

    const { list } = await importHandlers();
    const res = await list.GET(listReq(b.cookie));
    const body = (await res.json()) as { items: { type: string }[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.type).toBe('peremption_7j');
  });

  it('renvoie 401 sans credential', async () => {
    const { list } = await importHandlers();
    const res = await list.GET(new Request(`${BASE_URL}/api/v1/alertes`));
    expect(res.status).toBe(401);
  });
});

describe('POST /api/v1/alertes/:id/read', () => {
  it("marque l'alerte comme lue (lue_a non null) et 204", async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    const id = await seedAlerte(ctx, 'peremption_30j');

    const { read } = await importHandlers();
    const res = await read.POST(
      new Request(`${BASE_URL}/api/v1/alertes/${id}/read`, {
        method: 'POST',
        headers: { cookie: ctx.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    expect(res.status).toBe(204);

    const [row] = await env.handle.db.select().from(alertes).where(eq(alertes.id, id));
    expect(row?.lueA).not.toBeNull();
  });

  it('idempotence : 2e appel sur une alerte déjà lue → 204', async () => {
    const ctx = await signupAndOfficine('me@piloo.fr');
    const id = await seedAlerte(ctx, 'peremption_30j');

    const { read } = await importHandlers();
    await read.POST(
      new Request(`${BASE_URL}/api/v1/alertes/${id}/read`, {
        method: 'POST',
        headers: { cookie: ctx.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    const res2 = await read.POST(
      new Request(`${BASE_URL}/api/v1/alertes/${id}/read`, {
        method: 'POST',
        headers: { cookie: ctx.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    expect(res2.status).toBe(204);
  });

  it("404 si l'alerte appartient à un autre user", async () => {
    const a = await signupAndOfficine('a@piloo.fr');
    const b = await signupAndOfficine('b@piloo.fr');
    const id = await seedAlerte(a, 'peremption_30j');

    const { read } = await importHandlers();
    const res = await read.POST(
      new Request(`${BASE_URL}/api/v1/alertes/${id}/read`, {
        method: 'POST',
        headers: { cookie: b.cookie },
      }),
      { params: Promise.resolve({ id }) },
    );
    expect(res.status).toBe(404);
  });

  it('renvoie 401 sans credential', async () => {
    const { read } = await importHandlers();
    const id = crypto.randomUUID();
    const res = await read.POST(
      new Request(`${BASE_URL}/api/v1/alertes/${id}/read`, { method: 'POST' }),
      { params: Promise.resolve({ id }) },
    );
    expect(res.status).toBe(401);
  });
});
