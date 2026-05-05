// Connexion Drizzle pour les API Routes Next.js. Utilise la factory partagée
// `createDb` de @piloo/db-schema pour garantir le même client / parsers
// (timestamptz) que les tests d'intégration.
//
// Singleton paresseux : on ne crée la connexion qu'au premier accès, et on
// garde l'instance pour la durée du process serveur (Next.js réutilise les
// modules entre requêtes en serverless warm). Pas de close() — Next.js gère
// le cycle de vie du process.
import { createDb, type Db } from '@piloo/db-schema';

let cached: Db | undefined;

function getDatabaseUrl(): string {
  const url = process.env['DATABASE_URL'];
  if (!url) {
    throw new Error(
      'DATABASE_URL is not set. Configure it in apps/web/.env.local or the Vercel project.',
    );
  }
  return url;
}

export function getDb(): Db {
  cached ??= createDb(getDatabaseUrl()).db;
  return cached;
}
