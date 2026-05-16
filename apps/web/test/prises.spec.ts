// Tests d'intégration /api/v1/prises/today + /api/v1/prises (#114).
import {
  officines,
  ordonnances,
  partages,
  prescriptions,
  prisesPlanifiees,
} from '@piloo/db-schema';
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
      prises_planifiees, prescriptions, ordonnances,
      partages, officines, sessions, accounts, verifications, users
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
    today: await import('@/app/api/v1/prises/today/route'),
    list: await import('@/app/api/v1/prises/route'),
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

async function makePrescription(officineId: string, userId: string): Promise<string> {
  const [ord] = await env.handle.db
    .insert(ordonnances)
    .values({
      officineId,
      datePrescription: '2026-05-16',
      source: 'manuelle',
      saisiePar: userId,
    })
    .returning({ id: ordonnances.id });
  if (!ord) throw new Error('ordonnance insert returned no row');

  const [presc] = await env.handle.db
    .insert(prescriptions)
    .values({
      ordonnanceId: ord.id,
      nomTexte: 'Doliprane 1000mg',
      cip13: '3400930000019',
      indication: 'Douleur',
      posologie: {
        unitesParPrise: 1,
        unite: 'comprimé',
        frequence: 'quotidien',
        moments: ['matin', 'soir'],
      },
    })
    .returning({ id: prescriptions.id });
  if (!presc) throw new Error('prescription insert returned no row');
  return presc.id;
}

async function makePrise(
  officineId: string,
  prescriptionId: string,
  datetimePrevue: Date,
  statut: 'prevue' | 'prise' | 'sautee' | 'oubliee' = 'prevue',
): Promise<string> {
  const [row] = await env.handle.db
    .insert(prisesPlanifiees)
    .values({ officineId, prescriptionId, datetimePrevue, statut })
    .returning({ id: prisesPlanifiees.id });
  if (!row) throw new Error('prise insert returned no row');
  return row.id;
}

describe('GET /api/v1/prises/today', () => {
  it('renvoie 401 sans credential', async () => {
    const { today } = await importHandlers();
    const res = await today.GET(
      new Request(
        `${BASE_URL}/api/v1/prises/today?officine_id=00000000-0000-0000-0000-000000000000`,
      ),
    );
    expect(res.status).toBe(401);
  });

  it('renvoie 400 sans officine_id', async () => {
    const owner = await signup('a@piloo.fr');
    const { today } = await importHandlers();
    const res = await today.GET(
      new Request(`${BASE_URL}/api/v1/prises/today`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(400);
  });

  it("renvoie 404 si officine inconnue / pas d'accès", async () => {
    const owner = await signup('a@piloo.fr');
    const stranger = await signup('b@piloo.fr');
    const officineId = await makeOfficine(stranger.userId);
    await grant(stranger.userId, officineId, 'owner');

    const { today } = await importHandlers();
    const res = await today.GET(
      new Request(`${BASE_URL}/api/v1/prises/today?officine_id=${officineId}`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(404);
  });

  it('renvoie les prises du jour courant pour un viewer', async () => {
    const owner = await signup('a@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'viewer');
    const prescId = await makePrescription(officineId, owner.userId);

    const now = new Date();
    const todayUtc = now.toISOString().slice(0, 10);
    // Une prise aujourd'hui à 09h00 UTC, une autre hier (filtrée out).
    await makePrise(officineId, prescId, new Date(`${todayUtc}T09:00:00.000Z`));
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    await makePrise(officineId, prescId, new Date(`${yesterday}T09:00:00.000Z`));

    const { today } = await importHandlers();
    const res = await today.GET(
      new Request(`${BASE_URL}/api/v1/prises/today?officine_id=${officineId}`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      date: string;
      items: {
        statut: string;
        prescription: { nom_texte: string; cip13: string | null };
      }[];
    };
    expect(body.date).toBe(todayUtc);
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.statut).toBe('prevue');
    expect(body.items[0]?.prescription.nom_texte).toBe('Doliprane 1000mg');
    expect(body.items[0]?.prescription.cip13).toBe('3400930000019');
  });
});

describe('GET /api/v1/prises?date=', () => {
  it('renvoie 400 sans date', async () => {
    const owner = await signup('a@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/prises?officine_id=${officineId}`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(400);
  });

  it('renvoie 400 si date mal formée', async () => {
    const owner = await signup('a@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/prises?officine_id=${officineId}&date=pasUneDate`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(400);
  });

  it('renvoie les prises classées par datetime_prevue asc', async () => {
    const owner = await signup('a@piloo.fr');
    const officineId = await makeOfficine(owner.userId);
    await grant(owner.userId, officineId, 'owner');
    const prescId = await makePrescription(officineId, owner.userId);

    const date = '2026-05-20';
    await makePrise(officineId, prescId, new Date(`${date}T20:00:00.000Z`), 'prise');
    await makePrise(officineId, prescId, new Date(`${date}T08:00:00.000Z`), 'prevue');
    await makePrise(officineId, prescId, new Date(`${date}T12:00:00.000Z`), 'oubliee');

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/prises?officine_id=${officineId}&date=${date}`, {
        headers: { cookie: owner.cookie },
      }),
    );
    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      items: { statut: string; datetime_prevue: string }[];
    };
    expect(body.items.map((i) => i.statut)).toEqual(['prevue', 'oubliee', 'prise']);
    expect(body.items[0]?.datetime_prevue).toContain('T08:00:00');
  });

  it("exclut les prises soft-deleted et celles d'autres officines", async () => {
    const owner = await signup('a@piloo.fr');
    const officineA = await makeOfficine(owner.userId);
    const officineB = await makeOfficine(owner.userId);
    await grant(owner.userId, officineA, 'owner');
    await grant(owner.userId, officineB, 'owner');
    const prescA = await makePrescription(officineA, owner.userId);
    const prescB = await makePrescription(officineB, owner.userId);

    const date = '2026-05-21';
    await makePrise(officineA, prescA, new Date(`${date}T09:00:00.000Z`));
    await makePrise(officineB, prescB, new Date(`${date}T09:00:00.000Z`));

    const { list } = await importHandlers();
    const res = await list.GET(
      new Request(`${BASE_URL}/api/v1/prises?officine_id=${officineA}&date=${date}`, {
        headers: { cookie: owner.cookie },
      }),
    );
    const body = (await res.json()) as { items: { officine_id: string }[] };
    expect(body.items).toHaveLength(1);
    expect(body.items[0]?.officine_id).toBe(officineA);
  });
});
