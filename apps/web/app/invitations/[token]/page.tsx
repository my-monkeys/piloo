// Page publique d'acceptation d'invitation (#125).
//
// URL : /invitations/{token}. Le serveur fetch le preview (officine,
// rôle, inviteur) côté Server Component pour SSR. Le bouton accept
// est un Client Component qui :
//   - Si user non-loggé → redirige /sign-in?returnTo=/invitations/{token}
//   - Si user loggé → POST /api/v1/invitations/{token}/accept
//   - Au succès → redirect /inventory de l'officine rejointe
import { headers } from 'next/headers';

import { AcceptButton } from './accept-button';

interface InvitationPreview {
  officine_nom: string;
  role: 'owner' | 'editor' | 'viewer';
  invited_by_name: string;
  expires_at: string;
  status: 'pending' | 'expired' | 'accepted' | 'revoked';
}

async function fetchPreview(token: string): Promise<InvitationPreview | null> {
  const hs = await headers();
  const host = hs.get('host') ?? 'localhost:3000';
  const proto = host.includes('localhost') ? 'http' : 'https';
  const res = await fetch(`${proto}://${host}/api/v1/invitations/${token}`, {
    cache: 'no-store',
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`preview: ${String(res.status)}`);
  return (await res.json()) as InvitationPreview;
}

const roleLabel: Record<InvitationPreview['role'], string> = {
  owner: 'Propriétaire',
  editor: 'Éditeur',
  viewer: 'Lecteur',
};

export default async function InvitationPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  const preview = await fetchPreview(token);

  if (!preview) {
    return (
      <Centered>
        <h1 className="font-display text-2xl">Invitation introuvable</h1>
        <p className="text-muted-foreground mt-2">Ce lien est invalide ou a été supprimé.</p>
      </Centered>
    );
  }

  if (preview.status === 'expired') {
    return (
      <Centered>
        <h1 className="font-display text-2xl">Invitation expirée</h1>
        <p className="text-muted-foreground mt-2">
          Ce lien a expiré le {formatDate(preview.expires_at)}. Demande à {preview.invited_by_name}{' '}
          d&apos;en générer un nouveau.
        </p>
      </Centered>
    );
  }

  if (preview.status === 'accepted') {
    return (
      <Centered>
        <h1 className="font-display text-2xl">Déjà accepté</h1>
        <p className="text-muted-foreground mt-2">
          Tu as déjà rejoint l&apos;officine «&nbsp;{preview.officine_nom}&nbsp;».
        </p>
      </Centered>
    );
  }

  if (preview.status === 'revoked') {
    return (
      <Centered>
        <h1 className="font-display text-2xl">Invitation révoquée</h1>
        <p className="text-muted-foreground mt-2">
          {preview.invited_by_name} a annulé cette invitation.
        </p>
      </Centered>
    );
  }

  return (
    <Centered>
      <p className="text-sm text-muted-foreground">Invitation</p>
      <h1 className="font-display text-3xl mt-1">{preview.officine_nom}</h1>
      <p className="mt-4 text-base">
        <strong>{preview.invited_by_name}</strong> t&apos;invite à rejoindre son officine en tant
        que <strong>{roleLabel[preview.role]}</strong>.
      </p>
      <p className="text-xs text-muted-foreground mt-2">
        Lien valide jusqu&apos;au {formatDate(preview.expires_at)}.
      </p>
      <div className="mt-6">
        <AcceptButton token={token} />
      </div>
    </Centered>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen flex items-center justify-center px-6 py-12">
      <div className="max-w-md w-full rounded-2xl border bg-card p-8 text-center">{children}</div>
    </div>
  );
}

function formatDate(iso: string): string {
  return new Date(iso).toLocaleString('fr-FR', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
