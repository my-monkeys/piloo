// GET /api/status — health check public détaillé (#148).
//
// Plus riche que /api/health : vérifie aussi la DB Postgres + l'état
// BDPM + état pipeline IA. Endpoint public (lecture seule, pas de
// données nominatives), utilisé par la page /status pour afficher
// "tout va bien" / "incident en cours".
import { sql } from 'drizzle-orm';

import { medicamentsBdpm } from '@piloo/db-schema';

import { getDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

interface ComponentStatus {
  name: string;
  status: 'ok' | 'degraded' | 'down';
  details?: string;
}

interface StatusResponse {
  status: 'ok' | 'degraded' | 'down';
  timestamp: string;
  components: ComponentStatus[];
}

export async function GET(): Promise<Response> {
  const components: ComponentStatus[] = [];

  // 1. Database round-trip + BDPM stats en une seule query (économe).
  try {
    const db = getDb();
    const [stats] = await db
      .select({
        total: sql<number>`count(*)::int`,
        withSummary: sql<number>`count(*) filter (where ${medicamentsBdpm.aiSummary} is not null)::int`,
        version: sql<string | null>`max(${medicamentsBdpm.versionBdpm})::text`,
      })
      .from(medicamentsBdpm);

    components.push({
      name: 'database',
      status: 'ok',
      details: 'Postgres répond en < 1 s.',
    });
    if (stats) {
      const summaryRatio =
        stats.total > 0 ? Math.round((stats.withSummary / stats.total) * 100) : 0;
      components.push({
        name: 'bdpm',
        status: stats.total > 0 ? 'ok' : 'degraded',
        details: stats.version
          ? `Version ${stats.version} · ${String(stats.total)} médicaments`
          : 'Base BDPM vide — import non encore exécuté.',
      });
      components.push({
        name: 'ai_summaries',
        status: summaryRatio >= 50 ? 'ok' : 'degraded',
        details: `${String(stats.withSummary)} / ${String(stats.total)} résumés générés (${String(summaryRatio)}%)`,
      });
    }
  } catch (e) {
    components.push({
      name: 'database',
      status: 'down',
      details: e instanceof Error ? e.message : 'Erreur inconnue.',
    });
  }

  // Status agrégé : down si un composant est down, degraded si au
  // moins un est degraded, sinon ok.
  let global: ComponentStatus['status'] = 'ok';
  for (const c of components) {
    if (c.status === 'down') {
      global = 'down';
      break;
    }
    if (c.status === 'degraded') global = 'degraded';
  }

  const body: StatusResponse = {
    status: global,
    timestamp: new Date().toISOString(),
    components,
  };
  return Response.json(body, { status: global === 'down' ? 503 : 200 });
}
