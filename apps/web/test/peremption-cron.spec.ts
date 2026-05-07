// Tests cron péremption (#143).
//
// On invoque `runPeremptionCron(db, today)` avec une date contrôlée
// pour stabiliser les fenêtres 30j/7j sans dépendre de l'horloge réelle.
import { alertes, boites, officines, partages } from '@piloo/db-schema';
import { setupTestDb, type TestDb } from '@piloo/db-schema/testing';
import { and, eq } from 'drizzle-orm';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { runPeremptionCron } from '@/lib/alertes/peremption';

let env: TestDb;
let userOwner: string;
let userEditor: string;
let userViewer: string;
let officineId: string;

beforeAll(async () => {
  env = await setupTestDb();
}, 90_000);

afterAll(async () => {
  await env.teardown();
});

async function createUser(email: string): Promise<string> {
  const [row] = await env.handle.client<{ id: string }[]>`
    INSERT INTO users (id, email, name, nom, prenom, type_compte)
    VALUES (gen_random_uuid(), ${email}, ${email}, 'T', 'U', 'pro')
    RETURNING id::text
  `;
  if (!row) throw new Error('insert user');
  return row.id;
}

beforeEach(async () => {
  await env.handle.client`
    TRUNCATE TABLE alertes, boites, partages, officines, users
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

  const now = new Date();
  await env.handle.db.insert(partages).values([
    {
      userId: userOwner,
      officineId,
      role: 'owner',
      invitedAt: now,
      acceptedAt: now,
    },
    {
      userId: userEditor,
      officineId,
      role: 'editor',
      invitedAt: now,
      acceptedAt: now,
    },
    {
      userId: userViewer,
      officineId,
      role: 'viewer',
      invitedAt: now,
      acceptedAt: now,
    },
  ]);
});

const TODAY = new Date('2026-06-01T00:00:00Z');
const isoOffset = (days: number): string => {
  const d = new Date(TODAY);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
};

async function makeBoite(peremption: string): Promise<string> {
  const [b] = await env.handle.db
    .insert(boites)
    .values({
      officineId,
      cip13: '3400930000019',
      peremption,
      ajouteePar: userOwner,
      unitesRestantes: 16,
    })
    .returning({ id: boites.id });
  if (!b) throw new Error('boite');
  return b.id;
}

describe('runPeremptionCron', () => {
  it('crée une alerte peremption_30j pour owner + editor (pas viewer)', async () => {
    await makeBoite(isoOffset(20)); // dans 20j → ≤30j

    const result = await runPeremptionCron(env.handle.db, TODAY);
    expect(result.alertsCreated).toBe(2);

    const rows = await env.handle.db
      .select()
      .from(alertes)
      .where(eq(alertes.type, 'peremption_30j'));
    const userIds = rows.map((r) => r.userId).sort();
    expect(userIds).toEqual([userOwner, userEditor].sort());
    expect(rows.find((x) => x.userId === userViewer)).toBeUndefined();
  });

  it('crée une alerte peremption_7j (et aussi 30j) si la boîte est à J-5', async () => {
    await makeBoite(isoOffset(5));

    await runPeremptionCron(env.handle.db, TODAY);
    const types = (await env.handle.db.select().from(alertes)).map((r) => r.type);
    expect(types.filter((t) => t === 'peremption_30j').length).toBe(2);
    expect(types.filter((t) => t === 'peremption_7j').length).toBe(2);
  });

  it('idempotence : repasser le cron le même jour ne crée pas de doublon', async () => {
    await makeBoite(isoOffset(15));
    await runPeremptionCron(env.handle.db, TODAY);
    const before = await env.handle.db.select().from(alertes);
    expect(before.length).toBe(2);

    await runPeremptionCron(env.handle.db, TODAY);
    const after = await env.handle.db.select().from(alertes);
    expect(after.length).toBe(2);
  });

  it("idempotence : cron passé hier puis rejoué aujourd'hui ne dupplique pas le 30j", async () => {
    await makeBoite(isoOffset(15));
    const yesterday = new Date(TODAY);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    await runPeremptionCron(env.handle.db, yesterday);
    await runPeremptionCron(env.handle.db, TODAY);
    const rows30 = await env.handle.db
      .select()
      .from(alertes)
      .where(eq(alertes.type, 'peremption_30j'));
    expect(rows30.length).toBe(2);
  });

  it('ignore les boîtes périmées (statut perimee) et soft-deleted', async () => {
    // Boîte au statut perimee : à J-2 mais marquée déjà périmée.
    await env.handle.db.insert(boites).values({
      officineId,
      cip13: '3400930000019',
      peremption: isoOffset(2),
      ajouteePar: userOwner,
      statut: 'perimee',
    });
    // Boîte soft-deleted : à J-2 aussi.
    const [b] = await env.handle.db
      .insert(boites)
      .values({
        officineId,
        cip13: '3400930000019',
        peremption: isoOffset(2),
        ajouteePar: userOwner,
      })
      .returning({ id: boites.id });
    await env.handle.db.update(boites).set({ deletedAt: new Date() }).where(eq(boites.id, b!.id));

    const result = await runPeremptionCron(env.handle.db, TODAY);
    expect(result.alertsCreated).toBe(0);
  });

  it('ignore les boîtes très futures (>30j)', async () => {
    await makeBoite(isoOffset(60));
    const result = await runPeremptionCron(env.handle.db, TODAY);
    expect(result.alertsCreated).toBe(0);
  });

  it("ignore les partages soft-deleted (un editor révoqué ne reçoit plus d'alerte)", async () => {
    // Soft-delete du partage editor.
    await env.handle.db
      .update(partages)
      .set({ deletedAt: new Date() })
      .where(and(eq(partages.userId, userEditor), eq(partages.officineId, officineId)));

    await makeBoite(isoOffset(15));
    const result = await runPeremptionCron(env.handle.db, TODAY);
    // Plus que owner.
    expect(result.alertsCreated).toBe(1);
  });

  it('payload contient boite_id, cip13 et peremption pour traçabilité', async () => {
    const boiteId = await makeBoite(isoOffset(20));
    await runPeremptionCron(env.handle.db, TODAY);
    const [a] = await env.handle.db.select().from(alertes).limit(1);
    expect(a?.payload).toMatchObject({
      boite_id: boiteId,
      cip13: '3400930000019',
    });
  });
});
