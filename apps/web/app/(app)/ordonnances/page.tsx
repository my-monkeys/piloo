// Page Ordonnances — liste des ordonnances de l'officine active.
//
// Frontend de #106. Affiche un tableau trié par date_prescription
// décroissante, avec le nombre de prescriptions par ligne (chargement
// paresseux si besoin — pour l'instant on affiche juste les méta).
// Lien vers le détail `/ordonnances/[id]`.
'use client';

import { $api } from '@piloo/api-client';
import Link from 'next/link';

import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { useActiveOfficine } from '@/lib/officines/active-officine';

export default function OrdonnancesPage() {
  const { activeOfficineId } = useActiveOfficine();

  if (!activeOfficineId) {
    return (
      <EmptyState
        title="Aucune officine sélectionnée"
        description="Sélectionne une officine dans les réglages pour voir ses ordonnances."
        action={
          <Link href="/settings/officines">
            <Button>Gérer les officines</Button>
          </Link>
        }
      />
    );
  }

  return <OrdonnancesList officineId={activeOfficineId} />;
}

function OrdonnancesList({ officineId }: { officineId: string }) {
  const { data, isLoading, error } = $api.useQuery(
    'get',
    '/v1/officines/{officineId}/ordonnances',
    { params: { path: { officineId } } },
  );

  if (isLoading) {
    return <p className="text-muted-foreground">Chargement…</p>;
  }
  if (error) {
    return (
      <p className="text-destructive">Impossible de charger les ordonnances. Réessaie plus tard.</p>
    );
  }

  const items = data?.items ?? [];

  return (
    <div className="space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-3xl">Ordonnances</h1>
          <p className="text-muted-foreground">
            Historique des ordonnances saisies pour cette officine.
          </p>
        </div>
      </header>

      {items.length === 0 ? (
        <EmptyState
          title="Aucune ordonnance"
          description="Les ordonnances que tu saisis apparaîtront ici."
        />
      ) : (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Prescripteur</TableHead>
                  <TableHead>Source</TableHead>
                  <TableHead className="text-right">Notes</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((ord) => (
                  <TableRow key={ord.id}>
                    <TableCell className="font-medium">
                      <Link
                        href={`/ordonnances/${ord.id}`}
                        className="text-piloo-primary hover:underline"
                      >
                        {formatDate(ord.date_prescription)}
                      </Link>
                    </TableCell>
                    <TableCell>{ord.prescripteur ?? '—'}</TableCell>
                    <TableCell>
                      <span className="text-xs uppercase tracking-wide text-muted-foreground">
                        {ord.source}
                      </span>
                    </TableCell>
                    <TableCell className="text-right text-sm text-muted-foreground max-w-xs truncate">
                      {ord.notes ?? '—'}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="rounded-lg border border-dashed border-border p-12 text-center">
      <h2 className="font-display text-xl">{title}</h2>
      <p className="text-muted-foreground mt-2">{description}</p>
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}
