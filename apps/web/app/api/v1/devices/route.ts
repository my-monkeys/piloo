// GET /api/v1/devices : liste les devices du user courant.
// POST /api/v1/devices : enregistre / rafraîchit un device (idempotent
// sur le couple user+token). (#124)
import { RegisterDeviceInputSchema } from '@piloo/api-contract';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { listDevicesForUser, registerDevice } from '@/lib/devices/repo';
import { serializeDevice } from '@/lib/devices/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const items = await listDevicesForUser(getDb(), auth.user.id);
  return Response.json({ items: items.map(serializeDevice) }, { status: 200 });
}

export async function POST(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = RegisterDeviceInputSchema.safeParse(body);
  if (!parsed.success) {
    return zodErrorResponse(parsed.error);
  }

  const { device, created } = await registerDevice(getDb(), {
    userId: auth.user.id,
    token: parsed.data.token,
    platform: parsed.data.platform,
    appVersion: parsed.data.app_version,
  });

  return Response.json(serializeDevice(device), { status: created ? 201 : 200 });
}
