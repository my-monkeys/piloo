// Dashboard d'accueil après login (#170). Vue à 3 widgets utilisant
// l'officine active sélectionnée dans la sidebar (#73) :
//
//   1. Prochaines prises (timeline du jour)
//   2. Alertes non lues
//   3. Stock — boîtes périmées/vides/actives à un coup d'œil
//
// Responsive : grid 1 colonne mobile → 2 colonnes md → 3 colonnes lg
// (chaque widget est une Card autonome qui s'adapte).
//
// Empty states : si pas d'officine active, on prompt l'utilisateur à
// en activer une depuis la sidebar.
'use client';

import { $api } from '@piloo/api-client';
import Link from 'next/link';

import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useActiveOfficine } from '@/lib/officines/active-officine';

export default function DashboardPage() {
  const { activeOfficineId } = useActiveOfficine();

  return (
    <div className="space-y-6">
      <header>
        <h1 className="font-display text-3xl">Tableau de bord</h1>
        <p className="text-muted-foreground">Vue d&apos;ensemble du jour.</p>
      </header>

      {!activeOfficineId && <NoActiveOfficineEmpty />}

      {activeOfficineId && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          <UpcomingPrisesWidget officineId={activeOfficineId} />
          <UnreadAlertesWidget />
          <BoitesStockWidget officineId={activeOfficineId} />
        </div>
      )}
    </div>
  );
}

function NoActiveOfficineEmpty() {
  return (
    <Card>
      <CardContent className="pt-6 text-sm text-muted-foreground">
        Active une officine depuis la sidebar pour voir tes prises du jour, tes alertes et
        l&apos;état du stock. Si tu n&apos;en as pas encore créé,{' '}
        <Link href="/settings/officines" className="underline text-foreground">
          rends-toi sur Settings
        </Link>
        .
      </CardContent>
    </Card>
  );
}

function UpcomingPrisesWidget({ officineId }: { officineId: string }) {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/prises/today', {
    params: { query: { officine_id: officineId } },
  });

  const upcoming = data?.items.filter((p) => p.statut === 'prevue').slice(0, 5) ?? [];
  const oubliees = data?.items.filter((p) => p.statut === 'oubliee') ?? [];

  return (
    <Card>
      <CardHeader>
        <CardTitle>Prochaines prises</CardTitle>
        <CardDescription>Aujourd&apos;hui</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {isLoading && <SkeletonLine />}
        {error && <ErrorLine />}
        {data && oubliees.length > 0 && (
          <p className="text-sm text-piloo-warning-on font-medium">
            ⚠ {oubliees.length} prise{oubliees.length > 1 ? 's' : ''} oubliée
            {oubliees.length > 1 ? 's' : ''}
          </p>
        )}
        {data && upcoming.length === 0 && oubliees.length === 0 && (
          <p className="text-sm text-muted-foreground">Aucune prise prévue aujourd&apos;hui.</p>
        )}
        {upcoming.length > 0 && (
          <ul className="space-y-1.5 text-sm">
            {upcoming.map((p) => (
              <li key={p.id} className="flex justify-between gap-2">
                <span className="truncate">{p.prescription.nom_texte}</span>
                <span className="text-muted-foreground tabular-nums">
                  {formatTime(p.datetime_prevue)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

function UnreadAlertesWidget() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/alertes', {
    params: { query: { unread_only: 'true', limit: 5 } },
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle>Alertes</CardTitle>
        <CardDescription>
          {data
            ? `${String(data.items.length)} non lue${data.items.length > 1 ? 's' : ''}`
            : 'Non lues'}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {isLoading && <SkeletonLine />}
        {error && <ErrorLine />}
        {data?.items.length === 0 && (
          <p className="text-sm text-muted-foreground">Rien à signaler.</p>
        )}
        {data && data.items.length > 0 && (
          <ul className="space-y-1.5 text-sm">
            {data.items.map((a) => (
              <li key={a.id} className="flex justify-between gap-2">
                <span className="truncate">{labelForAlerte(a.type)}</span>
                <span className="text-muted-foreground text-xs">
                  {formatRelative(a.created_at)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

function BoitesStockWidget({ officineId }: { officineId: string }) {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId } },
  });

  const counts = {
    active: data?.items.filter((b) => b.statut === 'active').length ?? 0,
    perimee: data?.items.filter((b) => b.statut === 'perimee').length ?? 0,
    vide: data?.items.filter((b) => b.statut === 'vide').length ?? 0,
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Stock</CardTitle>
        <CardDescription>État des boîtes</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {isLoading && <SkeletonLine />}
        {error && <ErrorLine />}
        {data && (
          <div className="space-y-1.5 text-sm">
            <StockRow label="Actives" count={counts.active} color="text-piloo-success-on" />
            <StockRow label="Périmées" count={counts.perimee} color="text-piloo-error-on" />
            <StockRow label="Vides" count={counts.vide} color="text-muted-foreground" />
            <div className="pt-2">
              <Button asChild variant="outline" size="sm" className="w-full">
                <Link href="/settings/officines">Gérer le stock</Link>
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function StockRow({ label, count, color }: { label: string; count: number; color: string }) {
  return (
    <div className="flex justify-between">
      <span>{label}</span>
      <span className={`tabular-nums font-medium ${color}`}>{count}</span>
    </div>
  );
}

function SkeletonLine() {
  return <div className="h-4 w-full bg-muted rounded animate-pulse" />;
}

function ErrorLine() {
  return <p className="text-sm text-muted-foreground">Impossible de charger (non connecté ?)</p>;
}

function formatTime(iso: string): string {
  // Affichage HH:mm en heure locale.
  const d = new Date(iso);
  return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function formatRelative(iso: string): string {
  // "il y a Xh" / "hier" — affichage compact pour les widgets.
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.round(diffMs / 60_000);
  if (minutes < 1) return "à l'instant";
  if (minutes < 60) return `${String(minutes)}m`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${String(hours)}h`;
  const days = Math.round(hours / 24);
  if (days < 7) return `${String(days)}j`;
  return new Date(iso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
}

function labelForAlerte(type: string): string {
  const map: Record<string, string> = {
    peremption_30j: 'Péremption < 30j',
    peremption_7j: 'Péremption < 7j',
    stock_bas: 'Stock bas',
    prise_oubliee: 'Prise oubliée',
    manque_signale: 'Manque signalé',
  };
  return map[type] ?? type;
}
