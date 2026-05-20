// Better Auth — instance serveur (ADR 0004). Email/password + bearer pour
// le mobile (#40). Apple (#64) et Google (#65) ajoutés via `socialProviders`
// — la config est pré-calculée au module-load (top-level await) car
// générer le `client_secret` Apple nécessite jose/ES256.
//
// Initialisation paresseuse pour ne pas exiger DATABASE_URL au build :
// Next.js compile les modules sans avoir nécessairement les variables d'env
// en place ; le client Drizzle n'est créé qu'au premier appel runtime.
import { accounts, sessions, users, verifications, type Db } from '@piloo/db-schema';
import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { bearer } from 'better-auth/plugins';

import { getDb } from '@/lib/db';
import { sendEmail } from '@/lib/email/client';
import { renderVerifyEmail } from '@/lib/email/templates/verify-email';

import { createPersonalOfficineFor } from './hooks.ts';
import {
  loadAppleConfig,
  loadGoogleConfig,
  type AppleProviderConfig,
  type GoogleProviderConfig,
} from './social-config.ts';

interface BuildAuthOptions {
  db: Db;
  secret: string;
  baseURL: string;
  apple?: AppleProviderConfig;
  google?: GoogleProviderConfig;
  /**
   * #62 — quand `true`, exige le clic sur le magic link 1h avant tout
   * signin email/password. La prod (`getAuth`) active toujours ce flag ;
   * les tests d'intégration sur les autres flows le gardent à `false`
   * (défaut) pour éviter d'avoir à orchestrer le magic link.
   */
  requireEmailVerification?: boolean;
}

function buildAuth({
  db,
  secret,
  baseURL,
  apple,
  google,
  requireEmailVerification = false,
}: BuildAuthOptions) {
  const socialProviders: Record<string, unknown> = {};
  if (apple) socialProviders['apple'] = apple;
  if (google) socialProviders['google'] = google;

  return betterAuth({
    secret,
    baseURL,
    // Apple requiert que appleid.apple.com soit autorisé pour le flow web ;
    // sans effet sur le flow id-token natif, mais inoffensif.
    trustedOrigins: apple ? ['https://appleid.apple.com'] : undefined,
    socialProviders,
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
      requireEmailVerification,
    },
    emailVerification: {
      sendOnSignUp: requireEmailVerification,
      autoSignInAfterVerification: true,
      // Expiration alignée sur l'AC #62 (1h).
      expiresIn: 60 * 60,
      sendVerificationEmail: async ({ user, url }) => {
        const prenom = (user as { prenom?: string }).prenom ?? user.name;
        const rendered = renderVerifyEmail({ prenom, verifyUrl: url });
        await sendEmail({
          to: user.email,
          subject: rendered.subject,
          html: rendered.html,
          text: rendered.text,
          tag: 'verify-email',
        });
      },
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

// Pré-calculé au module-load : le JWT Apple nécessite jose/ES256 (async).
// Si les env vars OAuth sont absentes (cas test/dev sans Apple/Google),
// les providers sont simplement omis.
const APPLE_CONFIG = await loadAppleConfig();
const GOOGLE_CONFIG = loadGoogleConfig();

let cached: AuthInstance | undefined;

export function getAuth(): AuthInstance {
  cached ??= buildAuth({
    db: getDb(),
    secret: getRequiredSecret(),
    baseURL: process.env['BETTER_AUTH_URL'] ?? 'http://localhost:3000',
    apple: APPLE_CONFIG,
    google: GOOGLE_CONFIG,
    // Prod : magic link 1h obligatoire (#62).
    requireEmailVerification: true,
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
