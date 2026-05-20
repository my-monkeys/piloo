// Page d'attente après sign-up email (#62).
//
// Affichée juste après la création du compte : Better Auth a déjà
// envoyé le magic link 1h via emailVerification.sendVerificationEmail.
// L'utilisateur peut redemander un envoi (rate-limit côté Better Auth)
// ou revenir vers sign-in.
'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { sendVerificationEmail, WebAuthError } from '@/lib/auth/client';

export default function CheckInboxPage() {
  const params = useSearchParams();
  const email = params.get('email') ?? '';
  const [resending, setResending] = useState(false);
  const [feedback, setFeedback] = useState<{ kind: 'ok' | 'err'; msg: string } | null>(null);

  async function onResend() {
    if (!email) return;
    setResending(true);
    setFeedback(null);
    try {
      await sendVerificationEmail(email);
      setFeedback({ kind: 'ok', msg: 'Email renvoyé. Pensez à regarder vos spams.' });
    } catch (err) {
      const msg = err instanceof WebAuthError ? err.message : 'Renvoi impossible.';
      setFeedback({ kind: 'err', msg });
    } finally {
      setResending(false);
    }
  }

  return (
    <Card>
      <CardContent className="pt-6 space-y-4 text-center">
        <h1 className="font-display text-2xl">Vérifiez votre email</h1>
        <p className="text-sm text-muted-foreground">
          {email ? (
            <>
              On vient d'envoyer un lien de confirmation à <strong>{email}</strong>. Cliquez dessus
              dans l'heure pour activer votre compte.
            </>
          ) : (
            <>
              On vient d'envoyer un lien de confirmation. Cliquez dessus dans l'heure pour activer
              votre compte.
            </>
          )}
        </p>
        <p className="text-xs text-muted-foreground">
          Pensez à vérifier vos spams. Le lien expire dans 1 heure.
        </p>

        {email && (
          <Button
            type="button"
            variant="outline"
            disabled={resending}
            onClick={() => {
              void onResend();
            }}
          >
            {resending ? 'Envoi…' : 'Renvoyer le lien'}
          </Button>
        )}

        {feedback && (
          <p
            className={
              feedback.kind === 'ok' ? 'text-sm text-piloo-primary' : 'text-sm text-destructive'
            }
          >
            {feedback.msg}
          </p>
        )}

        <p className="text-sm text-muted-foreground pt-4">
          <Link href="/sign-in" className="text-piloo-primary underline">
            Retour à la connexion
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
