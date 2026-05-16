// Homepage de démonstration — confirme que la stack Tailwind + shadcn
// + tokens Piloo (#56) fonctionne avant de l'utiliser sur les vrais
// écrans (auth, dashboard, etc.).
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';

export default function HomePage() {
  return (
    <main className="container mx-auto max-w-3xl py-12 px-4">
      <h1 className="font-display text-4xl text-foreground mb-2">Piloo</h1>
      <p className="text-muted-foreground mb-8">
        Carnet numérique de médicaments. Cette page sert pour l&apos;instant de vitrine technique du
        design system (#56).
      </p>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Stack web</CardTitle>
            <CardDescription>Tailwind 3 · shadcn · tokens Piloo</CardDescription>
          </CardHeader>
          <CardContent className="text-sm">
            Les composants <code>Button</code> et <code>Card</code> sont câblés sur les CSS vars{' '}
            <code>--piloo-color-*</code>. Pas de hex en dur dans les composants.
          </CardContent>
          <CardFooter className="gap-2">
            <Button>Primary</Button>
            <Button variant="outline">Outline</Button>
          </CardFooter>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-piloo-accent">Couleurs marque</CardTitle>
            <CardDescription>Sage + terracotta = Piloo</CardDescription>
          </CardHeader>
          <CardContent className="space-y-2">
            <div className="flex gap-2 items-center text-sm">
              <span className="h-5 w-5 rounded bg-piloo-primary" />
              primary
            </div>
            <div className="flex gap-2 items-center text-sm">
              <span className="h-5 w-5 rounded bg-piloo-accent" />
              accent
            </div>
            <div className="flex gap-2 items-center text-sm">
              <span className="h-5 w-5 rounded bg-piloo-surface-subtle border" />
              surface subtle
            </div>
          </CardContent>
          <CardFooter>
            <Button variant="secondary" size="sm">
              Voir la doc
            </Button>
          </CardFooter>
        </Card>
      </div>

      <p className="text-xs text-muted-foreground mt-8">
        Routes utiles :{' '}
        <a className="underline" href="/api/health">
          /api/health
        </a>{' '}
        ·{' '}
        <a className="underline" href="/legal/cgu">
          /legal/cgu
        </a>{' '}
        ·{' '}
        <a className="underline" href="/legal/privacy">
          /legal/privacy
        </a>
      </p>
    </main>
  );
}
