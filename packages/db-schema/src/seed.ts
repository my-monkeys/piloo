// packages/db-schema/src/seed.ts
// Seed minimal pour le dev. Idempotent : si l'email du user dev existe déjà,
// le seed sort silencieusement plutôt que d'échouer sur l'index unique. Pour
// repartir de zéro utiliser `pnpm db:reset`.
import process from 'node:process';

import { eq } from 'drizzle-orm';

import { createDb } from './db.ts';
import { boites, officines, partages, users } from './schema/index.ts';

const SEED_EMAIL = 'dev@piloo.fr';

async function main(): Promise<void> {
  const url = process.env['DATABASE_URL'];
  if (!url) {
    throw new Error('DATABASE_URL is required to run the seed');
  }
  const handle = createDb(url);
  try {
    const existing = await handle.db
      .select({ id: users.id })
      .from(users)
      .where(eq(users.email, SEED_EMAIL))
      .limit(1);
    if (existing.length > 0) {
      console.info(`[seed] user ${SEED_EMAIL} already present — skipping`);
      return;
    }

    // Le mot de passe vit dans `accounts` (cf. Better Auth, ADR 0004) et n'est
    // pas créé par le seed : pour se connecter en local, passer par
    // /api/auth/sign-up/email puis pointer ce user vers les données de seed
    // existantes (ou simplement signer up avec un autre email — le seed sert
    // surtout de fixture pour les FK officines/boites/partages).
    const [user] = await handle.db
      .insert(users)
      .values({
        email: SEED_EMAIL,
        name: 'Dev Piloo',
        emailVerified: true,
        nom: 'Dev',
        prenom: 'Piloo',
        typeCompte: 'particulier',
      })
      .returning();
    if (!user) throw new Error('seed: user insert returned no row');

    const [officine] = await handle.db
      .insert(officines)
      .values({
        nom: 'Maison',
        type: 'perso',
        proprietaireUserId: user.id,
      })
      .returning();
    if (!officine) throw new Error('seed: officine insert returned no row');

    await handle.db.insert(partages).values({
      officineId: officine.id,
      userId: user.id,
      role: 'owner',
      invitedAt: new Date(),
      acceptedAt: new Date(),
    });

    const today = new Date();
    const inDays = (n: number) => {
      const d = new Date(today);
      d.setDate(d.getDate() + n);
      return d.toISOString().slice(0, 10);
    };

    await handle.db.insert(boites).values([
      {
        officineId: officine.id,
        cip13: '3400930000019',
        lot: 'LOT-DOLI-A',
        numeroSerie: 'SN-001',
        peremption: inDays(365),
        unitesInitiales: 16,
        unitesRestantes: 12,
        ajouteePar: user.id,
      },
      {
        officineId: officine.id,
        cip13: '3400930000019',
        lot: 'LOT-DOLI-B',
        numeroSerie: 'SN-002',
        peremption: inDays(180),
        unitesInitiales: 16,
        unitesRestantes: 16,
        ajouteePar: user.id,
      },
      {
        officineId: officine.id,
        cip13: '3400930000026',
        lot: 'LOT-IBU-A',
        numeroSerie: 'SN-003',
        peremption: inDays(30),
        unitesInitiales: 20,
        unitesRestantes: 8,
        ajouteePar: user.id,
      },
      {
        officineId: officine.id,
        cip13: '3400930000033',
        lot: 'LOT-OLD-A',
        numeroSerie: null,
        peremption: inDays(7),
        unitesInitiales: null,
        unitesRestantes: null,
        ajouteePar: user.id,
      },
      {
        officineId: officine.id,
        cip13: '3400930000040',
        lot: null,
        numeroSerie: null,
        peremption: inDays(-30),
        statut: 'perimee',
        unitesInitiales: 30,
        unitesRestantes: 5,
        ajouteePar: user.id,
      },
    ]);

    console.info(`[seed] inserted user=${user.id} officine=${officine.id} boites=5`);
  } finally {
    await handle.close();
  }
}

main().catch((err: unknown) => {
  console.error('[seed] failed', err);
  process.exit(1);
});
