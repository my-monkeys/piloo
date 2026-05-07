// GET /api/v1/sync/pull?since=ISO&cursor=base64url&limit=200 (#93).
import { z } from 'zod';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { buildPullResponse, decodeCursor } from '@/lib/sync/pull';
import { zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const QuerySchema = z.object({
  since: z.iso.datetime().optional(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const url = new URL(request.url);
  const parsed = QuerySchema.safeParse({
    since: url.searchParams.get('since') ?? undefined,
    cursor: url.searchParams.get('cursor') ?? undefined,
    limit: url.searchParams.get('limit') ?? undefined,
  });
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const cursor = parsed.data.cursor ? decodeCursor(parsed.data.cursor) : null;

  const result = await buildPullResponse({
    db: getDb(),
    userId: auth.user.id,
    since: parsed.data.since ? new Date(parsed.data.since) : null,
    cursor,
    limit: parsed.data.limit,
  });

  return Response.json(
    {
      entities: result.entities,
      deleted: result.deleted,
      server_time: result.serverTime,
      next_cursor: result.nextCursor,
    },
    { status: 200 },
  );
}
