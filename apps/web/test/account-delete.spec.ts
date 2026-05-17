// Tests suppression compte avec délai 7 jours (#159).
import { officines, users } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import {
  anonymizeExpiredAccounts,
  DELETION_GRACE_DAYS,
  requestAccountDeletion,
  restoreAccount,
} from '@/lib/me/delete';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

async function createUser(email: string): Promise<string> {
  const [row] = await env.handle.db
    .insert(users)
    .values({
      email,
      name: email,
      nom: 'Doe',
      prenom: 'Jane',
      typeCompte: 'particulier',
    })
    .returning({ id: users.id });
  if (!row) throw new Error('user');
  return row.id;
}

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      sessions, accounts, officines, users
    RESTART IDENTITY CASCADE
  `;
});

const NOW = new Date('2026-06-15T10:00:00.000Z');
const MS_PER_DAY = 24 * 60 * 60 * 1000;

describe('requestAccountDeletion', () => {
  it("marque deleted_at et calcule la date d'anonymisation à +7j", async () => {
    const userId = await createUser('alice@piloo.fr');
    const result = await requestAccountDeletion(env.handle.db, userId, NOW);
    expect(result.deletedAt.toISOString()).toBe(NOW.toISOString());
    expect(result.scheduledAnonymizationAt.toISOString()).toBe(
      new Date(NOW.getTime() + 7 * MS_PER_DAY).toISOString(),
    );

    const [row] = await env.handle.db
      .select({ deletedAt: users.deletedAt })
      .from(users)
      .where(eq(users.id, userId));
    expect(row?.deletedAt?.toISOString()).toBe(NOW.toISOString());
  });

  it('rejette si user inconnu', async () => {
    await expect(
      requestAccountDeletion(env.handle.db, '00000000-0000-0000-0000-000000000000', NOW),
    ).rejects.toThrow();
  });
});

describe('restoreAccount', () => {
  it('clear deleted_at pour un user en grace', async () => {
    const userId = await createUser('a@piloo.fr');
    await requestAccountDeletion(env.handle.db, userId, NOW);
    const ok = await restoreAccount(env.handle.db, userId);
    expect(ok).toBe(true);

    const [row] = await env.handle.db
      .select({ deletedAt: users.deletedAt })
      .from(users)
      .where(eq(users.id, userId));
    expect(row?.deletedAt).toBeNull();
  });

  it('renvoie false si aucune suppression en cours', async () => {
    const userId = await createUser('a@piloo.fr');
    const ok = await restoreAccount(env.handle.db, userId);
    expect(ok).toBe(false);
  });
});

describe('anonymizeExpiredAccounts', () => {
  it("n'anonymise rien dans la fenêtre de 7 jours", async () => {
    const userId = await createUser('alice@piloo.fr');
    // Suppression demandée il y a 3 jours
    const requested = new Date(NOW.getTime() - 3 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, userId, requested);

    const result = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(result.anonymized).toBe(0);

    const [row] = await env.handle.db
      .select({ email: users.email })
      .from(users)
      .where(eq(users.id, userId));
    expect(row?.email).toBe('alice@piloo.fr');
  });

  it('anonymise un compte au-delà des 7 jours', async () => {
    const userId = await createUser('alice@piloo.fr');
    // Suppression demandée il y a 8 jours
    const requested = new Date(NOW.getTime() - 8 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, userId, requested);

    const result = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(result.anonymized).toBe(1);

    const [row] = await env.handle.db
      .select({
        email: users.email,
        name: users.name,
        nom: users.nom,
        prenom: users.prenom,
      })
      .from(users)
      .where(eq(users.id, userId));
    expect(row?.email).toMatch(/^deleted-.+@piloo\.local$/);
    expect(row?.name).toBe('Compte supprimé');
    expect(row?.nom).toBe('');
    expect(row?.prenom).toBe('');
  });

  it("soft-delete les officines en propre lors de l'anonymisation", async () => {
    const userId = await createUser('alice@piloo.fr');
    const [off] = await env.handle.db
      .insert(officines)
      .values({ nom: 'Maison', type: 'perso', proprietaireUserId: userId })
      .returning({ id: officines.id });
    if (!off) throw new Error('off');

    const requested = new Date(NOW.getTime() - 8 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, userId, requested);
    await anonymizeExpiredAccounts(env.handle.db, NOW);

    const [offRow] = await env.handle.db
      .select({ deletedAt: officines.deletedAt })
      .from(officines)
      .where(eq(officines.id, off.id));
    expect(offRow?.deletedAt).not.toBeNull();
  });

  it('idempotent : ne re-anonymise pas un compte déjà anonymisé', async () => {
    const userId = await createUser('alice@piloo.fr');
    const requested = new Date(NOW.getTime() - 8 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, userId, requested);
    await anonymizeExpiredAccounts(env.handle.db, NOW);

    const rerun = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(rerun.anonymized).toBe(0);
  });

  it('plusieurs comptes traités en un passage', async () => {
    const u1 = await createUser('a@piloo.fr');
    const u2 = await createUser('b@piloo.fr');
    const requested = new Date(NOW.getTime() - 9 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, u1, requested);
    await requestAccountDeletion(env.handle.db, u2, requested);

    const result = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(result.anonymized).toBe(2);
  });

  it('ignore les comptes actifs (deleted_at = null)', async () => {
    await createUser('active@piloo.fr');
    const result = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(result.anonymized).toBe(0);
  });
});

describe('intégration cycle complet', () => {
  it("demande → restore → pas d'anonymisation", async () => {
    const userId = await createUser('alice@piloo.fr');
    const requested = new Date(NOW.getTime() - 8 * MS_PER_DAY);
    await requestAccountDeletion(env.handle.db, userId, requested);
    await restoreAccount(env.handle.db, userId);

    const result = await anonymizeExpiredAccounts(env.handle.db, NOW);
    expect(result.anonymized).toBe(0);
    const [row] = await env.handle.db
      .select({ email: users.email })
      .from(users)
      .where(eq(users.id, userId));
    expect(row?.email).toBe('alice@piloo.fr');
  });

  it('valide DELETION_GRACE_DAYS = 7', () => {
    expect(DELETION_GRACE_DAYS).toBe(7);
  });
});
