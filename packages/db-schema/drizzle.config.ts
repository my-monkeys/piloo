// Configuration Drizzle Kit. Source du schéma TS, sortie des migrations SQL.
// Voir docs/architecture.md §"DB" et docs/data-model.md pour le modèle.
import { defineConfig } from 'drizzle-kit';

const databaseUrl = process.env['DATABASE_URL'];

if (!databaseUrl && process.env['NODE_ENV'] !== 'test') {
  // En dev/prod on attend la variable. En test/CI sans DB, drizzle-kit
  // generate fonctionne sans (génération offline depuis les fichiers TS).

  console.warn("[drizzle.config] DATABASE_URL non défini — `migrate` échouera tant qu'il manque.");
}

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema/*.ts',
  out: './migrations',
  casing: 'snake_case',
  dbCredentials: {
    url: databaseUrl ?? 'postgres://piloo:piloo@localhost:5433/piloo',
  },
  strict: true,
  verbose: true,
});
