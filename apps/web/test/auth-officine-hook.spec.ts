// Tests d'intégration du hook databaseHooks.user.create.after (#69) :
// le signup d'un compte `particulier` doit créer une officine `Mon
// officine` + un partage `owner` ; le signup d'un compte `pro` ne
// doit rien créer.
import { officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { createAuth, type AuthInstance } from '@/lib/auth/server';

const BASE_URL = 'http://localhost:3000';
const TEST_SECRET = 'test-secret-not-used-in-prod-1234567890abcdef';

let env: TestDb;
let auth: AuthInstance;

beforeAll(async () => {
  env = await setupTestDb();
  auth = createAuth({ db: env.handle.db, secret: TEST_SECRET, baseURL: BASE_URL });
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      partages, officines, sessions, accounts, verifications, users
    RESTART IDENTITY CASCADE
  `;
});

interface SignUpPayload {
  email: string;
  password: string;
  name: string;
  nom: string;
  prenom: string;
  typeCompte: 'particulier' | 'pro';
}

async function signup(payload: SignUpPayload): Promise<{ userId: string }> {
  const res = await auth.handler(
    new Request(`${BASE_URL}/api/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }),
  );
  if (res.status !== 200) {
    throw new Error(`signup failed: ${String(res.status)}`);
  }
  const json = (await res.json()) as { user: { id: string } };
  return { userId: json.user.id };
}

describe('databaseHooks.user.create.after — auto-officine perso', () => {
  it('compte particulier : crée une officine "Mon officine" perso + partage owner', async () => {
    const { userId } = await signup({
      email: 'alice@piloo.fr',
      password: 'pass-word-1234',
      name: 'Alice Doe',
      nom: 'Doe',
      prenom: 'Alice',
      typeCompte: 'particulier',
    });

    const ownedOfficines = await env.handle.db
      .select()
      .from(officines)
      .where(eq(officines.proprietaireUserId, userId));

    expect(ownedOfficines).toHaveLength(1);
    const officine = ownedOfficines[0];
    expect(officine?.nom).toBe('Mon officine');
    expect(officine?.type).toBe('perso');
    expect(officine?.deletedAt).toBeNull();

    const userPartages = await env.handle.db
      .select()
      .from(partages)
      .where(eq(partages.userId, userId));

    expect(userPartages).toHaveLength(1);
    const partage = userPartages[0];
    expect(partage?.officineId).toBe(officine?.id);
    expect(partage?.role).toBe('owner');
    expect(partage?.acceptedAt).not.toBeNull();
  });

  it('compte pro : aucune officine ni partage créé automatiquement', async () => {
    const { userId } = await signup({
      email: 'docteur@piloo.fr',
      password: 'pass-word-1234',
      name: 'Dr Martin',
      nom: 'Martin',
      prenom: 'Jean',
      typeCompte: 'pro',
    });

    const ownedOfficines = await env.handle.db
      .select()
      .from(officines)
      .where(eq(officines.proprietaireUserId, userId));
    expect(ownedOfficines).toHaveLength(0);

    const userPartages = await env.handle.db
      .select()
      .from(partages)
      .where(eq(partages.userId, userId));
    expect(userPartages).toHaveLength(0);
  });

  it('deux particuliers : chacun a sa propre officine isolée', async () => {
    const a = await signup({
      email: 'alice@piloo.fr',
      password: 'pass-word-1234',
      name: 'Alice Doe',
      nom: 'Doe',
      prenom: 'Alice',
      typeCompte: 'particulier',
    });
    const b = await signup({
      email: 'bob@piloo.fr',
      password: 'pass-word-1234',
      name: 'Bob Roe',
      nom: 'Roe',
      prenom: 'Bob',
      typeCompte: 'particulier',
    });

    const aliceOfficines = await env.handle.db
      .select()
      .from(officines)
      .where(eq(officines.proprietaireUserId, a.userId));
    const bobOfficines = await env.handle.db
      .select()
      .from(officines)
      .where(eq(officines.proprietaireUserId, b.userId));

    expect(aliceOfficines).toHaveLength(1);
    expect(bobOfficines).toHaveLength(1);
    expect(aliceOfficines[0]?.id).not.toBe(bobOfficines[0]?.id);
  });
});
