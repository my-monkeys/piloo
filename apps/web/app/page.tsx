// Landing publique piloo.vercel.app/ (#168).
//
// Vitrine pour les visiteurs anonymes. Hero, features, positionnement,
// CTA inscription. Server Component statique — pas de fetch, pas de
// state.
import Link from 'next/link';

import { Button } from '@/components/ui/button';

export const dynamic = 'force-static';

export default function HomePage() {
  return (
    <main className="min-h-screen bg-piloo-background">
      <NavBar />
      <Hero />
      <Features />
      <Positioning />
      <Cta />
      <Footer />
    </main>
  );
}

function NavBar() {
  return (
    <header className="border-b border-border bg-piloo-surface">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link href="/" className="font-display text-2xl">
          <span className="text-piloo-primary">pil</span>
          <span className="text-piloo-accent">oo</span>
        </Link>
        <nav className="flex items-center gap-3">
          <Link
            href="/status"
            className="hidden text-sm text-muted-foreground hover:text-foreground sm:inline"
          >
            Status
          </Link>
          <Button asChild size="sm" variant="outline">
            <Link href="/sign-in">Se connecter</Link>
          </Button>
          <Button asChild size="sm">
            <Link href="/sign-up">Créer un compte</Link>
          </Button>
        </nav>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section className="mx-auto max-w-4xl px-6 py-20 text-center">
      <p className="mb-3 text-sm font-medium uppercase tracking-wide text-piloo-accent">
        Carnet numérique de médicaments
      </p>
      <h1 className="font-display text-5xl leading-tight sm:text-6xl">
        Tes médicaments, <span className="text-piloo-primary">au calme</span>.
      </h1>
      <p className="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground">
        Scanne tes boîtes, suis tes prises, partage le suivi avec un proche. Sans pub, sans
        tracking, sans recommandation clinique automatique — juste un meilleur cahier.
      </p>
      <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
        <Button asChild size="lg">
          <Link href="/sign-up">Essayer Piloo</Link>
        </Button>
        <Button asChild size="lg" variant="outline">
          <Link href="/legal/privacy">Lire la politique de confidentialité</Link>
        </Button>
      </div>
      <p className="mt-4 text-xs text-muted-foreground">
        iOS · Android · Web · 100% gratuit pendant le bêta
      </p>
    </section>
  );
}

function Features() {
  const items: { title: string; body: string }[] = [
    {
      title: 'Scan DataMatrix',
      body: "Pointe l'appareil photo sur le code de la boîte — on reconnaît le médicament dans la base BDPM officielle et on enregistre la péremption pour toi.",
    },
    {
      title: "Timeline d'aujourd'hui",
      body: 'Tu vois tes prises du jour groupées par moment (matin / midi / soir / coucher). Un tap valide. Notifications locales pour ne plus oublier.',
    },
    {
      title: 'Carnet partagé',
      body: "Invite un proche pour qu'il puisse aider à gérer (rôle éditeur) ou juste consulter (rôle lecteur). Idéal pour suivre tes parents.",
    },
    {
      title: 'OCR ordonnance',
      body: 'Prends en photo une ordonnance papier, on extrait les médicaments et la posologie. Tu valides chaque ligne — pas de magie noire.',
    },
    {
      title: "Hors-ligne d'abord",
      body: "Tu ajoutes une boîte en pharmacie sans réseau ? La sync se fait en arrière-plan dès que la connexion revient. Pas d'écran d'erreur.",
    },
    {
      title: 'BDPM officielle',
      body: "Base de Données Publique des Médicaments mise à jour 2× par jour. 20 000+ médicaments avec dosage, forme, voie d'administration, remboursement.",
    },
  ];
  return (
    <section className="bg-piloo-surface py-20">
      <div className="mx-auto max-w-6xl px-6">
        <header className="mb-12 max-w-2xl">
          <h2 className="font-display text-3xl">Ce que Piloo fait pour toi</h2>
          <p className="mt-2 text-muted-foreground">
            Les essentiels d&apos;un carnet de suivi, en mieux foutu et plus rapide qu&apos;un
            Excel.
          </p>
        </header>
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((it) => (
            <div key={it.title} className="rounded-lg border border-border bg-piloo-background p-6">
              <h3 className="mb-2 font-display text-xl">{it.title}</h3>
              <p className="text-sm text-muted-foreground">{it.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Positioning() {
  return (
    <section className="mx-auto max-w-4xl px-6 py-20">
      <h2 className="mb-6 font-display text-3xl">Ce que Piloo n&apos;est pas</h2>
      <ul className="space-y-3 text-muted-foreground">
        <li>
          <strong className="text-foreground">Pas un dispositif médical</strong> au sens du
          règlement MDR — pas de validation d&apos;ordonnance, pas d&apos;alerte d&apos;interaction
          médicamenteuse, pas de recommandation clinique.
        </li>
        <li>
          <strong className="text-foreground">Pas un substitut</strong> à ton ordonnance officielle
          ou à l&apos;avis de ton médecin / pharmacien.
        </li>
        <li>
          <strong className="text-foreground">Pas une mine de données</strong> pour la publicité ou
          la recherche commerciale. Aucun tracker tiers, aucun partage avec un labo, aucune
          monétisation des données médicales.
        </li>
      </ul>
      <div className="mt-8 rounded-lg border border-piloo-accent bg-piloo-accent-soft p-6 text-sm">
        <p className="font-medium text-piloo-accent">C&apos;est un aide-mémoire personnel.</p>
        <p className="mt-2 text-piloo-accent">
          Le meilleur cahier que tu pourrais avoir, à la place du papier dans le tiroir de la
          cuisine.
        </p>
      </div>
    </section>
  );
}

function Cta() {
  return (
    <section className="border-t border-border bg-piloo-primary-soft py-16">
      <div className="mx-auto max-w-3xl px-6 text-center">
        <h2 className="font-display text-3xl">Prêt à essayer ?</h2>
        <p className="mt-3 text-muted-foreground">
          Création de compte en 30 secondes. Aucune carte bancaire demandée.
        </p>
        <div className="mt-6 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <Button asChild size="lg">
            <Link href="/sign-up">Créer mon compte</Link>
          </Button>
          <Button asChild size="lg" variant="outline">
            <Link href="/sign-in">J&apos;ai déjà un compte</Link>
          </Button>
        </div>
      </div>
    </section>
  );
}

function Footer() {
  const year = new Date().getFullYear();
  return (
    <footer className="border-t border-border bg-piloo-surface">
      <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-4 px-6 py-8 sm:flex-row sm:items-center">
        <p className="text-sm text-muted-foreground">
          © {year} Piloo. Carnet médicaments — pas un dispositif médical.
        </p>
        <nav className="flex flex-wrap gap-4 text-sm text-muted-foreground">
          <Link href="/legal/mentions" className="hover:text-foreground">
            Mentions légales
          </Link>
          <Link href="/legal/privacy" className="hover:text-foreground">
            Confidentialité
          </Link>
          <Link href="/legal/cgu" className="hover:text-foreground">
            CGU
          </Link>
          <Link href="/legal/cookies" className="hover:text-foreground">
            Cookies
          </Link>
          <Link href="/status" className="hover:text-foreground">
            Status
          </Link>
        </nav>
      </div>
    </footer>
  );
}
