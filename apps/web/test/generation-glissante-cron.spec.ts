// Tests cron génération glissante (#108).
import {
  officines,
  ordonnances,
  prescriptions,
  prisesPlanifiees,
  type Posologie,
} from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runGenerationGlissanteCron, WINDOW_DAYS } from '@/lib/prises/cron-glissant';

let env: TestDb;
let userOwner: string;
let officineId: string;
let ordonnanceId: string;

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

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE
      prises_planifiees, prescriptions, ordonnances, officines, users
    RESTART IDENTITY CASCADE
  `;
  userOwner = await createUser('owner@piloo.fr');
  // Fuseau UTC explicite (#372) : depuis le support fuseau par officine
  // (#363), « matin » = 08:00 HEURE DE L'OFFICINE. En UTC, cela reste
  // 08:00 UTC — ce qui garde les fixtures ci-dessous (heures en dur en
  // UTC) alignées sur les créneaux générés, indépendamment du DST.
  const [off] = await env.handle.db
    .insert(officines)
    .values({ nom: 'M', type: 'perso', proprietaireUserId: userOwner, timezone: 'UTC' })
    .returning({ id: officines.id });
  if (!off) throw new Error('officine');
  officineId = off.id;

  const [ord] = await env.handle.db
    .insert(ordonnances)
    .values({
      officineId,
      datePrescription: '2026-05-01',
      saisiePar: userOwner,
    })
    .returning({ id: ordonnances.id });
  if (!ord) throw new Error('ordonnance');
  ordonnanceId = ord.id;
});

async function createPrescAVie(posologie: Posologie): Promise<string> {
  const [row] = await env.handle.db
    .insert(prescriptions)
    .values({
      ordonnanceId,
      nomTexte: 'Traitement de fond',
      posologie,
      dureeJours: null, // à vie
    })
    .returning({ id: prescriptions.id });
  if (!row) throw new Error('presc');
  return row.id;
}

const NOW = new Date('2026-06-01T03:00:00.000Z'); // cron tourne à 02:00 UTC

describe('runGenerationGlissanteCron', () => {
  it('génère 30 prises (quotidien × matin) pour 1 prescription à vie', async () => {
    const prescId = await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });

    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(1);
    expect(result.prisesCreated).toBe(WINDOW_DAYS);

    const rows = await env.handle.db
      .select({ id: prisesPlanifiees.id })
      .from(prisesPlanifiees)
      .where(eq(prisesPlanifiees.prescriptionId, prescId));
    expect(rows).toHaveLength(WINDOW_DAYS);
  });

  it('ignore les prescriptions avec dureeJours (pas à vie)', async () => {
    await env.handle.db.insert(prescriptions).values({
      ordonnanceId,
      nomTexte: 'Cure courte',
      posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      dureeJours: 7,
    });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
    expect(result.prisesCreated).toBe(0);
  });

  it('ignore les prescriptions soft-deleted', async () => {
    await env.handle.db.insert(prescriptions).values({
      ordonnanceId,
      nomTexte: 'Supprimée',
      posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien', moments: ['matin'] },
      dureeJours: null,
      deletedAt: new Date(),
    });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
  });

  it("ignore les prescriptions dont l'ordonnance est soft-deleted", async () => {
    await env.handle.db.update(ordonnances).set({ deletedAt: new Date() });
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
  });

  it('a_la_demande → aucune prise', async () => {
    await createPrescAVie({ unitesParPrise: 1, unite: 'cp', frequence: 'a_la_demande' });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(1);
    expect(result.prisesCreated).toBe(0);
  });

  it('idempotent : un rerun le même jour ne crée rien', async () => {
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });
    const first = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(first.prisesCreated).toBe(WINDOW_DAYS);

    const rerun = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(rerun.prisesCreated).toBe(0);

    const [count] = await env.handle.client<{ count: string }[]>`
      SELECT COUNT(*)::text AS count FROM prises_planifiees
    `;
    expect(Number(count?.count ?? 0)).toBe(WINDOW_DAYS);
  });

  it('étend la fenêtre de 1 jour quand le cron tourne à J+1', async () => {
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });
    await runGenerationGlissanteCron(env.handle.db, NOW);

    const nextDay = new Date(NOW);
    nextDay.setUTCDate(nextDay.getUTCDate() + 1);
    const result = await runGenerationGlissanteCron(env.handle.db, nextDay);
    // Une seule nouvelle prise : le 31ème jour à partir du nouveau "today".
    expect(result.prisesCreated).toBe(1);
  });

  it('hebdomadaire à vie → ~4-5 prises sur 30j', async () => {
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'hebdomadaire',
      moments: ['matin'],
    });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    // jours [0, 7, 14, 21, 28] dans [0, 30) = 5 prises.
    expect(result.prisesCreated).toBe(5);
  });

  it('multi-moments × multi-prescriptions accumulés correctement', async () => {
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin', 'soir'],
    });
    await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['midi'],
    });
    const result = await runGenerationGlissanteCron(env.handle.db, NOW);
    expect(result.candidates).toBe(2);
    expect(result.prisesCreated).toBe(WINDOW_DAYS * 2 + WINDOW_DAYS);
  });

  it("ne recrée pas une prise soft-deletée par l'utilisateur", async () => {
    const prescId = await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });
    const target = new Date(NOW);
    target.setUTCHours(0, 0, 0, 0);
    target.setUTCDate(target.getUTCDate() + 3);
    target.setUTCHours(8, 0, 0, 0);
    await env.handle.db.insert(prisesPlanifiees).values({
      prescriptionId: prescId,
      officineId,
      datetimePrevue: target,
      statut: 'prevue',
      deletedAt: new Date(),
    });

    await runGenerationGlissanteCron(env.handle.db, NOW);

    // 30 prises générées MOINS celle déjà soft-deletée = 29 actives.
    const [active] = await env.handle.client<{ count: string }[]>`
      SELECT COUNT(*)::text AS count FROM prises_planifiees WHERE deleted_at IS NULL
    `;
    expect(Number(active?.count ?? 0)).toBe(WINDOW_DAYS - 1);
  });

  it("respecte une prise déjà marquée `prise` (n'écrase pas le statut)", async () => {
    const prescId = await createPrescAVie({
      unitesParPrise: 1,
      unite: 'cp',
      frequence: 'quotidien',
      moments: ['matin'],
    });
    // Pré-insère une prise à NOW + 5j à 08:00 UTC avec statut "prise"
    const target = new Date(NOW);
    target.setUTCHours(0, 0, 0, 0);
    target.setUTCDate(target.getUTCDate() + 5);
    target.setUTCHours(8, 0, 0, 0);
    await env.handle.db.insert(prisesPlanifiees).values({
      prescriptionId: prescId,
      officineId,
      datetimePrevue: target,
      statut: 'prise',
      datetimeValidation: new Date(),
    });

    await runGenerationGlissanteCron(env.handle.db, NOW);

    const [row] = await env.handle.db
      .select({ statut: prisesPlanifiees.statut })
      .from(prisesPlanifiees)
      .where(
        and(
          eq(prisesPlanifiees.prescriptionId, prescId),
          eq(prisesPlanifiees.datetimePrevue, target),
        ),
      );
    expect(row?.statut).toBe('prise');
  });
});
