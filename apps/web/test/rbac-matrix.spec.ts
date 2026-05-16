// Matrice RBAC complète (#137).
//
// Pour chaque (rôle × action) on documente le statut HTTP attendu. Le
// "rôle" inclut une 4ᵉ valeur `stranger` (utilisateur authentifié mais
// sans partage actif sur l'officine) — important pour vérifier qu'on
// ne fuit pas l'existence des ressources via des 403/404 incohérents.
//
// Convention :
//   - 200/204 = autorisé
//   - 403     = authentifié + partage présent mais rôle insuffisant
//   - 404     = authentifié sans partage actif (on ne révèle pas
//               l'existence de la ressource)
//
// Les cas 401 (sans credential) et les validations 400 (uuid mal
// formé, body invalide…) sont couverts par des tests dédiés ailleurs.
import { boites, officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
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

interface UserCtx {
  userId: string;
  cookie: string;
}

async function signup(email: string): Promise<UserCtx> {
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

type RoleKey = 'owner' | 'editor' | 'viewer' | 'stranger';

interface Fixture {
  owner: UserCtx;
  editor: UserCtx;
  viewer: UserCtx;
  stranger: UserCtx;
  officineId: string;
  boiteId: string;
}

async function setupFixture(): Promise<Fixture> {
  const stamp = String(Date.now());
  const owner = await signup(`owner-${stamp}@piloo.fr`);
  const editor = await signup(`editor-${stamp}@piloo.fr`);
  const viewer = await signup(`viewer-${stamp}@piloo.fr`);
  const stranger = await signup(`stranger-${stamp}@piloo.fr`);

  const [officine] = await env.handle.db
    .insert(officines)
    .values({ nom: 'Maison', type: 'perso', proprietaireUserId: owner.userId })
    .returning({ id: officines.id });
  if (!officine) throw new Error('officine insert');
  const officineId = officine.id;

  const now = new Date();
  await env.handle.db.insert(partages).values([
    { userId: owner.userId, officineId, role: 'owner', invitedAt: now, acceptedAt: now },
    { userId: editor.userId, officineId, role: 'editor', invitedAt: now, acceptedAt: now },
    { userId: viewer.userId, officineId, role: 'viewer', invitedAt: now, acceptedAt: now },
  ]);

  const [boite] = await env.handle.db
    .insert(boites)
    .values({
      officineId,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: owner.userId,
      unitesRestantes: 16,
    })
    .returning({ id: boites.id });
  if (!boite) throw new Error('boite insert');

  return { owner, editor, viewer, stranger, officineId, boiteId: boite.id };
}

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      boites, partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

function userFor(role: RoleKey, fx: Fixture): UserCtx {
  return fx[role];
}

interface Action {
  name: string;
  // 200 ou 204 selon la réussite ; nous testons en === expected ou !== expected
  expected: Record<RoleKey, number>;
  call(fx: Fixture, role: RoleKey): Promise<Response>;
}

async function itemOfficineHandler() {
  return import('@/app/api/v1/officines/[officineId]/route');
}

async function listBoitesHandler() {
  return import('@/app/api/v1/officines/[officineId]/boites/route');
}

async function itemBoiteHandler() {
  return import('@/app/api/v1/boites/[id]/route');
}

const ACTIONS: readonly Action[] = [
  {
    name: 'GET /officines/:id',
    expected: { owner: 200, editor: 200, viewer: 200, stranger: 404 },
    async call(fx, role) {
      const { GET } = await itemOfficineHandler();
      const u = userFor(role, fx);
      return GET(
        new Request(`${BASE_URL}/api/v1/officines/${fx.officineId}`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ officineId: fx.officineId }) },
      );
    },
  },
  {
    name: 'PATCH /officines/:id',
    expected: { owner: 200, editor: 200, viewer: 403, stranger: 404 },
    async call(fx, role) {
      const { PATCH } = await itemOfficineHandler();
      const u = userFor(role, fx);
      return PATCH(
        new Request(`${BASE_URL}/api/v1/officines/${fx.officineId}`, {
          method: 'PATCH',
          headers: { cookie: u.cookie, 'Content-Type': 'application/json' },
          body: JSON.stringify({ nom: 'Renommée' }),
        }),
        { params: Promise.resolve({ officineId: fx.officineId }) },
      );
    },
  },
  {
    name: 'DELETE /officines/:id',
    expected: { owner: 204, editor: 403, viewer: 403, stranger: 404 },
    async call(fx, role) {
      const { DELETE } = await itemOfficineHandler();
      const u = userFor(role, fx);
      return DELETE(
        new Request(`${BASE_URL}/api/v1/officines/${fx.officineId}`, {
          method: 'DELETE',
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ officineId: fx.officineId }) },
      );
    },
  },
  {
    name: 'GET /officines/:officineId/boites',
    expected: { owner: 200, editor: 200, viewer: 200, stranger: 404 },
    async call(fx, role) {
      const { GET } = await listBoitesHandler();
      const u = userFor(role, fx);
      return GET(
        new Request(`${BASE_URL}/api/v1/officines/${fx.officineId}/boites`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ officineId: fx.officineId }) },
      );
    },
  },
  {
    name: 'POST /officines/:officineId/boites',
    expected: { owner: 201, editor: 201, viewer: 403, stranger: 404 },
    async call(fx, role) {
      const { POST } = await listBoitesHandler();
      const u = userFor(role, fx);
      return POST(
        new Request(`${BASE_URL}/api/v1/officines/${fx.officineId}/boites`, {
          method: 'POST',
          headers: { cookie: u.cookie, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            cip13: '3400930000019',
            peremption: '2028-01-01',
            unites_initiales: 8,
          }),
        }),
        { params: Promise.resolve({ officineId: fx.officineId }) },
      );
    },
  },
  {
    name: 'GET /boites/:id',
    expected: { owner: 200, editor: 200, viewer: 200, stranger: 404 },
    async call(fx, role) {
      const { GET } = await itemBoiteHandler();
      const u = userFor(role, fx);
      return GET(
        new Request(`${BASE_URL}/api/v1/boites/${fx.boiteId}`, {
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ id: fx.boiteId }) },
      );
    },
  },
  {
    name: 'PATCH /boites/:id',
    expected: { owner: 200, editor: 200, viewer: 403, stranger: 404 },
    async call(fx, role) {
      const { PATCH } = await itemBoiteHandler();
      const u = userFor(role, fx);
      return PATCH(
        new Request(`${BASE_URL}/api/v1/boites/${fx.boiteId}`, {
          method: 'PATCH',
          headers: { cookie: u.cookie, 'Content-Type': 'application/json' },
          body: JSON.stringify({ unites_restantes: 12 }),
        }),
        { params: Promise.resolve({ id: fx.boiteId }) },
      );
    },
  },
  {
    name: 'DELETE /boites/:id',
    expected: { owner: 204, editor: 204, viewer: 403, stranger: 404 },
    async call(fx, role) {
      const { DELETE } = await itemBoiteHandler();
      const u = userFor(role, fx);
      return DELETE(
        new Request(`${BASE_URL}/api/v1/boites/${fx.boiteId}`, {
          method: 'DELETE',
          headers: { cookie: u.cookie },
        }),
        { params: Promise.resolve({ id: fx.boiteId }) },
      );
    },
  },
];

const ROLES: readonly RoleKey[] = ['owner', 'editor', 'viewer', 'stranger'];

// Génère le produit cartésien (action × role) pour `it.each`.
const CASES = ACTIONS.flatMap((action) =>
  ROLES.map((role) => ({
    label: `${action.name} as ${role} → ${String(action.expected[role])}`,
    action,
    role,
  })),
);

describe('RBAC matrice complète (#137)', () => {
  it.each(CASES)('$label', async ({ action, role }) => {
    const fx = await setupFixture();
    const res = await action.call(fx, role);
    expect(res.status).toBe(action.expected[role]);
  });
});
