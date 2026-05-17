// Tests export RGPD article 20 (#158).
import {
  alertes,
  boites,
  devices,
  officines,
  ordonnances,
  partages,
  prescriptions,
  prisesPlanifiees,
  users,
} from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { EXPORT_FORMAT_VERSION, exportUserData } from '@/lib/me/export';

let env: TestDb;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

async function createUser(email: string, prefs: Record<string, unknown> = {}): Promise<string> {
  const [row] = await env.handle.db
    .insert(users)
    .values({
      email,
      name: email,
      nom: 'Doe',
      prenom: 'Jane',
      typeCompte: 'particulier',
      preferences: prefs,
    })
    .returning({ id: users.id });
  if (!row) throw new Error('user');
  return row.id;
}

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      alertes, prises_planifiees, prescriptions, ordonnances, boites,
      devices, partages, officines, users
    RESTART IDENTITY CASCADE
  `;
});

describe('exportUserData', () => {
  it('exporte un user minimal sans officine', async () => {
    const userId = await createUser('jane@piloo.fr', { theme: 'dark' });

    const data = await exportUserData(env.handle.db, userId);

    expect(data.format_version).toBe(EXPORT_FORMAT_VERSION);
    expect(data.user_id).toBe(userId);
    expect(data.account).toMatchObject({ email: 'jane@piloo.fr', nom: 'Doe', prenom: 'Jane' });
    expect(data.preferences).toEqual({ theme: 'dark' });
    expect(data.owned_officines).toEqual([]);
    expect(data.shared_officines).toEqual([]);
    expect(data.alertes).toEqual([]);
    expect(data.devices).toEqual([]);
  });

  it('inclut officines en propre avec boîtes, ordonnances, prescriptions, prises', async () => {
    const userId = await createUser('owner@piloo.fr');
    const [off] = await env.handle.db
      .insert(officines)
      .values({ nom: 'Maison', type: 'perso', proprietaireUserId: userId })
      .returning();
    if (!off) throw new Error('off');

    await env.handle.db.insert(boites).values({
      officineId: off.id,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: userId,
    });

    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({ officineId: off.id, datePrescription: '2026-06-01', saisiePar: userId })
      .returning();
    if (!ord) throw new Error('ord');
    const [presc] = await env.handle.db
      .insert(prescriptions)
      .values({
        ordonnanceId: ord.id,
        nomTexte: 'Doliprane',
        posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien' },
      })
      .returning();
    if (!presc) throw new Error('presc');
    await env.handle.db.insert(prisesPlanifiees).values({
      prescriptionId: presc.id,
      officineId: off.id,
      datetimePrevue: new Date('2026-06-01T08:00:00Z'),
    });

    const data = await exportUserData(env.handle.db, userId);
    expect(data.owned_officines).toHaveLength(1);
    const owned = data.owned_officines[0]!;
    expect(owned.officine).toMatchObject({ nom: 'Maison' });
    expect(owned.boites).toHaveLength(1);
    expect(owned.ordonnances).toHaveLength(1);
    expect(owned.ordonnances[0]!.prescriptions).toHaveLength(1);
    expect(owned.ordonnances[0]!.prises_planifiees).toHaveLength(1);
  });

  it("n'inclut PAS le contenu des officines partagées (seulement la relation)", async () => {
    const owner = await createUser('owner@piloo.fr');
    const guest = await createUser('guest@piloo.fr');

    const [off] = await env.handle.db
      .insert(officines)
      .values({ nom: 'Famille', type: 'perso', proprietaireUserId: owner })
      .returning();
    if (!off) throw new Error('off');

    await env.handle.db.insert(boites).values({
      officineId: off.id,
      cip13: '3400930000019',
      peremption: '2027-01-01',
      ajouteePar: owner,
    });
    await env.handle.db.insert(partages).values({
      userId: guest,
      officineId: off.id,
      role: 'viewer',
      invitedAt: new Date(),
      acceptedAt: new Date(),
    });

    const data = await exportUserData(env.handle.db, guest);
    expect(data.owned_officines).toEqual([]);
    expect(data.shared_officines).toHaveLength(1);
    expect(data.shared_officines[0]).toMatchObject({
      officine_id: off.id,
      officine_nom: 'Famille',
      role: 'viewer',
    });
    // Sécurité critique : aucune donnée des boîtes du owner ne fuit
    expect(JSON.stringify(data)).not.toContain('3400930000019');
  });

  it("inclut les alertes adressées à l'user", async () => {
    const userId = await createUser('alice@piloo.fr');
    const [off] = await env.handle.db
      .insert(officines)
      .values({ nom: 'M', type: 'perso', proprietaireUserId: userId })
      .returning();
    if (!off) throw new Error('off');
    await env.handle.db.insert(alertes).values({
      officineId: off.id,
      userId,
      type: 'peremption_7j',
      payload: { boite_id: 'fake' },
    });

    const data = await exportUserData(env.handle.db, userId);
    expect(data.alertes).toHaveLength(1);
    expect(data.alertes[0]).toMatchObject({ type: 'peremption_7j' });
  });

  it("inclut les devices push de l'user", async () => {
    const userId = await createUser('a@piloo.fr');
    await env.handle.db.insert(devices).values({
      userId,
      token: 'fcm-fake-token-1',
      platform: 'ios',
    });

    const data = await exportUserData(env.handle.db, userId);
    expect(data.devices).toHaveLength(1);
    expect(data.devices[0]).toMatchObject({
      token: 'fcm-fake-token-1',
      platform: 'ios',
    });
  });

  it('inclut les officines soft-deleted dans `shared` si pertinent ? non — owned seulement non-deletées', async () => {
    const userId = await createUser('a@piloo.fr');
    await env.handle.db.insert(officines).values({
      nom: 'Supprimée',
      type: 'perso',
      proprietaireUserId: userId,
      deletedAt: new Date(),
    });
    const data = await exportUserData(env.handle.db, userId);
    expect(data.owned_officines).toEqual([]);
  });

  it('user inconnu → throw', async () => {
    await expect(
      exportUserData(env.handle.db, '00000000-0000-0000-0000-000000000000'),
    ).rejects.toThrow(/user not found/);
  });

  it('produit un JSON sérialisable', async () => {
    const userId = await createUser('a@piloo.fr');
    const data = await exportUserData(env.handle.db, userId);
    expect(() => JSON.stringify(data)).not.toThrow();
    const round = JSON.parse(JSON.stringify(data)) as { user_id: string };
    expect(round.user_id).toBe(userId);
  });
});
