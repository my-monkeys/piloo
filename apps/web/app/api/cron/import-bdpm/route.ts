// Cron mensuel d'import BDPM (#74).
//
// Tourne via Vercel Cron (cf. apps/web/vercel.json, "0 3 5 * *"
// = 03h00 le 5 de chaque mois). Vercel envoie GET avec header
// `Authorization: Bearer <CRON_SECRET>`.
//
// Flux :
//   1. Télécharge les TSV depuis base-donnees-publique.medicaments.gouv.fr
//      (encodage Latin-1 → décodé en UTF-8).
//   2. Détermine la version BDPM (= aujourd'hui en UTC).
//   3. Lance `importBdpm()` qui upsert dans `medicaments_bdpm`.
//   4. Invalide le cache /tmp du SQLite mobile en touchant
//      la nouvelle version (le endpoint `/bdpm/sqlite` régénérera
//      automatiquement à la prochaine requête).
//
// Idempotent : si le contenu n'a pas changé, l'UPSERT ne touche
// que `version_bdpm` → coût Postgres minime.
import { importBdpm } from '@/lib/bdpm/import';
import { getDb } from '@/lib/db';
import { apiErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';
// Download ~7 Mo TSV + import ~14 batches Postgres = ~15-20s. Marge 60s.
export const maxDuration = 60;

const CIS_URL = 'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_bdpm.txt';
const CIP_URL = 'https://base-donnees-publique.medicaments.gouv.fr/download/file/CIS_CIP_bdpm.txt';

export async function GET(request: Request): Promise<Response> {
  const expected = process.env['CRON_SECRET'];
  if (!expected) {
    log.error('cron.import_bdpm.config_missing', {});
    return apiErrorResponse('internal_error', 'Cron secret non configuré.');
  }
  const got = request.headers.get('authorization');
  if (got !== `Bearer ${expected}`) {
    return apiErrorResponse('unauthorized', 'Authentification cron invalide.');
  }

  const t0 = Date.now();
  log.info('cron.import_bdpm.start', {});

  try {
    const [cisRaw, cipRaw] = await Promise.all([fetchLatin1(CIS_URL), fetchLatin1(CIP_URL)]);

    // Version = date du jour UTC en YYYY-MM-DD. data.gouv ne nous
    // donne pas la version officielle dans le fichier, donc on
    // utilise la date d'import comme proxy — suffisant pour le diff
    // mobile.
    const versionBdpm = new Date().toISOString().slice(0, 10);

    const result = await importBdpm(getDb(), {
      cisContent: cisRaw,
      cipContent: cipRaw,
      versionBdpm,
    });

    const durationMs = Date.now() - t0;
    log.info('cron.import_bdpm.done', { ...result, durationMs });
    return Response.json({ ok: true, version: versionBdpm, ...result }, { status: 200 });
  } catch (e) {
    log.error('cron.import_bdpm.failed', { error: String(e) });
    return apiErrorResponse('internal_error', 'Import BDPM en échec.');
  }
}

/// BDPM est servie en Latin-1 historiquement ; on décode explicitement
/// pour ne pas se retrouver avec `comprim�` en base.
async function fetchLatin1(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (piloo-cron)' },
  });
  if (!res.ok) {
    throw new Error(`HTTP ${String(res.status)} pour ${url}`);
  }
  const buf = await res.arrayBuffer();
  return new TextDecoder('latin1').decode(buf);
}
