// Page inventaire desktop (#171). Vue table des boîtes de l'officine
// active avec tri colonne + recherche fuzzy + panneau slide pour le
// détail.
//
// Choix UX :
// - Tri par défaut : peremption ascendant (les bientôt-périmées
//   remontent → action prioritaire).
// - Recherche : match insensible à la casse sur cip13 ET notes. La
//   recherche par nom de médicament viendra quand on enrichira la
//   liste avec la BDPM côté client (suit #167).
// - Panneau slide : shadcn Sheet à droite, ouvert au click ligne.
//   `null` = fermé, `Boite` = boîte ouverte.
'use client';

import { $api, type components } from '@piloo/api-client';
import { useMemo, useState } from 'react';

import { AddBoiteDialog } from '@/components/app/inventory/add-boite-dialog';
import { BoiteDetailPanel } from '@/components/app/inventory/boite-detail-panel';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { useActiveOfficine } from '@/lib/officines/active-officine';
import { cn } from '@/lib/utils';

type Boite = components['schemas']['Boite'];

type SortColumn = 'peremption' | 'cip13' | 'stock' | 'statut';
type SortDirection = 'asc' | 'desc';

export default function InventoryPage() {
  const { activeOfficineId } = useActiveOfficine();
  const [query, setQuery] = useState('');
  const [sortBy, setSortBy] = useState<SortColumn>('peremption');
  const [sortDir, setSortDir] = useState<SortDirection>('asc');
  const [opened, setOpened] = useState<Boite | null>(null);

  return (
    <div className="space-y-6">
      <header className="flex items-start justify-between gap-4">
        <div>
          <h1 className="font-display text-3xl">Inventaire</h1>
          <p className="text-muted-foreground">
            Toutes les boîtes de l&apos;officine active. Tri colonne, recherche, détail à droite.
          </p>
        </div>
        {activeOfficineId && <AddBoiteDialog officineId={activeOfficineId} />}
      </header>

      {!activeOfficineId ? (
        <NoActiveOfficineEmpty />
      ) : (
        <InventoryTable
          officineId={activeOfficineId}
          query={query}
          sortBy={sortBy}
          sortDir={sortDir}
          onQueryChange={setQuery}
          onSortChange={(col) => {
            if (col === sortBy) {
              setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
            } else {
              setSortBy(col);
              setSortDir('asc');
            }
          }}
          onOpen={setOpened}
        />
      )}

      <Sheet
        open={opened !== null}
        onOpenChange={(o) => {
          if (!o) setOpened(null);
        }}
      >
        <SheetContent className="overflow-y-auto">
          {opened && (
            <>
              <SheetHeader>
                <SheetTitle>{opened.cip13}</SheetTitle>
                <SheetDescription>
                  Boîte ajoutée le {formatDate(opened.created_at)}
                </SheetDescription>
              </SheetHeader>
              <BoiteDetailPanel
                boite={opened}
                onClose={() => {
                  setOpened(null);
                }}
              />
            </>
          )}
        </SheetContent>
      </Sheet>
    </div>
  );
}

function InventoryTable({
  officineId,
  query,
  sortBy,
  sortDir,
  onQueryChange,
  onSortChange,
  onOpen,
}: {
  officineId: string;
  query: string;
  sortBy: SortColumn;
  sortDir: SortDirection;
  onQueryChange: (q: string) => void;
  onSortChange: (col: SortColumn) => void;
  onOpen: (b: Boite) => void;
}) {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines/{officineId}/boites', {
    params: { path: { officineId } },
  });

  const rows = useMemo(() => {
    if (!data) return [];
    // Boîtes vidées : on les retire de l'affichage — l'utilisateur les a
    // marquées épuisées, plus aucune action utile. Elles restent en DB
    // (historique, agrégat alerte stock_bas).
    const visible = data.items.filter((b) => b.statut !== 'vide' && (b.unites_restantes ?? 1) > 0);
    const q = query.trim().toLowerCase();
    const filtered = q
      ? visible.filter(
          (b) => b.cip13.toLowerCase().includes(q) || (b.notes?.toLowerCase().includes(q) ?? false),
        )
      : visible;
    const sorted = [...filtered].sort((a, b) => cmp(a, b, sortBy));
    return sortDir === 'asc' ? sorted : sorted.reverse();
  }, [data, query, sortBy, sortDir]);

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <Input
          placeholder="Rechercher (CIP13, notes)…"
          value={query}
          onChange={(e) => {
            onQueryChange(e.target.value);
          }}
          className="max-w-sm"
        />
        <p className="text-sm text-muted-foreground">
          {data ? `${String(rows.length)} / ${String(data.items.length)}` : ''}
        </p>
      </div>

      {isLoading && <p className="text-sm text-muted-foreground">Chargement…</p>}
      {error && (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Impossible de charger (non connecté ?).
          </CardContent>
        </Card>
      )}

      {data?.items.length === 0 && (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Aucune boîte enregistrée pour cette officine.
          </CardContent>
        </Card>
      )}

      {data?.items.length ? (
        <Card>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <SortableHeader
                    col="cip13"
                    sortBy={sortBy}
                    sortDir={sortDir}
                    onClick={onSortChange}
                  >
                    CIP13
                  </SortableHeader>
                  <SortableHeader
                    col="peremption"
                    sortBy={sortBy}
                    sortDir={sortDir}
                    onClick={onSortChange}
                  >
                    Péremption
                  </SortableHeader>
                  <SortableHeader
                    col="stock"
                    sortBy={sortBy}
                    sortDir={sortDir}
                    onClick={onSortChange}
                  >
                    Stock
                  </SortableHeader>
                  <SortableHeader
                    col="statut"
                    sortBy={sortBy}
                    sortDir={sortDir}
                    onClick={onSortChange}
                  >
                    Statut
                  </SortableHeader>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((b) => (
                  <TableRow
                    key={b.id}
                    onClick={() => {
                      onOpen(b);
                    }}
                  >
                    <TableCell className="font-mono text-xs">{b.cip13}</TableCell>
                    <TableCell>{formatDate(b.peremption)}</TableCell>
                    <TableCell className="tabular-nums">{b.unites_restantes ?? '—'}</TableCell>
                    <TableCell>
                      <StatutBadge statut={b.statut} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}

function SortableHeader({
  col,
  sortBy,
  sortDir,
  onClick,
  children,
}: {
  col: SortColumn;
  sortBy: SortColumn;
  sortDir: SortDirection;
  onClick: (c: SortColumn) => void;
  children: React.ReactNode;
}) {
  const active = sortBy === col;
  return (
    <TableHead>
      <button
        type="button"
        className={cn(
          'inline-flex items-center gap-1 hover:text-foreground transition-colors',
          active && 'text-foreground font-medium',
        )}
        onClick={() => {
          onClick(col);
        }}
      >
        {children}
        {active && <span className="text-xs">{sortDir === 'asc' ? '↑' : '↓'}</span>}
      </button>
    </TableHead>
  );
}

function StatutBadge({ statut }: { statut: Boite['statut'] }) {
  const map: Record<Boite['statut'], { label: string; cls: string }> = {
    active: {
      label: 'Active',
      cls: 'bg-piloo-success text-piloo-success-on',
    },
    perimee: {
      label: 'Périmée',
      cls: 'bg-piloo-error text-piloo-error-on',
    },
    vide: { label: 'Vide', cls: 'bg-muted text-muted-foreground' },
  };
  const { label, cls } = map[statut];
  return (
    <span
      className={cn('inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium', cls)}
    >
      {label}
    </span>
  );
}

function NoActiveOfficineEmpty() {
  return (
    <Card>
      <CardContent className="pt-6 text-sm text-muted-foreground">
        Sélectionne une officine dans la sidebar pour voir son inventaire.
      </CardContent>
    </Card>
  );
}

function cmp(a: Boite, b: Boite, by: SortColumn): number {
  switch (by) {
    case 'peremption':
      return a.peremption.localeCompare(b.peremption);
    case 'cip13':
      return a.cip13.localeCompare(b.cip13);
    case 'stock': {
      const av = a.unites_restantes ?? -1;
      const bv = b.unites_restantes ?? -1;
      return av - bv;
    }
    case 'statut':
      return a.statut.localeCompare(b.statut);
  }
}

function formatDate(iso: string): string {
  // YYYY-MM-DD pour les dates plein-jour, YYYY-MM-DD HH:mm pour
  // datetime — on garde l'affichage simple.
  const trimmed = iso.length >= 10 ? iso.slice(0, 10) : iso;
  const d = new Date(trimmed);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
}
