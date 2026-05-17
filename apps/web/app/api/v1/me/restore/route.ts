// POST /api/v1/me/restore — annule une demande de suppression de compte (#159).
import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { restoreAccount } from '@/lib/me/delete';
import { apiErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const ok = await restoreAccount(getDb(), auth.user.id);
  if (!ok) {
    return apiErrorResponse('not_found', 'Aucune demande de suppression en cours.');
  }
  return Response.json({ restored: true }, { status: 200 });
}
