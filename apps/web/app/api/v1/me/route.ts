// GET / PATCH /api/v1/me — profil utilisateur courant (#162).
//
// Couvre le droit de rectification RGPD (article 16) : l'utilisateur
// peut consulter et modifier ses données personnelles immédiatement,
// sans demande manuelle. L'email reste géré par Better Auth (changement
// d'email = flow dédié avec vérification).
import { UpdateMeInputSchema, type GetMeResponse } from '@piloo/api-contract';
import { users } from '@piloo/db-schema';
import { eq } from 'drizzle-orm';

import { requireAuth } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

function serializeMe(row: typeof users.$inferSelect): GetMeResponse {
  return {
    id: row.id,
    email: row.email,
    nom: row.nom,
    prenom: row.prenom,
    name: row.name,
    telephone: row.telephone,
    type_compte: row.typeCompte,
    image: row.image,
    deleted_at: row.deletedAt?.toISOString() ?? null,
    created_at: row.createdAt.toISOString(),
  };
}

export async function GET(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const db = getDb();
  const [row] = await db.select().from(users).where(eq(users.id, auth.user.id)).limit(1);
  if (!row) return apiErrorResponse('not_found', 'Utilisateur introuvable.');
  return Response.json(serializeMe(row), { status: 200 });
}

export async function PATCH(request: Request): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = UpdateMeInputSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const patch: Partial<typeof users.$inferInsert> = {};
  if (parsed.data.nom !== undefined) patch.nom = parsed.data.nom;
  if (parsed.data.prenom !== undefined) patch.prenom = parsed.data.prenom;
  if (parsed.data.telephone !== undefined) patch.telephone = parsed.data.telephone;
  if (parsed.data.name !== undefined) patch.name = parsed.data.name;
  if (parsed.data.image !== undefined) patch.image = parsed.data.image;

  if (Object.keys(patch).length === 0) {
    return apiErrorResponse('validation_error', 'Aucun champ à modifier.');
  }

  const db = getDb();
  const [updated] = await db
    .update(users)
    .set({ ...patch, updatedAt: new Date() })
    .where(eq(users.id, auth.user.id))
    .returning();
  if (!updated) return apiErrorResponse('not_found', 'Utilisateur introuvable.');
  return Response.json(serializeMe(updated), { status: 200 });
}
