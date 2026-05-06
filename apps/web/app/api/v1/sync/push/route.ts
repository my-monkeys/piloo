// POST /api/v1/sync/push (#92).
import { SyncPushRequestSchema, type SyncAck } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { applyOperation } from '@/lib/sync/engine';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }

  const parsed = SyncPushRequestSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  // On séquence les opérations dans l'ordre reçu : si plusieurs ops
  // touchent la même entité (e.g. create + update), l'ordre client doit
  // être préservé.
  const acks: SyncAck[] = [];
  for (const op of parsed.data.operations) {
    acks.push(
      await applyOperation({ db, userId: auth.user.id, clientId: parsed.data.client_id }, op),
    );
  }

  return Response.json({ acks, server_time: new Date().toISOString() }, { status: 200 });
}
