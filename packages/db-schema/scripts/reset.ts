// scripts/reset.ts
// Wipe le schema public + redrop drizzle, pour qu'un `pnpm migrate && pnpm seed`
// reparte de zéro. Refuse de tourner si DATABASE_URL ressemble à de la prod.
import process from 'node:process';

import postgres from 'postgres';

const url = process.env['DATABASE_URL'];
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}
if (url.includes('prod') || url.includes('production')) {
  console.error('DATABASE_URL looks like a production URL — refusing to reset');
  process.exit(1);
}

const sql = postgres(url, { max: 1 });
try {
  await sql.unsafe('DROP SCHEMA IF EXISTS public CASCADE');
  await sql.unsafe('CREATE SCHEMA public');
  await sql.unsafe('DROP SCHEMA IF EXISTS drizzle CASCADE');
  console.info('[reset] schema wiped');
} finally {
  await sql.end({ timeout: 5 });
}
