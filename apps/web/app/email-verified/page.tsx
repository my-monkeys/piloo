// Page d'atterrissage après vérification email (#62).
//
// Cible du callbackURL du magic link Better Auth. À ce stade, BA a déjà
// activé `users.emailVerified` et créé une session (autoSignInAfterVerification).
// On affiche juste la confirmation et un CTA vers le dashboard.
import Link from 'next/link';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

export default function EmailVerifiedPage() {
  return (
    <main className="min-h-dvh flex items-center justify-center bg-piloo-bg px-4 py-12">
      <Card className="max-w-md w-full">
        <CardContent className="pt-6 space-y-4 text-center">
          <h1 className="font-display text-2xl">Email confirmé</h1>
          <p className="text-sm text-muted-foreground">
            Votre adresse est vérifiée. Vous êtes connecté(e) — votre carnet est prêt.
          </p>
          <Button asChild className="w-full">
            <Link href="/dashboard">Accéder à mon carnet</Link>
          </Button>
        </CardContent>
      </Card>
    </main>
  );
}
