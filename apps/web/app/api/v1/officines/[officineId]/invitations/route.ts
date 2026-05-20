// POST /api/v1/officines/{officineId}/invitations (#123).
//
// Crée une invitation à rejoindre l'officine avec un rôle donné.
// Owner uniquement — un editor ne peut pas inviter de nouveaux
// membres (cf. matrice RBAC docs/data-model.md §Partages).
import { officines as officinesTable, users as usersTable } from '@piloo/db-schema';
import { CreateInvitationInputSchema } from '@piloo/api-contract';
import { eq } from 'drizzle-orm';
import { z } from 'zod';

import { requireAuth, requireRole } from '@/lib/auth/guards';
import { getDb } from '@/lib/db';
import { sendEmail } from '@/lib/email/client';
import { renderInvitation } from '@/lib/email/templates/invitation';
import { createInvitation } from '@/lib/invitations/repo';
import { serializeInvitation } from '@/lib/invitations/serialize';
import { apiErrorResponse, zodErrorResponse } from '@/lib/server/errors';
import { log } from '@/lib/server/logger';

export const dynamic = 'force-dynamic';

const ParamsSchema = z.object({ officineId: z.uuid() });

interface RouteContext {
  params: Promise<{ officineId: string }>;
}

export async function POST(request: Request, context: RouteContext): Promise<Response> {
  const auth = await requireAuth(request);
  if (auth instanceof Response) return auth;

  const rawParams = await context.params;
  const parsedParams = ParamsSchema.safeParse(rawParams);
  if (!parsedParams.success) return zodErrorResponse(parsedParams.error);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return apiErrorResponse('validation_error', 'Body JSON invalide.');
  }
  const parsedBody = CreateInvitationInputSchema.safeParse(body);
  if (!parsedBody.success) return zodErrorResponse(parsedBody.error);

  const db = getDb();
  const partage = await requireRole(auth.user.id, parsedParams.data.officineId, ['owner'], { db });
  if (partage instanceof Response) return partage;

  const invitation = await createInvitation(db, {
    officineId: parsedParams.data.officineId,
    invitedByUserId: auth.user.id,
    role: parsedBody.data.role,
    email: parsedBody.data.email ?? null,
    ttlHours: parsedBody.data.ttlHours ?? 72,
  });

  // #127 — envoi mail à l'invité si email fourni. Best-effort : si le
  // mail rate, l'invitation reste valide (l'owner peut renvoyer le lien
  // manuellement depuis l'écran partages).
  if (invitation.email) {
    void sendInvitationEmail(db, invitation, parsedParams.data.officineId, auth.user.id);
  }

  return Response.json(serializeInvitation(invitation), { status: 201 });
}

async function sendInvitationEmail(
  db: ReturnType<typeof getDb>,
  invitation: {
    id: string;
    email: string | null;
    role: 'owner' | 'editor' | 'viewer';
    expiresAt: Date;
  },
  officineId: string,
  inviterUserId: string,
): Promise<void> {
  if (!invitation.email) return;
  try {
    const [officineRow] = await db
      .select({ nom: officinesTable.nom })
      .from(officinesTable)
      .where(eq(officinesTable.id, officineId))
      .limit(1);
    const [inviterRow] = await db
      .select({ name: usersTable.name })
      .from(usersTable)
      .where(eq(usersTable.id, inviterUserId))
      .limit(1);
    if (!officineRow || !inviterRow) return;

    const appUrl = process.env['NEXT_PUBLIC_APP_URL'] ?? 'http://localhost:3000';
    const inviteUrl = `${appUrl}/invitations/${invitation.id}`;
    const rendered = renderInvitation({
      inviteUrl,
      officineNom: officineRow.nom,
      invitedByName: inviterRow.name,
      role: invitation.role,
      expiresAt: invitation.expiresAt,
    });
    await sendEmail({
      to: invitation.email,
      subject: rendered.subject,
      html: rendered.html,
      text: rendered.text,
      tag: 'invitation',
    });
  } catch (e) {
    log.error('invitation.email.failed', {
      invitationId: invitation.id,
      message: e instanceof Error ? e.message : 'unknown',
    });
  }
}
