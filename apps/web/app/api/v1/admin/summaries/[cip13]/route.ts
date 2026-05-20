// PATCH /api/v1/admin/summaries/{cip13} — édite manuellement le résumé IA.
// DELETE /api/v1/admin/summaries/{cip13} — reset (sera re-généré au prochain run).
import { medicamentsBdpm } from '@piloo/db-schema';
import { eq } from 'drizzle-orm';
import { z } from 'zod';

import { requireAdmin } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';

export const dynamic = 'force-dynamic';

const PatchSchema = z.object({
  ai_summary: z.string().min(1).max(2000),
});

interface Ctx {
  params: Promise<{ cip13: string }>;
}

export async function PATCH(request: Request, ctx: Ctx): Promise<Response> {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) return auth;

  const { cip13 } = await ctx.params;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsed = PatchSchema.safeParse(body);
  if (!parsed.success) return zodErrorResponse(parsed.error);

  const db = getDb();
  const [updated] = await db
    .update(medicamentsBdpm)
    .set({
      aiSummary: parsed.data.ai_summary,
      // Tag manual = ne pas re-générer même si on bump la pipeline.
      aiSummaryVersion: 'manual',
    })
    .where(eq(medicamentsBdpm.cip13, cip13))
    .returning({ cip13: medicamentsBdpm.cip13 });
  if (!updated) return apiErrorResponse('not_found', 'CIP13 inconnu.');
  return Response.json({ cip13: updated.cip13 });
}

export async function DELETE(request: Request, ctx: Ctx): Promise<Response> {
  const auth = await requireAdmin(request);
  if (auth instanceof Response) return auth;

  const { cip13 } = await ctx.params;
  const db = getDb();
  const [updated] = await db
    .update(medicamentsBdpm)
    .set({ aiSummary: null, aiSummaryVersion: null })
    .where(eq(medicamentsBdpm.cip13, cip13))
    .returning({ cip13: medicamentsBdpm.cip13 });
  if (!updated) return apiErrorResponse('not_found', 'CIP13 inconnu.');
  return new Response(null, { status: 204 });
}
