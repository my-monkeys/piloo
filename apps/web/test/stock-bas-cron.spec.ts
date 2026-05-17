// Tests cron stock_bas (#145).
import { alertes, boites, officines, ordonnances, partages, prescriptions } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { dailyConsumption, runStockBasCron } from '@/lib/alertes/stock-bas';

let env: TestDb;
let userOwner: string;
let userEditor: string;
let userViewer: string;
let officineId: string;
let prescriptionId: string;
let ordonnanceId: string;

const CIP = '3400930000019';

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

async function createUser(email: string): Promise<string> {
  const [row] = await env.handle.client<{ id: string }[]>`
    INSERT INTO users (id, email, name, nom, prenom, type_compte)
    VALUES (gen_random_uuid(), ${email}, ${email}, 'T', 'U', 'particulier')
    RETURNING id::text
  `;
  if (!row) throw new Error('insert user');
  return row.id;
}

interface PosologieInput {
  unitesParPrise: number;
  frequence: 'quotidien' | 'hebdomadaire' | 'a_la_demande';
  moments?: readonly ('matin' | 'midi' | 'soir' | 'coucher')[];
}

async function createPrescription(poso: PosologieInput, cip: string | null = CIP): Promise<string> {
  const [presc] = await env.handle.db
    .insert(prescriptions)
    .values({
      ordonnanceId,
      nomTexte: 'Doliprane 1000mg',
      cip13: cip,
      posologie: { unite: 'comprimé', ...poso },
    })
    .returning({ id: prescriptions.id });
  if (!presc) throw new Error('prescription');
  return presc.id;
}

async function addBoite(
  cip: string,
  unitesRestantes: number,
  statut: 'active' | 'vide' | 'perimee' = 'active',
): Promise<void> {
  await env.handle.db.insert(boites).values({
    officineId,
    cip13: cip,
    peremption: '2027-12-31',
    unitesRestantes,
    statut,
    ajouteePar: userOwner,
  });
}

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      alertes, boites, prescriptions, ordonnances,
      partages, officines, users
    RESTART IDENTITY CASCADE
  `;
  userOwner = await createUser('owner@piloo.fr');
  userEditor = await createUser('editor@piloo.fr');
  userViewer = await createUser('viewer@piloo.fr');

  const [off] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: userOwner })
    .returning({ id: officines.id });
  if (!off) throw new Error('officine');
  officineId = off.id;

  const t = new Date();
  await env.handle.db.insert(partages).values([
    { userId: userOwner, officineId, role: 'owner', invitedAt: t, acceptedAt: t },
    { userId: userEditor, officineId, role: 'editor', invitedAt: t, acceptedAt: t },
    { userId: userViewer, officineId, role: 'viewer', invitedAt: t, acceptedAt: t },
  ]);

  const [ord] = await env.handle.db
    .insert(ordonnances)
    .values({
      officineId,
      datePrescription: '2026-06-01',
      source: 'manuelle',
      saisiePar: userOwner,
    })
    .returning({ id: ordonnances.id });
  if (!ord) throw new Error('ordonnance');
  ordonnanceId = ord.id;

  // Posologie par défaut : 1 cp/jour matin+soir = 2 unités/jour.
  prescriptionId = await createPrescription({
    unitesParPrise: 1,
    frequence: 'quotidien',
    moments: ['matin', 'soir'],
  });
});

describe('dailyConsumption', () => {
  it('quotidien × moments', () => {
    expect(
      dailyConsumption({ unitesParPrise: 2, frequence: 'quotidien', moments: ['matin', 'soir'] }),
    ).toBe(4);
  });
  it('quotidien sans moments = 1 prise/jour', () => {
    expect(dailyConsumption({ unitesParPrise: 1, frequence: 'quotidien' })).toBe(1);
  });
  it('hebdomadaire divisé par 7', () => {
    expect(
      dailyConsumption({ unitesParPrise: 1, frequence: 'hebdomadaire', moments: ['matin'] }),
    ).toBeCloseTo(1 / 7);
  });
  it('a_la_demande → 0', () => {
    expect(dailyConsumption({ unitesParPrise: 1, frequence: 'a_la_demande' })).toBe(0);
  });
  it('null/objet vide → 0', () => {
    expect(dailyConsumption(null)).toBe(0);
    expect(dailyConsumption({})).toBe(0);
  });
});

describe('runStockBasCron', () => {
  it('no-op sans prescriptions ni boîtes', async () => {
    await env.handle.client`TRUNCATE prescriptions, boites RESTART IDENTITY CASCADE`;
    const result = await runStockBasCron(env.handle.db);
    expect(result).toEqual({ candidates: 0, lowStock: 0, alertsCreated: 0 });
  });

  it('skip prescription `a_la_demande`', async () => {
    await env.handle.client`TRUNCATE prescriptions RESTART IDENTITY CASCADE`;
    await createPrescription({ unitesParPrise: 1, frequence: 'a_la_demande' });
    await addBoite(CIP, 1); // 1 cp, mais à la demande → pas de signal
    const result = await runStockBasCron(env.handle.db);
    expect(result.candidates).toBe(0);
    expect(result.alertsCreated).toBe(0);
  });

  it('no alert quand stock >= 7 jours', async () => {
    // Conso = 2/jour, stock = 20 → 10 jours.
    await addBoite(CIP, 20);
    const result = await runStockBasCron(env.handle.db);
    expect(result.candidates).toBe(1);
    expect(result.lowStock).toBe(0);
    expect(result.alertsCreated).toBe(0);
  });

  it('alerte quand stock < 7 jours', async () => {
    // Conso = 2/jour, stock = 10 → 5 jours.
    await addBoite(CIP, 10);
    const result = await runStockBasCron(env.handle.db);
    expect(result.lowStock).toBe(1);
    expect(result.alertsCreated).toBe(2); // owner + editor (pas viewer)

    const rows = await env.handle.db
      .select({ userId: alertes.userId, type: alertes.type })
      .from(alertes);
    const userIds = rows.map((r) => r.userId).sort();
    expect(userIds).toEqual([userOwner, userEditor].sort());
    expect(rows.every((r) => r.type === 'stock_bas')).toBe(true);
  });

  it('idempotent : rerun ne duplique pas les alertes', async () => {
    await addBoite(CIP, 10);
    await runStockBasCron(env.handle.db);
    const rerun = await runStockBasCron(env.handle.db);
    expect(rerun.alertsCreated).toBe(0);

    const rows = await env.handle.client<{ count: string }[]>`
      SELECT COUNT(*)::text AS count FROM alertes
    `;
    expect(Number(rows[0]?.count ?? 0)).toBe(2);
  });

  it('somme le stock des boîtes actives, ignore vide/perimee et soft-deleted', async () => {
    // 2 boîtes actives (4+4 = 8 < 14 = 7 jours × 2/jour) → alerte
    await addBoite(CIP, 4);
    await addBoite(CIP, 4);
    // 1 boîte vide (ignorée — épuisée)
    await addBoite(CIP, 100, 'vide');
    // 1 boîte périmée (ignorée)
    await addBoite(CIP, 100, 'perimee');
    // 1 boîte soft-deleted (ignorée)
    await env.handle.db.insert(boites).values({
      officineId,
      cip13: CIP,
      peremption: '2027-12-31',
      unitesRestantes: 100,
      statut: 'active',
      ajouteePar: userOwner,
      deletedAt: new Date(),
    });

    const result = await runStockBasCron(env.handle.db);
    expect(result.lowStock).toBe(1);
    expect(result.alertsCreated).toBe(2);

    const [row] = await env.handle.db
      .select({ payload: alertes.payload })
      .from(alertes)
      .where(eq(alertes.userId, userOwner));
    expect(row?.payload).toMatchObject({
      prescription_id: prescriptionId,
      cip13: CIP,
      total_stock: 8,
    });
  });

  it('skip prescription sans cip13 (pas de matching possible)', async () => {
    await env.handle.client`TRUNCATE prescriptions RESTART IDENTITY CASCADE`;
    await createPrescription(
      { unitesParPrise: 1, frequence: 'quotidien', moments: ['matin'] },
      null,
    );
    await addBoite(CIP, 1);
    const result = await runStockBasCron(env.handle.db);
    expect(result.candidates).toBe(1); // candidate computed
    expect(result.lowStock).toBe(0); // pas de matching → pas d'alerte
  });

  it('skip prescription sans boîte (totalStock=0)', async () => {
    // Prescription par défaut existe, on n'ajoute pas de boîte.
    const result = await runStockBasCron(env.handle.db);
    expect(result.candidates).toBe(1);
    expect(result.lowStock).toBe(0);
  });
});
