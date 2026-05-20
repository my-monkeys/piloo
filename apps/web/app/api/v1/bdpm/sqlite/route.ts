// GET /api/v1/bdpm/sqlite — sert le fichier SQLite BDPM mobile (#78).
//
// Format de réponse : binaire gzippé (`Content-Encoding: gzip`,
// `Content-Type: application/x-sqlite3`).
//
// Le mobile envoie `?version=YYYY-MM-DD` pour skip le download s'il
// a déjà cette version → 304 Not Modified.
//
// Génération : on-the-fly depuis Postgres via `generateBdpmSqlite`.
// La 1ère requête (cold) prend ~5-10s ; les suivantes (warm) sont
// quasi instant grâce au cache /tmp (Vercel le préserve entre
// invocations sur la même instance).
//
// À optimiser plus tard si nécessaire :
//   - pré-générer via cron → upload Vercel Blob ou apps/web/public
//   - signed URL CDN pour éviter de tirer Postgres à chaque cold start
import { existsSync } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { gzipSync } from 'node:zlib';

import { getBdpmStats } from '@/lib/bdpm/repo';
import { generateBdpmSqlite } from '@/lib/bdpm/sqlite';
import { getDb } from '@/lib/db';

export const dynamic = 'force-dynamic';
// Génération + gzip ~5-10s en cold start ; on prend de la marge.
export const maxDuration = 60;

const FALLBACK_VERSION = 'unknown';

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const requestedVersion = url.searchParams.get('version');

  const db = getDb();
  const stats = await getBdpmStats(db);
  const currentVersion = stats.version ?? FALLBACK_VERSION;

  if (requestedVersion && requestedVersion === currentVersion) {
    return new Response(null, {
      status: 304,
      headers: { 'X-Piloo-Bdpm-Version': currentVersion },
    });
  }

  // Cache /tmp : persiste entre invocations chaudes Vercel. Si une
  // nouvelle version a été importée, on régénère.
  const tmpPath = `/tmp/bdpm-${currentVersion}.sqlite.gz`;
  let payload: Buffer;
  if (existsSync(tmpPath)) {
    payload = await readFile(tmpPath);
  } else {
    // Génère un .sqlite frais dans /tmp puis gzippe en mémoire.
    const rawPath = `/tmp/bdpm-${currentVersion}.sqlite`;
    await generateBdpmSqlite(db, rawPath);
    const raw = await readFile(rawPath);
    payload = gzipSync(raw);
    // Cache pour les invocations chaudes suivantes.
    await writeFile(tmpPath, payload);
  }

  return new Response(new Uint8Array(payload), {
    status: 200,
    headers: {
      'Content-Type': 'application/x-sqlite3',
      'Content-Encoding': 'gzip',
      'Content-Length': payload.length.toString(),
      'X-Piloo-Bdpm-Version': currentVersion,
      // 1 jour : la BDPM bouge au max 2×/jour côté data.gouv ; cache
      // côté CDN OK, le mobile envoie de toute façon `?version=` pour
      // hit le 304 si rien n'a changé.
      'Cache-Control': 'public, max-age=86400, s-maxage=86400',
    },
  });
}
