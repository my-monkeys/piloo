// POST /api/v1/me/export — export RGPD article 20 (#158).
//
// Retourne en JSON l'intégralité des données personnelles de l'user
// authentifié. Téléchargement immédiat (Content-Disposition attachment).
import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { exportUserData } from '@/lib/me/export';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const data = await exportUserData(getDb(), auth.user.id);
  const filename = `piloo-export-${auth.user.id}-${new Date().toISOString().slice(0, 10)}.json`;
  return new Response(JSON.stringify(data, null, 2), {
    status: 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Content-Disposition': `attachment; filename="${filename}"`,
    },
  });
}
