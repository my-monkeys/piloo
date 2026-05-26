// Repository invitations (#123/#125).
import {
  invitations,
  officines,
  partages,
  users,
  type Db,
  type Invitation,
} from '@piloo/db-schema';
import { and, eq, isNull } from 'drizzle-orm';

export interface CreateInvitationParams {
  officineId: string;
  invitedByUserId: string;
  role: 'owner' | 'editor' | 'viewer';
  email: string | null;
  ttlHours: number;
}

export async function createInvitation(
  db: Db,
  params: CreateInvitationParams,
): Promise<Invitation> {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + params.ttlHours * 3600 * 1000);
  const [row] = await db
    .insert(invitations)
    .values({
      officineId: params.officineId,
      invitedByUserId: params.invitedByUserId,
      role: params.role,
      email: params.email,
      expiresAt,
    })
    .returning();
  if (!row) throw new Error('insert invitation returned no row');
  return row;
}

export interface InvitationPreviewRow {
  invitation: Invitation;
  officineNom: string;
  invitedByName: string;
}

export async function findInvitationByToken(
  db: Db,
  token: string,
): Promise<InvitationPreviewRow | null> {
  const [row] = await db
    .select({
      invitation: invitations,
      officineNom: officines.nom,
      invitedByName: users.name,
    })
    .from(invitations)
    .innerJoin(officines, eq(invitations.officineId, officines.id))
    .innerJoin(users, eq(invitations.invitedByUserId, users.id))
    .where(eq(invitations.id, token))
    .limit(1);
  return row ?? null;
}

/// Accepte une invitation : insère un `partages` (ou ré-active s'il
/// existe en soft-delete), marque l'invitation acceptée. Idempotent
/// si on appelle plusieurs fois pour la même (officine, user).
export async function acceptInvitation(
  db: Db,
  invitation: Invitation,
  acceptedByUserId: string,
): Promise<{ officineId: string; role: 'owner' | 'editor' | 'viewer' }> {
  const now = new Date();
  await db.transaction(async (tx) => {
    // Cherche un partage existant (même soft-deleted) pour éviter
    // d'enfreindre la contrainte UNIQUE partial sur (officine, user).
    const [existing] = await tx
      .select()
      .from(partages)
      .where(
        and(eq(partages.officineId, invitation.officineId), eq(partages.userId, acceptedByUserId)),
      )
      .limit(1);

    if (existing) {
      await tx
        .update(partages)
        .set({
          role: invitation.role,
          acceptedAt: now,
          deletedAt: null,
          invitedBy: invitation.invitedByUserId,
          invitedAt: invitation.createdAt,
          updatedAt: now,
        })
        .where(eq(partages.id, existing.id));
    } else {
      await tx.insert(partages).values({
        officineId: invitation.officineId,
        userId: acceptedByUserId,
        role: invitation.role,
        invitedBy: invitation.invitedByUserId,
        invitedAt: invitation.createdAt,
        acceptedAt: now,
      });
    }

    await tx
      .update(invitations)
      .set({
        acceptedAt: now,
        acceptedByUserId,
        updatedAt: now,
      })
      .where(eq(invitations.id, invitation.id));

    // Soft-delete les autres invitations pending pour la même officine
    // et le même email (cas où l'user a été invité plusieurs fois avant
    // d'accepter — l'ancienne reste sinon visible comme "en attente").
    if (invitation.email) {
      await tx
        .update(invitations)
        .set({ deletedAt: now, updatedAt: now })
        .where(
          and(
            eq(invitations.officineId, invitation.officineId),
            eq(invitations.email, invitation.email),
            isNull(invitations.acceptedAt),
            isNull(invitations.deletedAt),
          ),
        );
    }
  });
  return {
    officineId: invitation.officineId,
    role: invitation.role,
  };
}

export function isPending(inv: Invitation, now: Date = new Date()): boolean {
  if (inv.deletedAt !== null) return false;
  if (inv.acceptedAt !== null) return false;
  if (inv.expiresAt <= now) return false;
  return true;
}

export function statusOf(inv: Invitation, now: Date = new Date()) {
  if (inv.deletedAt !== null) return 'revoked' as const;
  if (inv.acceptedAt !== null) return 'accepted' as const;
  if (inv.expiresAt <= now) return 'expired' as const;
  return 'pending' as const;
}

/// Ré-export pour le serializer.
export function isInvitationOwnable(
  db: Db,
  invitation: Invitation,
  userId: string,
): Promise<boolean> {
  return db
    .select({ id: officines.id })
    .from(officines)
    .where(
      and(
        eq(officines.id, invitation.officineId),
        eq(officines.proprietaireUserId, userId),
        isNull(officines.deletedAt),
      ),
    )
    .limit(1)
    .then((rows) => rows.length > 0);
}
