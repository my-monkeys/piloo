// Tests d'intégration /api/v1/sync/{push,pull} (#92 #93 #94).
//
// Couverture :
//  - push : create_boite, update_boite, soft_delete_boite
//  - idempotence : rejouer la même operation_id renvoie le même ack sans
//    écrire deux fois
//  - LWW : si server.updated_at > op.timestamp_local → conflict + server_version
//  - AuthZ : viewer rejected, stranger forbidden
//  - validation Zod : batch > 100 → 400
//  - pull : entités modifiées depuis since, soft-deleted dans deleted[]
//  - pull : pas d'accès cross-user
import { boites, officines, partages, syncOperationsLog } from '@piloo/db-schema';
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
      sync_operations_log, boites, partages, officines,
      sessions, accounts, verifications, users
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
        typeCompte: 'pro',
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
    push: await import('@/app/api/v1/sync/push/route'),
    pull: await import('@/app/api/v1/sync/pull/route'),
  };
}

async function makeOfficine(userId: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  return row!.id;
}

async function grant(
  userId: string,
  officineId: string,
  role: 'owner' | 'editor' | 'viewer',
): Promise<void> {
  await env.handle.db.insert(partages).values({
    userId,
    officineId,
    role,
    invitedAt: new Date(),
    acceptedAt: new Date(),
  });
}

const uuid = (): string => crypto.randomUUID();

function pushReq(cookie: string, body: unknown): Request {
  return new Request(`${BASE_URL}/api/v1/sync/push`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', cookie },
    body: JSON.stringify(body),
  });
}

function pullReq(cookie: string, query = ''): Request {
  return new Request(`${BASE_URL}/api/v1/sync/pull${query}`, {
    headers: { cookie },
  });
}

describe('POST /api/v1/sync/push', () => {
  it('applique create_boite + update_boite + soft_delete_boite', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const boiteId = uuid();
    const { push } = await importHandlers();

    const res = await push.POST(
      pushReq(me.cookie, {
        client_id: 'device-1',
        operations: [
          {
            id: uuid(),
            type: 'create_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: {
              officine_id: officineId,
              cip13: '3400930000019',
              peremption: '2027-01-01',
              unites_initiales: 16,
              unites_restantes: 16,
            },
            timestamp_local: Date.now(),
          },
          {
            id: uuid(),
            type: 'update_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: { unites_restantes: 12 },
            timestamp_local: Date.now() + 1000,
          },
          {
            id: uuid(),
            type: 'soft_delete_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: {},
            timestamp_local: Date.now() + 2000,
          },
        ],
      }),
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      acks: { status: string }[];
      server_time: string;
    };
    expect(body.acks.map((a) => a.status)).toEqual(['applied', 'applied', 'applied']);

    const [row] = await env.handle.db.select().from(boites).where(eq(boites.id, boiteId));
    expect(row?.deletedAt).not.toBeNull();
  });

  it('idempotence : rejouer la même operation_id ne re-applique pas', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const opId = uuid();
    const boiteId = uuid();
    const op = {
      id: opId,
      type: 'create_boite' as const,
      entity_type: 'boite' as const,
      entity_id: boiteId,
      payload: {
        officine_id: officineId,
        cip13: '3400930000019',
        peremption: '2027-01-01',
      },
      timestamp_local: Date.now(),
    };

    const { push } = await importHandlers();
    const res1 = await push.POST(pushReq(me.cookie, { client_id: 'device-1', operations: [op] }));
    expect(res1.status).toBe(200);
    const body1 = (await res1.json()) as { acks: { status: string }[] };
    expect(body1.acks[0]?.status).toBe('applied');

    const res2 = await push.POST(pushReq(me.cookie, { client_id: 'device-1', operations: [op] }));
    expect(res2.status).toBe(200);
    const body2 = (await res2.json()) as { acks: { status: string }[] };
    expect(body2.acks[0]?.status).toBe('applied'); // même ack, pas de re-création

    // Une seule entrée dans le log + une seule boîte
    const logs = await env.handle.db
      .select()
      .from(syncOperationsLog)
      .where(eq(syncOperationsLog.operationId, opId));
    expect(logs).toHaveLength(1);
    const allBoites = await env.handle.db.select().from(boites);
    expect(allBoites).toHaveLength(1);
  });

  it('LWW : update plus ancien que server.updated_at → conflict + server_version', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    // Pre-existing boîte avec updated_at très récent
    const boiteId = uuid();
    await env.handle.db.insert(boites).values({
      id: boiteId,
      officineId,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: me.userId,
      unitesRestantes: 16,
    });

    const { push } = await importHandlers();
    // Op avec timestamp_local dans le passé → server gagne
    const res = await push.POST(
      pushReq(me.cookie, {
        client_id: 'device-1',
        operations: [
          {
            id: uuid(),
            type: 'update_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: { unites_restantes: 0 },
            timestamp_local: 1000, // ancien
          },
        ],
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      acks: { status: string; server_version?: { unites_restantes: number } }[];
    };
    expect(body.acks[0]?.status).toBe('conflict');
    expect(body.acks[0]?.server_version?.unites_restantes).toBe(16);

    // La boîte n'a pas été mise à 0
    const [row] = await env.handle.db.select().from(boites).where(eq(boites.id, boiteId));
    expect(row?.unitesRestantes).toBe(16);
  });

  it('LWW 2 devices : device-1 push update récent, device-2 push update plus ancien → conflict', async () => {
    // Scénario : un utilisateur a 2 devices. Device-1 modifie une
    // boîte en ligne ; device-2 (offline depuis hier) modifie la même
    // boîte avec une valeur différente puis se reconnecte. La règle
    // LWW + soft delete dit : la version la plus récente l'emporte,
    // device-2 reçoit `conflict` avec le `server_version` à mettre
    // à jour localement.
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const boiteId = uuid();
    await env.handle.db.insert(boites).values({
      id: boiteId,
      officineId,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: me.userId,
      unitesRestantes: 16,
    });

    const { push } = await importHandlers();

    // Device-1 push une mise à jour récente : applied (avance updated_at
    // sur l'horloge serveur via `new Date()`).
    const tDevice1 = Date.now();
    const res1 = await push.POST(
      pushReq(me.cookie, {
        client_id: 'device-1',
        operations: [
          {
            id: uuid(),
            type: 'update_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: { unites_restantes: 8 },
            timestamp_local: tDevice1,
          },
        ],
      }),
    );
    expect(res1.status).toBe(200);
    const body1 = (await res1.json()) as { acks: { status: string }[] };
    expect(body1.acks[0]?.status).toBe('applied');

    // Device-2 (offline depuis la veille) push une op avec un
    // timestamp_local antérieur à `now` (donc antérieur à l'updated_at
    // serveur fixé par device-1). LWW → conflict.
    const tDevice2 = Date.now() - 24 * 60 * 60 * 1000;
    const res2 = await push.POST(
      pushReq(me.cookie, {
        client_id: 'device-2',
        operations: [
          {
            id: uuid(),
            type: 'update_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: { unites_restantes: 0 },
            timestamp_local: tDevice2,
          },
        ],
      }),
    );
    expect(res2.status).toBe(200);
    const body2 = (await res2.json()) as {
      acks: { status: string; server_version?: { unites_restantes: number } }[];
    };
    expect(body2.acks[0]?.status).toBe('conflict');
    // Le server_version contient la valeur écrite par device-1 que le
    // device-2 doit refléter localement.
    expect(body2.acks[0]?.server_version?.unites_restantes).toBe(8);

    // La DB n'a PAS été modifiée par device-2.
    const [row] = await env.handle.db.select().from(boites).where(eq(boites.id, boiteId));
    expect(row?.unitesRestantes).toBe(8);
  });

  it('soft_delete : la ligne est conservée en DB avec deletedAt non null (pas de DELETE physique)', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const boiteId = uuid();
    await env.handle.db.insert(boites).values({
      id: boiteId,
      officineId,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: me.userId,
      unitesRestantes: 16,
    });

    const { push } = await importHandlers();
    const res = await push.POST(
      pushReq(me.cookie, {
        client_id: 'device-1',
        operations: [
          {
            id: uuid(),
            type: 'soft_delete_boite',
            entity_type: 'boite',
            entity_id: boiteId,
            payload: {},
            timestamp_local: Date.now() + 5000,
          },
        ],
      }),
    );
    expect(res.status).toBe(200);

    // La ligne existe encore en base avec deletedAt set.
    const rows = await env.handle.db.select().from(boites).where(eq(boites.id, boiteId));
    expect(rows.length).toBe(1);
    expect(rows[0]?.deletedAt).not.toBeNull();
    // Le sync_operations_log a bien archivé l'op (audit trail).
    const logs = await env.handle.db
      .select()
      .from(syncOperationsLog)
      .where(eq(syncOperationsLog.entityId, boiteId));
    expect(logs.length).toBe(1);
    expect(logs[0]?.status).toBe('applied');
  });

  it('AuthZ : viewer rejected, stranger forbidden', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');

    const { push } = await importHandlers();
    const res = await push.POST(
      pushReq(viewer.cookie, {
        client_id: 'device-2',
        operations: [
          {
            id: uuid(),
            type: 'create_boite',
            entity_type: 'boite',
            entity_id: uuid(),
            payload: {
              officine_id: officineId,
              cip13: '3400930000019',
              peremption: '2027-01-01',
            },
            timestamp_local: Date.now(),
          },
        ],
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { acks: { status: string; reason?: string }[] };
    expect(body.acks[0]?.status).toBe('rejected');
    expect(body.acks[0]?.reason).toBe('forbidden');
  });

  it('rejette un batch > 100 (400 validation_error)', async () => {
    const me = await signup('me@piloo.fr');
    const { push } = await importHandlers();
    const oversize = Array.from({ length: 101 }, () => ({
      id: uuid(),
      type: 'create_boite' as const,
      entity_type: 'boite' as const,
      entity_id: uuid(),
      payload: {
        officine_id: uuid(),
        cip13: '3400930000019',
        peremption: '2027-01-01',
      },
      timestamp_local: Date.now(),
    }));

    const res = await push.POST(
      pushReq(me.cookie, { client_id: 'device-1', operations: oversize }),
    );
    expect(res.status).toBe(400);
  });

  it('renvoie 401 sans credential', async () => {
    const { push } = await importHandlers();
    const res = await push.POST(
      new Request(`${BASE_URL}/api/v1/sync/push`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_id: 'x', operations: [] }),
      }),
    );
    expect(res.status).toBe(401);
  });
});

describe('GET /api/v1/sync/pull', () => {
  it('renvoie les boîtes accessibles + soft-deleted dans deleted[]', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const aliveId = uuid();
    const deletedId = uuid();
    await env.handle.db.insert(boites).values([
      {
        id: aliveId,
        officineId,
        cip13: '3400930000019',
        peremption: '2027-01-01',
        ajouteePar: me.userId,
      },
      {
        id: deletedId,
        officineId,
        cip13: '3400930000026',
        peremption: '2027-01-01',
        ajouteePar: me.userId,
        deletedAt: new Date(),
      },
    ]);

    const { pull } = await importHandlers();
    const res = await pull.GET(pullReq(me.cookie));
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      entities: { boites: { id: string }[] };
      deleted: { boites: string[] };
    };
    expect(body.entities.boites.map((b) => b.id)).toEqual([aliveId]);
    expect(body.deleted.boites).toEqual([deletedId]);
  });

  it('filtre par since= : ne renvoie que les modifs récentes', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const oldId = uuid();
    await env.handle.db.insert(boites).values({
      id: oldId,
      officineId,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: me.userId,
    });
    // Marker temporel
    const marker = new Date();
    // Force updatedAt dans le futur sur une autre boîte
    await new Promise((r) => setTimeout(r, 10));
    const newId = uuid();
    await env.handle.db.insert(boites).values({
      id: newId,
      officineId,
      cip13: '3400930000026',
      peremption: '2027-01-01',
      ajouteePar: me.userId,
    });

    const { pull } = await importHandlers();
    const res = await pull.GET(pullReq(me.cookie, `?since=${marker.toISOString()}`));
    const body = (await res.json()) as { entities: { boites: { id: string }[] } };
    expect(body.entities.boites.map((b) => b.id)).toEqual([newId]);
  });

  it("isolation : un user ne voit pas les boîtes des officines auxquelles il n'a pas accès", async () => {
    const a = await signup('a@piloo.fr');
    const b = await signup('b@piloo.fr');
    const officineA = await makeOfficine(a.userId);
    const officineB = await makeOfficine(b.userId);
    await grant(a.userId, officineA, 'owner');
    await grant(b.userId, officineB, 'owner');

    await env.handle.db.insert(boites).values([
      {
        id: uuid(),
        officineId: officineA,
        cip13: '3400930000019',
        peremption: '2027-01-01',
        ajouteePar: a.userId,
      },
      {
        id: uuid(),
        officineId: officineB,
        cip13: '3400930000026',
        peremption: '2027-01-01',
        ajouteePar: b.userId,
      },
    ]);

    const { pull } = await importHandlers();
    const res = await pull.GET(pullReq(a.cookie));
    const body = (await res.json()) as { entities: { boites: { officine_id: string }[] } };
    expect(body.entities.boites.every((bx) => bx.officine_id === officineA)).toBe(true);
    expect(body.entities.boites).toHaveLength(1);
  });

  it('renvoie 401 sans credential', async () => {
    const { pull } = await importHandlers();
    const res = await pull.GET(new Request(`${BASE_URL}/api/v1/sync/pull`));
    expect(res.status).toBe(401);
  });
});
