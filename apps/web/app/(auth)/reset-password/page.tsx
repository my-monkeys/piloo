// Page A6 Mot de passe oublié — étape 2 : choix du nouveau mdp (#63).
//
// Atterrissage du lien magique reçu par email. `?token=X` injecté par
// Better Auth dans le redirectTo configuré côté forget-password.
'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { resetPassword, WebAuthError } from '@/lib/auth/client';

export default function ResetPasswordPage() {
  return (
    <Suspense fallback={<Fallback />}>
      <ResetForm />
    </Suspense>
  );
}

function Fallback() {
  return (
    <Card>
      <CardContent className="pt-6">
        <p className="text-sm text-muted-foreground">Chargement…</p>
      </CardContent>
    </Card>
  );
}

function ResetForm() {
  const router = useRouter();
  const params = useSearchParams();
  const token = params.get('token') ?? '';

  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError('8 caractères minimum.');
      return;
    }
    if (password !== confirm) {
      setError('Les deux mots de passe doivent être identiques.');
      return;
    }
    setSubmitting(true);
    try {
      await resetPassword(token, password);
      // Sessions révoquées côté serveur → on renvoie sur sign-in
      // pour reconnexion propre.
      router.push('/sign-in?reset=success');
    } catch (err) {
      setError(err instanceof WebAuthError ? err.message : 'Reset impossible.');
    } finally {
      setSubmitting(false);
    }
  }

  if (!token) {
    return (
      <Card>
        <CardContent className="pt-6 space-y-4 text-center">
          <h1 className="font-display text-2xl">Lien invalide</h1>
          <p className="text-sm text-muted-foreground">
            Ce lien n'est pas valide. Demande un nouveau lien depuis l'écran de connexion.
          </p>
          <p className="text-sm text-muted-foreground">
            <Link href="/forgot-password" className="text-piloo-primary underline">
              Demander un nouveau lien
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
          <h1 className="font-display text-2xl">Nouveau mot de passe</h1>
          <p className="text-sm text-muted-foreground">
            Choisis un mot de passe d'au moins 8 caractères. Tes sessions actives seront
            déconnectées par sécurité.
          </p>
        </header>

        <form
          className="space-y-4"
          onSubmit={(e) => {
            void onSubmit(e);
          }}
        >
          <div className="space-y-2">
            <Label htmlFor="password">Nouveau mot de passe</Label>
            <Input
              id="password"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
              }}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="confirm">Confirmer</Label>
            <Input
              id="confirm"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => {
                setConfirm(e.target.value);
              }}
            />
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Enregistrement…' : 'Choisir ce mot de passe'}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
