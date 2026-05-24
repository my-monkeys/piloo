// Serializers /v1/officines/{id}/partages (#339).
import type { PartageMember, PendingMemberInvitation } from '@piloo/api-contract';
import type { Invitation } from '@piloo/db-schema';

import type { MemberRow } from './repo';

export function serializeMember(row: MemberRow): PartageMember {
  // acceptedAt est forcément non-null ici — listMembers filtre dessus.
  const acceptedAt = row.partage.acceptedAt;
  if (acceptedAt === null) {
    throw new Error('serializeMember called on a non-accepted partage');
  }
  return {
    user_id: row.partage.userId,
    email: row.email,
    display_name: row.displayName,
    role: row.partage.role,
    invited_at: row.partage.invitedAt.toISOString(),
    accepted_at: acceptedAt.toISOString(),
  };
}

export function serializePendingInvitation(inv: Invitation): PendingMemberInvitation {
  return {
    invitation_id: inv.id,
    email: inv.email,
    role: inv.role,
    expires_at: inv.expiresAt.toISOString(),
    created_at: inv.createdAt.toISOString(),
  };
}
