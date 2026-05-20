// Vue pro web : dashboard multi-patients (#150).
//
// Affiche TOUTES les officines accessibles (perso + partagées + pro)
// avec un widget "tournée du jour" par officine : prises restantes
// aujourd'hui + ratio prises validées.
//
// Scope MVP : pas d'observance historique (#150 AC "indicateurs
// observance" — graphique 7j/30j à venir, demande des stats DB qui
// n'existent pas encore côté serveur).
//
// Tap sur une card → switch active + redirige vers /dashboard pour
// la vue détaillée.
'use client';

import { $api } from '@piloo/api-client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

export default function ProPatientsPage() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-3xl">Mes patients</h1>
        <p className="text-muted-foreground">
          Vue d&apos;ensemble de toutes les officines auxquelles tu as accès.
        </p>
      </header>

      {isLoading && <p className="text-sm text-muted-foreground">Chargement…</p>}
      {error && (
        <p className="text-sm text-piloo-error">Impossible de charger la liste des officines.</p>
      )}
      {data?.items.length === 0 && (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Aucune officine n&apos;est encore liée à ton compte. Demande à un proche de te partager
            la sienne, ou crée la tienne depuis{' '}
            <Link href="/settings/officines" className="underline">
              Réglages → Officines
            </Link>
            .
          </CardContent>
        </Card>
      )}
      {data?.items.length && data.items.length > 0 ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {data.items.map((o) => (
            <OfficineCard key={o.id} id={o.id} nom={o.nom} role={o.role} type={o.type} />
          ))}
        </div>
      ) : null}
    </div>
  );
}

interface OfficineCardProps {
  id: string;
  nom: string;
  role: string;
  type: string;
}

function OfficineCard({ id, nom, role, type }: OfficineCardProps) {
  const router = useRouter();
  const { setActive } = useActiveOfficine();
  const prisesQ = $api.useQuery('get', '/v1/prises/today', {
    params: { query: { officine_id: id } },
  });
  const boitesQ = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId: id } },
  });

  const prises = prisesQ.data?.items ?? [];
  const prisesTotal = prises.length;
  const prisesDone = prises.filter((p) => p.statut === 'prise' || p.statut === 'sautee').length;
  const prisesRemaining = prises.filter((p) => p.statut === 'prevue').length;
  const prisesMissed = prises.filter((p) => p.statut === 'oubliee').length;
  const observancePct = prisesTotal > 0 ? Math.round((prisesDone / prisesTotal) * 100) : null;

  const boitesTotal = boitesQ.data?.items.length ?? 0;
  const boitesPerimees = boitesQ.data?.items.filter((b) => b.statut === 'perimee').length ?? 0;

  function openOfficine() {
    setActive(id);
    router.push('/dashboard');
  }

  return (
    <Card
      className="cursor-pointer transition-colors hover:bg-piloo-primary-soft/30"
      onClick={openOfficine}
    >
      <CardHeader>
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="font-display text-xl truncate">{nom}</CardTitle>
          <RoleBadge role={role} />
        </div>
        <CardDescription>{labelForType(type)}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3 text-sm">
        <Row
          label="Boîtes"
          value={
            boitesPerimees > 0
              ? `${String(boitesTotal)} (${String(boitesPerimees)} périmée${boitesPerimees > 1 ? 's' : ''})`
              : String(boitesTotal)
          }
        />
        <Row
          label="Prises aujourd'hui"
          value={
            prisesTotal === 0
              ? 'Aucune planifiée'
              : prisesRemaining > 0
                ? `${String(prisesDone)}/${String(prisesTotal)} validées · ${String(prisesRemaining)} restantes`
                : `${String(prisesDone)}/${String(prisesTotal)} validées`
          }
        />
        {prisesMissed > 0 && (
          <Row
            label="Oubliées"
            value={String(prisesMissed)}
            valueClassName="text-piloo-warning-on font-semibold"
          />
        )}
        {observancePct !== null && (
          <Row
            label="Observance jour"
            value={`${String(observancePct)}%`}
            valueClassName={cn(
              'font-semibold',
              observancePct >= 80
                ? 'text-piloo-success-on'
                : observancePct >= 50
                  ? 'text-piloo-warning-on'
                  : 'text-piloo-error-on',
            )}
          />
        )}
      </CardContent>
    </Card>
  );
}

function Row({
  label,
  value,
  valueClassName,
}: {
  label: string;
  value: string;
  valueClassName?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <span className="text-muted-foreground">{label}</span>
      <span className={cn('truncate text-right', valueClassName)}>{value}</span>
    </div>
  );
}

function RoleBadge({ role }: { role: string }) {
  const cfg =
    role === 'owner'
      ? { label: 'Propriétaire', cls: 'bg-piloo-primary-soft text-piloo-primary' }
      : role === 'editor'
        ? { label: 'Éditeur', cls: 'bg-piloo-info text-piloo-info-on' }
        : { label: 'Lecteur', cls: 'bg-muted text-muted-foreground' };
  return (
    <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', cfg.cls)}>{cfg.label}</span>
  );
}

function labelForType(type: string): string {
  switch (type) {
    case 'perso':
      return 'Officine personnelle';
    case 'patient':
      return 'Patient suivi';
    default:
      return type;
  }
}
