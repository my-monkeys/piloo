// Better Auth — instance serveur (ADR 0004). Email/password + bearer pour
// le mobile (#40). Apple/Google/2FA/magic link sont laissés à leurs
// tickets dédiés (#62/#64/#65/#157).
//
// Initialisation paresseuse pour ne pas exiger DATABASE_URL au build :
// Next.js compile les modules sans avoir nécessairement les variables d'env
// en place ; le client Drizzle n'est créé qu'au premier appel runtime.
import { accounts, sessions, users, verifications, type Db } from '@piloo/db-schema';
import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { bearer } from 'better-auth/plugins';

import { getDb } from '@/lib/db';

import { createPersonalOfficineFor } from './hooks.ts';

interface BuildAuthOptions {
  db: Db;
  secret: string;
  baseURL: string;
}

function buildAuth({ db, secret, baseURL }: BuildAuthOptions) {
  return betterAuth({
    secret,
    baseURL,
    database: drizzleAdapter(db, {
      provider: 'pg',
      // Les clés correspondent aux `modelName` configurés ci-dessous (pluriel
      // côté Piloo) et non aux noms par défaut Better Auth (singulier). Sinon
      // l'adapter renvoie "The model 'users' was not found in the schema".
      schema: {
        users,
        sessions,
        accounts,
        verifications,
      },
    }),
    emailAndPassword: {
      enabled: true,
      // Pas de vérification d'email obligatoire pour le POC #40 ; activé via
      // le ticket #62 (magic link 1h).
      requireEmailVerification: false,
    },
    user: {
      // Mapping vers notre table `users` (plurielle) au lieu du `user` par
      // défaut de Better Auth.
      modelName: 'users',
      additionalFields: {
        nom: { type: 'string', required: true, input: true },
        prenom: { type: 'string', required: true, input: true },
        typeCompte: { type: 'string', required: true, input: true },
        telephone: { type: 'string', required: false, input: true },
      },
    },
    session: { modelName: 'sessions' },
    account: { modelName: 'accounts' },
    verification: { modelName: 'verifications' },
    advanced: {
      database: {
        // Cohérence avec les autres tables (uuid v4) — cf. règle "IDs UUID v4"
        // du CLAUDE.md packages/db-schema.
        generateId: () => crypto.randomUUID(),
      },
    },
    databaseHooks: {
      user: {
        create: {
          // #69 — auto-création de l'officine perso pour les comptes
          // particuliers. Pour les comptes pro, le user crée ses
          // officines "patient" à la demande.
          after: async (user) => {
            await createPersonalOfficineFor(db, {
              id: user.id,
              name: user.name,
              typeCompte: (user as { typeCompte?: string }).typeCompte,
            });
          },
        },
      },
    },
    plugins: [bearer()],
  });
}

export type AuthInstance = ReturnType<typeof buildAuth>;

// Export public pour les tests d'intégration : on injecte une DB jetable
// (testcontainers) et un secret de test sans toucher à l'env de prod.
export function createAuth(options: BuildAuthOptions): AuthInstance {
  return buildAuth(options);
}

let cached: AuthInstance | undefined;

export function getAuth(): AuthInstance {
  cached ??= buildAuth({
    db: getDb(),
    secret: getRequiredSecret(),
    baseURL: process.env['BETTER_AUTH_URL'] ?? 'http://localhost:3000',
  });
  return cached;
}

function getRequiredSecret(): string {
  const secret = process.env['BETTER_AUTH_SECRET'];
  if (!secret || secret === 'changeme') {
    throw new Error(
      'BETTER_AUTH_SECRET is not set (or still "changeme"). Generate one with `openssl rand -hex 32`.',
    );
  }
  return secret;
}
