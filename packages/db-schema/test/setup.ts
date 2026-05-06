// packages/db-schema/test/setup.ts
// Re-export depuis src/testing.ts pour rester DRY entre les tests internes
// au package et ceux qui importent via `@piloo/db-schema/testing`.
export { setupTestDb, truncateAll, type TestDb } from '../src/testing.ts';
