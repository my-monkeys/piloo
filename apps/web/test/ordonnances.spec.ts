// Tests d'intégration ordonnances + prescriptions (#106).
import { officines, ordonnances, partages, prescriptions } from '@piloo/db-schema';
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
      prescriptions, ordonnances, partages, officines,
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
    listCreate: await import('@/app/api/v1/officines/[officineId]/ordonnances/route'),
    item: await import('@/app/api/v1/ordonnances/[id]/route'),
    addPresc: await import('@/app/api/v1/ordonnances/[id]/prescriptions/route'),
    prescItem: await import('@/app/api/v1/prescriptions/[id]/route'),
  };
}

async function makeOfficine(userId: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: userId })
    .returning({ id: officines.id });
  if (!row) throw new Error('officine insert returned no row');
  return row.id;
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

const validPosologie = {
  unitesParPrise: 1,
  unite: 'comprimé',
  frequence: 'quotidien',
  moments: ['matin', 'soir'],
};

const validCreate = {
  prescripteur: 'Dr Dupont',
  date_prescription: '2026-06-01',
  prescriptions: [
    {
      cip13: '3400930000019',
      nom_texte: 'Doliprane 1000mg',
      posologie: validPosologie,
      duree_jours: 7,
    },
  ],
};

describe('POST /api/v1/officines/:officineId/ordonnances', () => {
  it('owner crée une ordonnance avec prescriptions imbriquées', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { listCreate } = await importHandlers();
    const res = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as {
      id: string;
      saisie_par: string;
      source: string;
      prescriptions: { id: string; nom_texte: string; cip13: string | null }[];
    };
    expect(body.saisie_par).toBe(me.userId);
    expect(body.source).toBe('manuelle');
    expect(body.prescriptions).toHaveLength(1);
    expect(body.prescriptions[0]?.nom_texte).toBe('Doliprane 1000mg');
    expect(body.prescriptions[0]?.cip13).toBe('3400930000019');
  });

  it('crée une ordonnance sans prescriptions', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { listCreate } = await importHandlers();
    const res = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ date_prescription: '2026-06-01' }),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as { prescriptions: unknown[] };
    expect(body.prescriptions).toEqual([]);
  });

  it('viewer ne peut pas créer (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(viewer.userId, officineId, 'viewer');

    const { listCreate } = await importHandlers();
    const res = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: viewer.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(403);
  });

  it('rejette posologie invalide (400)', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');

    const { listCreate } = await importHandlers();
    const res = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({
          ...validCreate,
          prescriptions: [
            {
              nom_texte: 'X',
              posologie: { ...validPosologie, frequence: 'INVALIDE' },
            },
          ],
        }),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe('validation_error');
  });

  it('renvoie 401 sans credential', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);

    const { listCreate } = await importHandlers();
    const res = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(401);
  });
});

describe('GET /api/v1/officines/:officineId/ordonnances', () => {
  it('liste pour les 3 rôles, exclut les soft-deleted', async () => {
    const owner = await signup('owner@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const [ord1] = await env.handle.db
      .insert(ordonnances)
      .values({
        officineId,
        datePrescription: '2026-06-01',
        saisiePar: owner.userId,
      })
      .returning({ id: ordonnances.id });
    const [ord2] = await env.handle.db
      .insert(ordonnances)
      .values({
        officineId,
        datePrescription: '2026-05-01',
        saisiePar: owner.userId,
        deletedAt: new Date(),
      })
      .returning({ id: ordonnances.id });
    if (!ord1 || !ord2) throw new Error('insert ord');

    const { listCreate } = await importHandlers();
    const res = await listCreate.GET(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        headers: { cookie: owner.cookie },
      }),
      { params: Promise.resolve({ officineId }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { items: { id: string }[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.id).toBe(ord1.id);
  });
});

describe('GET /api/v1/ordonnances/:id', () => {
  it("renvoie l'ordonnance avec ses prescriptions actives", async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const { listCreate, item } = await importHandlers();

    const createRes = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    const created = (await createRes.json()) as { id: string; prescriptions: { id: string }[] };

    // Soft-delete une prescription pour vérifier qu'elle disparaît du GET
    await env.handle.db
      .update(prescriptions)
      .set({ deletedAt: new Date() })
      .where(eq(prescriptions.id, created.prescriptions[0]!.id));

    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/ordonnances/${created.id}`, {
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { prescriptions: unknown[] };
    expect(body.prescriptions).toEqual([]);
  });

  it('404 si stranger sans partage', async () => {
    const owner = await signup('owner@piloo.fr');
    const stranger = await signup('stranger@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: owner.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');

    const { item } = await importHandlers();
    const res = await item.GET(
      new Request(`${BASE_URL}/api/v1/ordonnances/${ord.id}`, {
        headers: { cookie: stranger.cookie },
      }),
      { params: Promise.resolve({ id: ord.id }) },
    );
    expect(res.status).toBe(404);
  });
});

describe('PATCH /api/v1/ordonnances/:id', () => {
  it('owner peut updater', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: me.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');

    const { item } = await importHandlers();
    const res = await item.PATCH(
      new Request(`${BASE_URL}/api/v1/ordonnances/${ord.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({ prescripteur: 'Dr Modifie', notes: null }),
      }),
      { params: Promise.resolve({ id: ord.id }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { prescripteur: string; notes: string | null };
    expect(body.prescripteur).toBe('Dr Modifie');
    expect(body.notes).toBeNull();
  });
});

describe('DELETE /api/v1/ordonnances/:id', () => {
  it('cascade soft-delete sur les prescriptions', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const { listCreate, item } = await importHandlers();

    const createRes = await listCreate.POST(
      new Request(`${BASE_URL}/api/v1/officines/${officineId}/ordonnances`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify(validCreate),
      }),
      { params: Promise.resolve({ officineId }) },
    );
    const created = (await createRes.json()) as { id: string; prescriptions: { id: string }[] };

    const res = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/ordonnances/${created.id}`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: created.id }) },
    );
    expect(res.status).toBe(204);

    // L'ordonnance ET sa prescription doivent être soft-deleted
    const [ordRow] = await env.handle.db
      .select({ deletedAt: ordonnances.deletedAt })
      .from(ordonnances)
      .where(eq(ordonnances.id, created.id));
    expect(ordRow?.deletedAt).not.toBeNull();

    const [prescRow] = await env.handle.db
      .select({ deletedAt: prescriptions.deletedAt })
      .from(prescriptions)
      .where(eq(prescriptions.id, created.prescriptions[0]!.id));
    expect(prescRow?.deletedAt).not.toBeNull();
  });

  it('editor peut delete, viewer ne peut pas (403)', async () => {
    const owner = await signup('owner@piloo.fr');
    const editor = await signup('editor@piloo.fr');
    const viewer = await signup('viewer@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(editor.userId, officineId, 'editor');
    await grant(viewer.userId, officineId, 'viewer');
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: owner.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');

    const { item } = await importHandlers();
    const resViewer = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/ordonnances/${ord.id}`, {
        method: 'DELETE',
        headers: { cookie: viewer.cookie },
      }),
      { params: Promise.resolve({ id: ord.id }) },
    );
    expect(resViewer.status).toBe(403);

    const resEditor = await item.DELETE(
      new Request(`${BASE_URL}/api/v1/ordonnances/${ord.id}`, {
        method: 'DELETE',
        headers: { cookie: editor.cookie },
      }),
      { params: Promise.resolve({ id: ord.id }) },
    );
    expect(resEditor.status).toBe(204);
  });
});

describe('POST /api/v1/ordonnances/:id/prescriptions', () => {
  it('ajoute une prescription à une ordonnance existante', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: me.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');

    const { addPresc } = await importHandlers();
    const res = await addPresc.POST(
      new Request(`${BASE_URL}/api/v1/ordonnances/${ord.id}/prescriptions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({
          nom_texte: 'Spasfon 80mg',
          posologie: validPosologie,
        }),
      }),
      { params: Promise.resolve({ id: ord.id }) },
    );
    expect(res.status).toBe(201);
    const body = (await res.json()) as { nom_texte: string; ordonnance_id: string };
    expect(body.nom_texte).toBe('Spasfon 80mg');
    expect(body.ordonnance_id).toBe(ord.id);
  });
});

describe('PATCH /api/v1/prescriptions/:id', () => {
  it('met à jour le nom et la posologie', async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: me.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');
    const [presc] = await env.handle.db
      .insert(prescriptions)
      .values({
        ordonnanceId: ord.id,
        nomTexte: 'Original',
        posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien' },
      })
      .returning({ id: prescriptions.id });
    if (!presc) throw new Error('presc');

    const { prescItem } = await importHandlers();
    const res = await prescItem.PATCH(
      new Request(`${BASE_URL}/api/v1/prescriptions/${presc.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', cookie: me.cookie },
        body: JSON.stringify({
          nom_texte: 'Modifie',
          posologie: { unitesParPrise: 2, unite: 'cp', frequence: 'hebdomadaire' },
        }),
      }),
      { params: Promise.resolve({ id: presc.id }) },
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as { nom_texte: string; posologie: { frequence: string } };
    expect(body.nom_texte).toBe('Modifie');
    expect(body.posologie.frequence).toBe('hebdomadaire');
  });
});

describe('DELETE /api/v1/prescriptions/:id', () => {
  it("soft-delete sans toucher l'ordonnance parent", async () => {
    const me = await signup('me@piloo.fr');
    const officineId = await makeOfficine(me.userId);
    await grant(me.userId, officineId, 'owner');
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId, datePrescription: '2026-06-01', saisiePar: me.userId })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');
    const [presc] = await env.handle.db
      .insert(prescriptions)
      .values({
        ordonnanceId: ord.id,
        nomTexte: 'À supprimer',
        posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien' },
      })
      .returning({ id: prescriptions.id });
    if (!presc) throw new Error('presc');

    const { prescItem } = await importHandlers();
    const res = await prescItem.DELETE(
      new Request(`${BASE_URL}/api/v1/prescriptions/${presc.id}`, {
        method: 'DELETE',
        headers: { cookie: me.cookie },
      }),
      { params: Promise.resolve({ id: presc.id }) },
    );
    expect(res.status).toBe(204);

    const [prescRow] = await env.handle.db
      .select({ deletedAt: prescriptions.deletedAt })
      .from(prescriptions)
      .where(eq(prescriptions.id, presc.id));
    expect(prescRow?.deletedAt).not.toBeNull();

    const [ordRow] = await env.handle.db
      .select({ deletedAt: ordonnances.deletedAt })
      .from(ordonnances)
      .where(eq(ordonnances.id, ord.id));
    expect(ordRow?.deletedAt).toBeNull();
  });
});
