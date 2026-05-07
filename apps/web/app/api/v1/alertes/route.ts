// GET /api/v1/alertes (#140).
import { ListAlertesQuerySchema, type ListAlertesResponse } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { listAlertesForUser } from '@/lib/alertes/repo';
import { serializeAlerte } from '@/lib/alertes/serialize';
import { getDb } from '@/lib/db';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const DEFAULT_LIMIT = 20;

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const params = Object.fromEntries(url.searchParams.entries());
  const parsed = ListAlertesQuerySchema.safeParse(params);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const page = await listAlertesForUser(db, {
    userId: auth.user.id,
    limit: parsed.data.limit ?? DEFAULT_LIMIT,
    cursor: parsed.data.cursor ?? null,
    type: parsed.data.type ?? null,
    unreadOnly: parsed.data.unread_only ?? false,
  });

  const body: ListAlertesResponse = {
    items: page.items.map(serializeAlerte),
    next_cursor: page.nextCursor,
  };
  return Response.json(body, { status: 200 });
}
