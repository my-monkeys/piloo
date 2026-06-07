// Tests d'intégration PATCH + DELETE /api/v1/rappels/{id}
// Vérifie que la réconciliation des prises_planifiees est bien câblée
// dans les handlers HTTP (tâches A3 + A4 du plan gestion-rappels #355).
import { prisesPlanifiees } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { and, eq, gte, isNull } from 'drizzle-orm';
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
      prises_planifiees, rappels, prescriptions, ordonnances,
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

interface SeedResult {
  officineId: string;
  rappelId: string;
  cookie: string;
}

/** Crée une officine + un rappel via les handlers réels pour que les prises soient générées. */
async function seedViaApi(cookie: string): Promise<SeedResult> {
  // Import dynamique APRÈS le doMock
  const { POST: createOfficine } = await import('@/app/api/v1/officines/route');
  const officineRes = await createOfficine(
    new Request(`${BASE_URL}/api/v1/officines`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', cookie },
      body: JSON.stringify({ nom: 'Maison', type: 'perso' }),
    }),
  );
  if (officineRes.status !== 201) {
    throw new Error(`createOfficine failed: ${String(officineRes.status)}`);
  }
  const officineBody = (await officineRes.json()) as { id: string };
  const officineId = officineBody.id;

  const { POST: createRappel } = await import('@/app/api/v1/officines/[officineId]/rappels/route');
  const todayIso = new Date().toISOString().slice(0, 10);
  const rappelRes = await createRappel(
    new Request(`${BASE_URL}/api/v1/officines/${officineId}/rappels`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', cookie },
      body: JSON.stringify({
        cip13: '3400930000019',
        nom_texte: 'Doliprane 1000mg',
        quantite_matin: 1,
        date_debut: todayIso,
      }),
    }),
    { params: Promise.resolve({ officineId }) },
  );
  if (rappelRes.status !== 201) {
    throw new Error(`createRappel failed: ${String(rappelRes.status)}`);
  }
  const rappelBody = (await rappelRes.json()) as { id: string };
  return { officineId, rappelId: rappelBody.id, cookie };
}

function ctx(id: string): { params: Promise<{ id: string }> } {
  return { params: Promise.resolve({ id }) };
}

function patchReq(id: string, body: unknown, cookie: string): Request {
  return new Request(`${BASE_URL}/api/v1/rappels/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', cookie },
    body: JSON.stringify(body),
  });
}

function deleteReq(id: string, cookie: string): Request {
  return new Request(`${BASE_URL}/api/v1/rappels/${id}`, {
    method: 'DELETE',
    headers: { cookie },
  });
}

/** Compte les prises futures non supprimées d'un rappel. */
async function countFuturePrises(rappelId: string): Promise<number> {
  const now = new Date();
  const rows = await env.handle.db
    .select({ id: prisesPlanifiees.id })
    .from(prisesPlanifiees)
    .where(
      and(
        eq(prisesPlanifiees.rappelId, rappelId),
        isNull(prisesPlanifiees.deletedAt),
        gte(prisesPlanifiees.datetimePrevue, now),
      ),
    );
  return rows.length;
}

describe('PATCH /api/v1/rappels/:id — réconciliation', () => {
  it('pause (actif: false) → 0 prises futures non-deleted', async () => {
    const owner = await signup('owner-pause@piloo.fr');
    const seed = await seedViaApi(owner.cookie);

    // Vérification préalable : des prises ont bien été générées
    const before = await countFuturePrises(seed.rappelId);
    expect(before).toBeGreaterThan(0);

    const { PATCH } = await import('@/app/api/v1/rappels/[id]/route');
    const res = await PATCH(
      patchReq(seed.rappelId, { actif: false }, owner.cookie),
      ctx(seed.rappelId),
    );
    expect(res.status).toBe(200);

    const after = await countFuturePrises(seed.rappelId);
    expect(after).toBe(0);
  });

  it('reprise (actif: true depuis paused) → prises régénérées', async () => {
    const owner = await signup('owner-resume@piloo.fr');
    const seed = await seedViaApi(owner.cookie);

    const { PATCH } = await import('@/app/api/v1/rappels/[id]/route');

    // Pause d'abord
    const pauseRes = await PATCH(
      patchReq(seed.rappelId, { actif: false }, owner.cookie),
      ctx(seed.rappelId),
    );
    expect(pauseRes.status).toBe(200);
    expect(await countFuturePrises(seed.rappelId)).toBe(0);

    // Reprise
    const resumeRes = await PATCH(
      patchReq(seed.rappelId, { actif: true }, owner.cookie),
      ctx(seed.rappelId),
    );
    expect(resumeRes.status).toBe(200);

    const after = await countFuturePrises(seed.rappelId);
    expect(after).toBeGreaterThan(0);
  });

  it('édition planning (quantite_soir: 1) → les prises futures doublent', async () => {
    const owner = await signup('owner-edit@piloo.fr');
    // Rappel matin seulement
    const seed = await seedViaApi(owner.cookie);

    const before = await countFuturePrises(seed.rappelId);
    expect(before).toBeGreaterThan(0);

    const { PATCH } = await import('@/app/api/v1/rappels/[id]/route');
    const res = await PATCH(
      patchReq(seed.rappelId, { quantite_soir: 1 }, owner.cookie),
      ctx(seed.rappelId),
    );
    expect(res.status).toBe(200);

    const after = await countFuturePrises(seed.rappelId);
    // On a maintenant matin + soir = 2x les prises
    expect(after).toBeGreaterThan(before);
  });

  it('édition non-planning (nom_texte) → prises inchangées', async () => {
    const owner = await signup('owner-noplan@piloo.fr');
    const seed = await seedViaApi(owner.cookie);

    const before = await countFuturePrises(seed.rappelId);

    const { PATCH } = await import('@/app/api/v1/rappels/[id]/route');
    const res = await PATCH(
      patchReq(seed.rappelId, { nom_texte: 'Paracétamol' }, owner.cookie),
      ctx(seed.rappelId),
    );
    expect(res.status).toBe(200);

    const after = await countFuturePrises(seed.rappelId);
    // Aucune réconciliation attendue — prises restent identiques
    expect(after).toBe(before);
  });
});

describe('DELETE /api/v1/rappels/:id — réconciliation', () => {
  it('delete → 204 et 0 prises futures non-deleted', async () => {
    const owner = await signup('owner-del@piloo.fr');
    const seed = await seedViaApi(owner.cookie);

    const before = await countFuturePrises(seed.rappelId);
    expect(before).toBeGreaterThan(0);

    const { DELETE } = await import('@/app/api/v1/rappels/[id]/route');
    const res = await DELETE(deleteReq(seed.rappelId, owner.cookie), ctx(seed.rappelId));
    expect(res.status).toBe(204);

    const after = await countFuturePrises(seed.rappelId);
    expect(after).toBe(0);
  });
});
