// Page Pricing publique (#154, M3+).
//
// 3 plans : Gratuit (M1 actuel), Famille (partage + alertes), Pro
// (multi-patients + résumés IA). Static, pas de fetch — la page liste
// la promesse produit, le CTA upgrade va dans /settings/billing
// quand on aura branché Stripe / RevenueCat (hors scope ici).
//
// Note non-MDR : aucun plan ne débloque de "conseil clinique" — Piloo
// reste un carnet d'aide-mémoire personnel à tous les niveaux.
import Link from 'next/link';

import { Button } from '@/components/ui/button';

export const dynamic = 'force-static';

interface Plan {
  id: 'gratuit' | 'famille' | 'pro';
  nom: string;
  badge?: string;
  prix: { mensuel: string; annuel: string | null };
  pitch: string;
  features: string[];
  cta: { label: string; href: string };
  highlighted?: boolean;
}

const PLANS: Plan[] = [
  {
    id: 'gratuit',
    nom: 'Gratuit',
    prix: { mensuel: '0 €', annuel: null },
    pitch: 'Pour démarrer un carnet perso solo.',
    features: [
      '1 officine personnelle',
      'Inventaire des boîtes (scan ou saisie)',
      'Timeline de prises + rappels locaux',
      'Résumés IA des médicaments (BDPM)',
      'Stockage local + sync sur ton compte',
    ],
    cta: { label: 'Créer un compte', href: '/sign-up' },
  },
  {
    id: 'famille',
    nom: 'Famille',
    badge: 'Bientôt',
    prix: { mensuel: '4,99 €', annuel: '49 €/an' },
    pitch: 'Partage avec tes proches, alertes push & email.',
    features: [
      'Tout le plan Gratuit, plus :',
      "Jusqu'à 5 officines partagées",
      'Invitations avec rôles (Éditeur, Lecteur)',
      'Notifications push pour rappels manqués',
      'Alertes email + SMS critiques (stock bas, péremption)',
      'Historique illimité',
    ],
    cta: {
      label: "Rejoindre la liste d'attente",
      href: 'mailto:hello@piloo.fr?subject=Plan%20Famille',
    },
    highlighted: true,
  },
  {
    id: 'pro',
    nom: 'Pro de santé',
    badge: 'Bientôt',
    prix: { mensuel: '19 €', annuel: '190 €/an' },
    pitch: 'Pour IDEL & aidants suivant plusieurs patients.',
    features: [
      'Tout le plan Famille, plus :',
      'Officines patients en nombre illimité',
      'Vue agrégée multi-patients',
      'Export RGPD par patient (PDF + JSON)',
      'OCR ordonnance → pré-remplissage prescriptions',
      'Support prioritaire (réponse < 24h)',
    ],
    cta: { label: 'Demander une démo', href: 'mailto:hello@piloo.fr?subject=Plan%20Pro' },
  },
];

export default function PricingPage() {
  return (
    <main className="min-h-screen bg-piloo-background">
      <NavBar />
      <Hero />
      <PlansGrid />
      <FaqSection />
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
          <Link href="/" className="text-sm text-muted-foreground hover:text-foreground">
            Accueil
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
    <section className="mx-auto max-w-3xl px-6 py-16 text-center">
      <p className="text-sm uppercase tracking-wider text-piloo-primary">Tarifs</p>
      <h1 className="mt-4 font-display text-4xl md:text-5xl">Un carnet, trois usages.</h1>
      <p className="mt-6 text-lg text-muted-foreground">
        Piloo est gratuit pour ton armoire à pharmacie personnelle. Quand tu commences à partager ou
        à suivre des patients, on propose des plans dédiés — pas de gating sur le suivi
        médicamenteux de base.
      </p>
    </section>
  );
}

function PlansGrid() {
  return (
    <section className="mx-auto max-w-6xl px-6 pb-16">
      <div className="grid gap-6 md:grid-cols-3">
        {PLANS.map((p) => (
          <PlanCard key={p.id} plan={p} />
        ))}
      </div>
      <p className="mt-8 text-center text-xs text-muted-foreground">
        Les plans Famille & Pro sont en preview — on ouvre la facturation après la beta. En
        attendant, l'inscription à la liste d'attente garantit le prix de lancement.
      </p>
    </section>
  );
}

function PlanCard({ plan }: { plan: Plan }) {
  return (
    <div
      className={`flex flex-col rounded-2xl border bg-piloo-surface p-6 ${
        plan.highlighted ? 'border-piloo-primary shadow-lg' : 'border-border'
      }`}
    >
      <div className="flex items-baseline justify-between">
        <h3 className="font-display text-2xl">{plan.nom}</h3>
        {plan.badge && (
          <span className="rounded-full bg-piloo-primary-soft px-2 py-0.5 text-xs font-medium text-piloo-primary">
            {plan.badge}
          </span>
        )}
      </div>
      <p className="mt-2 text-sm text-muted-foreground">{plan.pitch}</p>

      <div className="mt-4 flex items-baseline gap-2">
        <span className="font-display text-3xl">{plan.prix.mensuel}</span>
        {plan.prix.mensuel !== '0 €' && (
          <span className="text-sm text-muted-foreground">/ mois</span>
        )}
      </div>
      {plan.prix.annuel && <p className="text-xs text-muted-foreground">ou {plan.prix.annuel}</p>}

      <ul className="mt-6 space-y-2 text-sm">
        {plan.features.map((f) => (
          <li key={f} className="flex items-start gap-2">
            <span
              aria-hidden
              className="mt-1 inline-block size-1.5 shrink-0 rounded-full bg-piloo-primary"
            />
            <span>{f}</span>
          </li>
        ))}
      </ul>

      <div className="mt-6 grow" />
      <Button asChild className="w-full" variant={plan.highlighted ? 'default' : 'outline'}>
        <Link href={plan.cta.href}>{plan.cta.label}</Link>
      </Button>
    </div>
  );
}

function FaqSection() {
  const faqs = [
    {
      q: 'Mes données restent privées sur le plan Gratuit ?',
      a: 'Oui — les données médicamenteuses sont chiffrées en transit et stockées sur des serveurs européens. Aucun tracking tiers sur les écrans contenant des données de santé (cf. notre politique de confidentialité). Le statut HDS arrive avant la mise en prod commerciale.',
    },
    {
      q: 'Je peux upgrade / downgrade quand je veux ?',
      a: 'Oui, sans frais. Le passage à un plan supérieur prend effet immédiatement, le downgrade à la fin de la période facturée. Les données restent accessibles (les partages au-delà de la limite Gratuit sont juste mis en lecture seule).',
    },
    {
      q: 'Piloo remplace mon médecin ?',
      a: 'Non. Piloo est un aide-mémoire personnel — un meilleur cahier de prises. Aucun plan ne débloque de conseil clinique. Pour les interactions, posologies, contre-indications, parlez à votre médecin ou pharmacien.',
    },
    {
      q: "Le plan Pro de santé, c'est pour qui ?",
      a: 'Infirmier·e libéral·e, aidant familial qui suit plusieurs proches, pharmacien·ne avec une patientèle de suivi. Si vous êtes une structure (EHPAD, HAD), contactez-nous pour un devis adapté.',
    },
  ];
  return (
    <section className="mx-auto max-w-3xl px-6 pb-16">
      <h2 className="font-display text-3xl">Questions fréquentes</h2>
      <dl className="mt-6 space-y-6">
        {faqs.map((f) => (
          <div key={f.q}>
            <dt className="font-medium">{f.q}</dt>
            <dd className="mt-1 text-sm text-muted-foreground">{f.a}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-border bg-piloo-surface">
      <div className="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-8 text-sm text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
        <p>© 2026 Piloo · Aide-mémoire personnel, pas un dispositif médical.</p>
        <nav className="flex gap-4">
          <Link href="/legal/cgu" className="hover:text-foreground">
            CGU
          </Link>
          <Link href="/legal/privacy" className="hover:text-foreground">
            Confidentialité
          </Link>
          <Link href="/legal/mentions" className="hover:text-foreground">
            Mentions
          </Link>
        </nav>
      </div>
    </footer>
  );
}
