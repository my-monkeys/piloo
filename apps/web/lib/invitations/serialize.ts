import type { Invitation as ApiInvitation, InvitationPreview } from '@piloo/api-contract';
import type { Invitation } from '@piloo/db-schema';

import { statusOf } from './repo';

export function serializeInvitation(row: Invitation): ApiInvitation {
  return {
    id: row.id,
    officine_id: row.officineId,
    role: row.role,
    invited_by_user_id: row.invitedByUserId,
    email: row.email,
    expires_at: row.expiresAt.toISOString(),
    accepted_at: row.acceptedAt?.toISOString() ?? null,
    accepted_by_user_id: row.acceptedByUserId,
    created_at: row.createdAt.toISOString(),
    updated_at: row.updatedAt.toISOString(),
    deleted_at: row.deletedAt?.toISOString() ?? null,
  };
}

export function serializePreview(
  row: Invitation,
  officineNom: string,
  invitedByName: string,
): InvitationPreview {
  return {
    officine_nom: officineNom,
    role: row.role,
    invited_by_name: invitedByName,
    expires_at: row.expiresAt.toISOString(),
    status: statusOf(row),
  };
}
