// Page A6 Mot de passe oublié — étape 1 : saisie email (#63).
//
// Better Auth renvoie systématiquement 200 même si l'email est inconnu,
// pour éviter l'attaque par énumération. On affiche donc toujours le
// même message de succès après la soumission.
'use client';

import Link from 'next/link';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { forgetPassword, WebAuthError } from '@/lib/auth/client';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await forgetPassword(email.trim());
      setSent(true);
    } catch (err) {
      setError(err instanceof WebAuthError ? err.message : 'Envoi impossible.');
    } finally {
      setSubmitting(false);
    }
  }

  if (sent) {
    return (
      <Card>
        <CardContent className="pt-6 space-y-4 text-center">
          <h1 className="font-display text-2xl">Vérifiez votre email</h1>
          <p className="text-sm text-muted-foreground">
            Si un compte existe avec cette adresse, un lien de réinitialisation va arriver dans
            quelques minutes. Le lien expire dans 1 heure.
          </p>
          <p className="text-sm text-muted-foreground">
            <Link href="/sign-in" className="text-piloo-primary underline">
              Retour à la connexion
            </Link>
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-6 space-y-4">
        <header className="space-y-1">
          <h1 className="font-display text-2xl">Mot de passe oublié</h1>
          <p className="text-sm text-muted-foreground">
            Indique ton email et on t'envoie un lien pour en créer un nouveau.
          </p>
        </header>

        <form
          className="space-y-4"
          onSubmit={(e) => {
            void onSubmit(e);
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
              }}
            />
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Envoi…' : 'Recevoir le lien'}
          </Button>
        </form>

        <p className="text-sm text-center text-muted-foreground">
          <Link href="/sign-in" className="text-piloo-primary underline">
            Retour à la connexion
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
