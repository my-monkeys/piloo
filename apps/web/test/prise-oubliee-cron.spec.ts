// Tests cron prise oubliée (#118).
//
// On invoque `runPriseOublieeCron(db, now)` avec une horloge contrôlée
// pour stabiliser les bornes "+1h" sans dépendre de l'horloge réelle.
import {
  alertes,
  officines,
  ordonnances,
  partages,
  prescriptions,
  prisesPlanifiees,
} from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runPriseOublieeCron } from '@/lib/alertes/prise-oubliee';

let env: TestDb;
let userOwner: string;
let userEditor: string;
let userViewer: string;
let userStranger: string;
let officineId: string;
let prescriptionId: string;

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
      alertes, prises_planifiees, prescriptions, ordonnances,
      partages, officines, users
    RESTART IDENTITY CASCADE
  `;
  userOwner = await createUser('owner@piloo.fr');
  userEditor = await createUser('editor@piloo.fr');
  userViewer = await createUser('viewer@piloo.fr');
  userStranger = await createUser('stranger@piloo.fr');

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
  const [presc] = await env.handle.db
    .insert(prescriptions)
    .values({
      ordonnanceId: ord.id,
      nomTexte: 'Doliprane 1000mg',
      cip13: '3400930000019',
      posologie: { unitesParPrise: 1, unite: 'comprimé', frequence: 'quotidien' },
    })
    .returning({ id: prescriptions.id });
  if (!presc) throw new Error('prescription');
  prescriptionId = presc.id;
});

const NOW = new Date('2026-06-15T12:00:00Z');
const HOUR = 60 * 60 * 1000;

async function insertPrise(
  datetimePrevue: Date,
  statut: 'prevue' | 'prise' | 'sautee' | 'oubliee' = 'prevue',
): Promise<string> {
  const [row] = await env.handle.db
    .insert(prisesPlanifiees)
    .values({ officineId, prescriptionId, datetimePrevue, statut })
    .returning({ id: prisesPlanifiees.id });
  if (!row) throw new Error('prise');
  return row.id;
}

describe('runPriseOublieeCron', () => {
  it('no-op quand pas de candidates', async () => {
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result).toEqual({ candidates: 0, transitioned: 0, alertsCreated: 0 });
  });

  it('ignore les prises dans la grace period (< 1h)', async () => {
    // Prévue il y a 30min — toujours dans la grace.
    await insertPrise(new Date(NOW.getTime() - 30 * 60 * 1000));
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
  });

  it('flip prevue → oubliee au-delà de la grace', async () => {
    const priseId = await insertPrise(new Date(NOW.getTime() - 2 * HOUR));
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result.transitioned).toBe(1);

    const [row] = await env.handle.db
      .select({ statut: prisesPlanifiees.statut })
      .from(prisesPlanifiees)
      .where(eq(prisesPlanifiees.id, priseId));
    expect(row?.statut).toBe('oubliee');
  });

  it('crée une alerte par destinataire (owner + editor, pas viewer)', async () => {
    await insertPrise(new Date(NOW.getTime() - 2 * HOUR));
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result.alertsCreated).toBe(2);

    const rows = await env.handle.db
      .select({ userId: alertes.userId, type: alertes.type })
      .from(alertes);
    const userIds = rows.map((r) => r.userId).sort();
    expect(userIds).toEqual([userOwner, userEditor].sort());
    expect(rows.every((r) => r.type === 'prise_oubliee')).toBe(true);
  });

  it('idempotent : un rerun ne crée pas de doublon', async () => {
    await insertPrise(new Date(NOW.getTime() - 2 * HOUR));
    await runPriseOublieeCron(env.handle.db, NOW);
    const rerun = await runPriseOublieeCron(env.handle.db, NOW);
    expect(rerun.alertsCreated).toBe(0);
    expect(rerun.transitioned).toBe(0);

    const rows = await env.handle.client<{ count: string }[]>`
      SELECT COUNT(*)::text AS count FROM alertes
    `;
    expect(Number(rows[0]?.count ?? 0)).toBe(2); // owner + editor, pas de doublon
  });

  it('ne flip pas une prise marquée `prise` entre-temps (race)', async () => {
    await insertPrise(new Date(NOW.getTime() - 2 * HOUR), 'prise');
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
    expect(result.transitioned).toBe(0);
  });

  it('ignore les prises soft-deleted', async () => {
    await env.handle.db.insert(prisesPlanifiees).values({
      officineId,
      prescriptionId,
      datetimePrevue: new Date(NOW.getTime() - 2 * HOUR),
      statut: 'prevue',
      deletedAt: new Date(),
    });
    const result = await runPriseOublieeCron(env.handle.db, NOW);
    expect(result.candidates).toBe(0);
  });

  it('payload contient prise_id + prescription_id + nom + datetime_prevue', async () => {
    const due = new Date(NOW.getTime() - 2 * HOUR);
    const priseId = await insertPrise(due);
    await runPriseOublieeCron(env.handle.db, NOW);

    const [row] = await env.handle.db
      .select({ payload: alertes.payload })
      .from(alertes)
      .where(eq(alertes.userId, userOwner));
    expect(row?.payload).toMatchObject({
      prise_id: priseId,
      prescription_id: prescriptionId,
      nom_texte: 'Doliprane 1000mg',
      datetime_prevue: due.toISOString(),
    });
  });

  it("n'alerte personne pour une officine d'un autre user", async () => {
    // Officine du stranger — l'owner ne doit pas recevoir d'alerte.
    const [otherOff] = await env.handle.db
      .insert(officines)
      .values({ nom: 'X', type: 'perso', proprietaireUserId: userStranger })
      .returning({ id: officines.id });
    if (!otherOff) throw new Error('other officine');
    const t = new Date();
    await env.handle.db.insert(partages).values({
      userId: userStranger,
      officineId: otherOff.id,
      role: 'owner',
      invitedAt: t,
      acceptedAt: t,
    });
    const [ord] = await env.handle.db
      .insert(ordonnances)
      .values({
        officineId: otherOff.id,
        datePrescription: '2026-06-01',
        source: 'manuelle',
        saisiePar: userStranger,
      })
      .returning({ id: ordonnances.id });
    if (!ord) throw new Error('ord');
    const [otherPresc] = await env.handle.db
      .insert(prescriptions)
      .values({
        ordonnanceId: ord.id,
        nomTexte: 'Autre',
        posologie: { unitesParPrise: 1, unite: 'cp', frequence: 'quotidien' },
      })
      .returning({ id: prescriptions.id });
    if (!otherPresc) throw new Error('presc');
    await env.handle.db.insert(prisesPlanifiees).values({
      officineId: otherOff.id,
      prescriptionId: otherPresc.id,
      datetimePrevue: new Date(NOW.getTime() - 2 * HOUR),
      statut: 'prevue',
    });

    await runPriseOublieeCron(env.handle.db, NOW);

    // Seul stranger doit avoir une alerte. Owner/editor/viewer de
    // l'officine de owner ne doivent rien recevoir car la prise est sur
    // l'officine de stranger.
    const ownerAlerts = await env.handle.db
      .select()
      .from(alertes)
      .where(eq(alertes.userId, userOwner));
    expect(ownerAlerts).toHaveLength(0);

    const strangerAlerts = await env.handle.db
      .select()
      .from(alertes)
      .where(eq(alertes.userId, userStranger));
    expect(strangerAlerts).toHaveLength(1);
  });
});
