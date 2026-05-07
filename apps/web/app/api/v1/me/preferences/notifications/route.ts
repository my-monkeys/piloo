// GET / PUT /api/v1/me/preferences/notifications (#138).
import {
  DEFAULT_NOTIF_PREFERENCES,
  type NotifPreferences,
  UpdateNotifPreferencesInputSchema,
} from '@piloo/api-contract';
import { users } from '@piloo/db-schema';
import { eq } from 'drizzle-orm';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

interface UserPreferences {
  notifications?: NotifPreferences;
  [k: string]: unknown;
}

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const db = getDb();
  const [row] = await db
    .select({ preferences: users.preferences })
    .from(users)
    .where(eq(users.id, auth.user.id))
    .limit(1);
  if (!row) {
    return apiErrorResponse('not_found', 'Utilisateur introuvable.');
  }
  const prefs = (row.preferences as UserPreferences | null)?.notifications;
  return Response.json(prefs ?? DEFAULT_NOTIF_PREFERENCES, { status: 200 });
}

export async function PUT(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdateNotifPreferencesInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const [existing] = await db
    .select({ preferences: users.preferences })
    .from(users)
    .where(eq(users.id, auth.user.id))
    .limit(1);
  if (!existing) {
    return apiErrorResponse('not_found', 'Utilisateur introuvable.');
  }

  const merged: UserPreferences = {
    ...((existing.preferences as UserPreferences | null) ?? {}),
    notifications: parsed.data,
  };

  await db.update(users).set({ preferences: merged }).where(eq(users.id, auth.user.id));

  return Response.json(parsed.data, { status: 200 });
}
