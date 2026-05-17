// Page sign-in web (#169). Email/password + bouton Google (web flow).
//
// Apple web sign-in nécessite un Services ID Apple distinct du Bundle ID
// iOS (Apple Developer Console). Pas configuré pour l'instant — bouton
// désactivé avec note explicative. La connexion Apple existe déjà côté
// mobile (#64) via le flow id-token natif iOS.
'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Suspense, useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { signInEmail, signInWithGoogleRedirect, WebAuthError } from '@/lib/auth/client';

export default function SignInPage() {
  // useSearchParams() exige un Suspense boundary en App Router pour
  // permettre le prerender statique du shell sans bloquer sur les query
  // params (cf. Next.js missing-suspense-with-csr-bailout).
  return (
    <Suspense fallback={<SignInFallback />}>
      <SignInForm />
    </Suspense>
  );
}

function SignInFallback() {
  return (
    <Card>
      <CardContent className="pt-6">
        <p className="text-sm text-muted-foreground">Chargement…</p>
      </CardContent>
    </Card>
  );
}

/**
 * Whitelist : on n'accepte que les chemins internes (`/foo/bar`) — pas
 * les schemas absolus (`https://...`), pas le `//` protocol-relative,
 * pas `/\` (Edge antique). Évite l'open redirect via `?redirect=...`.
 */
function safeRedirect(raw: string | null): string {
  const fallback = '/dashboard';
  if (!raw) return fallback;
  // Refuse tout ce qui pourrait être interprété comme une autre origin.
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.startsWith('/\\')) {
    return fallback;
  }
  return raw;
}

function SignInForm() {
  const router = useRouter();
  const params = useSearchParams();
  const redirectTo = safeRedirect(params.get('redirect'));

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onEmailSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await signInEmail(email.trim(), password);
      router.push(redirectTo);
      router.refresh();
    } catch (err) {
      if (err instanceof WebAuthError) {
        setError(err.message);
      } else {
        setError('Connexion impossible.');
      }
    } finally {
      setSubmitting(false);
    }
  }

  async function onGoogle() {
    setError(null);
    setSubmitting(true);
    try {
      const url = await signInWithGoogleRedirect(redirectTo);
      window.location.assign(url);
    } catch (err) {
      setError(err instanceof WebAuthError ? err.message : 'Erreur Google.');
      setSubmitting(false);
    }
  }

  return (
    <Card>
      <CardContent className="pt-6 space-y-4">
        <header className="space-y-1">
          <h1 className="font-display text-2xl">Bon retour</h1>
          <p className="text-sm text-muted-foreground">
            Connecte-toi pour accéder à tes officines.
          </p>
        </header>

        <Button
          type="button"
          variant="outline"
          className="w-full"
          onClick={() => {
            void onGoogle();
          }}
          disabled={submitting}
        >
          Continuer avec Google
        </Button>
        <Button
          type="button"
          variant="outline"
          className="w-full"
          disabled
          title="iOS uniquement pour l'instant"
        >
          Continuer avec Apple
        </Button>

        <div className="relative my-2">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-border" />
          </div>
          <div className="relative flex justify-center text-xs uppercase">
            <span className="bg-card px-2 text-muted-foreground">ou</span>
          </div>
        </div>

        <form
          className="space-y-4"
          onSubmit={(e) => {
            void onEmailSubmit(e);
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
          <div className="space-y-2">
            <Label htmlFor="password">Mot de passe</Label>
            <Input
              id="password"
              type="password"
              required
              autoComplete="current-password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
              }}
            />
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Connexion…' : 'Se connecter'}
          </Button>
        </form>

        <p className="text-sm text-center text-muted-foreground">
          Pas encore de compte ?{' '}
          <Link href="/sign-up" className="text-piloo-primary underline">
            S&apos;inscrire
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
