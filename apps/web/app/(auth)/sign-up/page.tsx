// Page sign-up web (#169). Mirror du flow mobile : email/password + nom,
// prénom, type de compte (perso/pro). Apple/Google bypassent ces champs
// — leur mapProfileToUser côté serveur les remplit (cf. social-config.ts).
//
// Pour le MVP : seul flow email exposé. Les boutons Apple/Google
// renvoient vers la même action que sign-in (pas de distinction
// sign-in/sign-up côté OAuth — c'est l'IdP qui gère).
'use client';

import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useState } from 'react';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { signInWithGoogleRedirect, signUpEmail, WebAuthError } from '@/lib/auth/client';

export default function SignUpPage() {
  const router = useRouter();
  const [prenom, setPrenom] = useState('');
  const [nom, setNom] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [typeCompte, setTypeCompte] = useState<'particulier' | 'pro'>('particulier');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: React.SyntheticEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const trimmedEmail = email.trim();
      await signUpEmail({
        email: trimmedEmail,
        password,
        name: `${prenom.trim()} ${nom.trim()}`.trim(),
        nom: nom.trim(),
        prenom: prenom.trim(),
        typeCompte,
      });
      // #62 — selon la config serveur (requireEmailVerification), Better Auth
      // a soit posé une session direct (verif off), soit envoyé un magic link.
      // On vérifie get-session pour router en conséquence : /dashboard si la
      // session existe, sinon /check-inbox pour attendre la vérification.
      const session = await fetch('/api/auth/get-session', { credentials: 'same-origin' })
        .then((r) => (r.ok ? (r.json() as Promise<{ user?: unknown } | null>) : null))
        .catch(() => null);
      if (session?.user) {
        router.push('/dashboard');
      } else {
        router.push(`/check-inbox?email=${encodeURIComponent(trimmedEmail)}`);
      }
      router.refresh();
    } catch (err) {
      setError(err instanceof WebAuthError ? err.message : 'Inscription impossible.');
    } finally {
      setSubmitting(false);
    }
  }

  async function onGoogle() {
    setError(null);
    setSubmitting(true);
    try {
      const url = await signInWithGoogleRedirect('/dashboard');
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
          <h1 className="font-display text-2xl">Créer un compte</h1>
          <p className="text-sm text-muted-foreground">Ton carnet de médicaments, à toi.</p>
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
            void onSubmit(e);
          }}
        >
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label htmlFor="prenom">Prénom</Label>
              <Input
                id="prenom"
                required
                autoComplete="given-name"
                value={prenom}
                onChange={(e) => {
                  setPrenom(e.target.value);
                }}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="nom">Nom</Label>
              <Input
                id="nom"
                required
                autoComplete="family-name"
                value={nom}
                onChange={(e) => {
                  setNom(e.target.value);
                }}
              />
            </div>
          </div>
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
              minLength={8}
              autoComplete="new-password"
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
              }}
            />
            <p className="text-xs text-muted-foreground">8 caractères minimum.</p>
          </div>
          <div className="space-y-2">
            <Label>Type de compte</Label>
            <div className="flex gap-2">
              <Button
                type="button"
                variant={typeCompte === 'particulier' ? 'default' : 'outline'}
                size="sm"
                onClick={() => {
                  setTypeCompte('particulier');
                }}
              >
                Particulier
              </Button>
              <Button
                type="button"
                variant={typeCompte === 'pro' ? 'default' : 'outline'}
                size="sm"
                onClick={() => {
                  setTypeCompte('pro');
                }}
              >
                Pro de santé
              </Button>
            </div>
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <Button type="submit" className="w-full" disabled={submitting}>
            {submitting ? 'Création…' : 'Créer mon compte'}
          </Button>
        </form>

        <p className="text-sm text-center text-muted-foreground">
          Déjà un compte ?{' '}
          <Link href="/sign-in" className="text-piloo-primary underline">
            Se connecter
          </Link>
        </p>
      </CardContent>
    </Card>
  );
}
