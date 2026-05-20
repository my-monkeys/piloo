// Bouton client d'acceptation d'invitation (#125).
//
// Si l'API renvoie 401 → l'utilisateur n'est pas auth → on le route
// vers /sign-in avec returnTo pour qu'il revienne ici après login.
'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { Button } from '@/components/ui/button';

export function AcceptButton({ token }: { token: string }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onAccept() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/invitations/${token}/accept`, {
        method: 'POST',
        credentials: 'include',
      });
      if (res.status === 401) {
        const returnTo = encodeURIComponent(`/invitations/${token}`);
        router.push(`/sign-in?returnTo=${returnTo}`);
        return;
      }
      if (!res.ok) {
        const body = (await res.json().catch(() => null)) as {
          error?: { message?: string };
        } | null;
        setError(body?.error?.message ?? `Erreur ${String(res.status)}`);
        return;
      }
      router.push('/inventory');
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-3">
      <Button
        onClick={() => {
          void onAccept();
        }}
        disabled={loading}
        className="w-full"
      >
        {loading ? 'Acceptation…' : 'Rejoindre l’officine'}
      </Button>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
