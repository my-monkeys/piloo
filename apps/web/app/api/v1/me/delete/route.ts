// POST /api/v1/me/delete — déclenche la suppression de compte (#159).
//
// Le compte reste accessible pendant 7 jours pour permettre la
// restauration via /api/v1/me/restore. Au-delà, le cron anonymise.
import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { requestAccountDeletion } from '@/lib/me/delete';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const result = await requestAccountDeletion(getDb(), auth.user.id);
  return Response.json(
    {
      deleted_at: result.deletedAt.toISOString(),
      scheduled_anonymization_at: result.scheduledAnonymizationAt.toISOString(),
    },
    { status: 200 },
  );
}
