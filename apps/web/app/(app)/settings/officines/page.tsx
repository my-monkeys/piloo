// Page Settings → Officines (#73). CRUD UI.
//
// Lecture : $api.useQuery('get', '/v1/officines') — liste accessible
// pour l'utilisateur courant (via le cookie Better Auth).
// Création : dialog avec form (nom, type, date_naissance, notes).
// Suppression : confirmation puis $api.useMutation DELETE.
//
// L'édition (PATCH) est laissée pour un follow-up — pas dans la portée
// minimale du ticket "Page Settings → Officines".
'use client';

import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { InviteDialog } from '@/components/app/officines/invite-dialog';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useActiveOfficine } from '@/lib/officines/active-officine';

type Officine = components['schemas']['Officine'];

export default function OfficinesSettingsPage() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');

  return (
    <div className="space-y-6">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-3xl">Officines</h1>
          <p className="text-muted-foreground">
            Gère les officines auxquelles tu as accès. Une officine perso pour toi, des officines
            patient si tu es pro de santé.
          </p>
        </div>
        <NewOfficineDialog />
      </header>

      {isLoading && <p className="text-muted-foreground">Chargement…</p>}

      {error && (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Tu n&apos;es pas connecté ou la session a expiré. Cette page est pleinement
            opérationnelle dès que l&apos;auth web sera branchée (ticket #169).
          </CardContent>
        </Card>
      )}

      {data?.items.length === 0 && (
        <Card>
          <CardContent className="pt-6 text-sm text-muted-foreground">
            Aucune officine pour le moment. Crée la première avec le bouton ci-dessus.
          </CardContent>
        </Card>
      )}

      <PendingInvitationsSection />

      {data?.items.length ? (
        <ul className="grid gap-3">
          {data.items.map((o) => (
            <li key={o.id}>
              <OfficineRow officine={o} />
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function PendingInvitationsSection() {
  const queryClient = useQueryClient();
  const { data, isLoading } = $api.useQuery('get', '/v1/me/invitations');
  const acceptMutation = $api.useMutation('post', '/v1/invitations/{token}/accept', {
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/me/invitations'] });
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/officines'] });
    },
  });

  if (isLoading) return null;
  if (!data?.items.length) return null;

  return (
    <section className="space-y-2">
      <h2 className="text-sm font-medium text-muted-foreground">Invitations en attente</h2>
      <ul className="grid gap-2">
        {data.items.map((inv) => (
          <li key={inv.token}>
            <Card className="border-piloo-primary/50">
              <CardContent className="flex items-center justify-between gap-3 p-4">
                <div className="space-y-1">
                  <p className="font-medium">{inv.officine_nom}</p>
                  <p className="text-xs text-muted-foreground">
                    Invité(e) par {inv.invited_by_name} · rôle {inv.role}
                  </p>
                </div>
                <Button
                  size="sm"
                  disabled={acceptMutation.isPending}
                  onClick={() => {
                    acceptMutation.mutate({ params: { path: { token: inv.token } } });
                  }}
                >
                  {acceptMutation.isPending ? 'Acceptation…' : 'Accepter'}
                </Button>
              </CardContent>
            </Card>
          </li>
        ))}
      </ul>
    </section>
  );
}

function OfficineRow({ officine }: { officine: Officine }) {
  const queryClient = useQueryClient();
  const { activeOfficineId, setActive } = useActiveOfficine();
  const isActive = officine.id === activeOfficineId;
  const canDelete = officine.role === 'owner';

  const deleteMutation = $api.useMutation('delete', '/v1/officines/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/officines'] });
      if (isActive) setActive(null);
    },
  });

  return (
    <Card>
      <CardContent className="flex items-center justify-between p-4">
        <div>
          <h3 className="font-medium">{officine.nom}</h3>
          <p className="text-xs text-muted-foreground">
            {officine.type === 'perso' ? 'Officine perso' : 'Patient'} · rôle {officine.role}
            {isActive && ' · active'}
          </p>
        </div>
        <div className="flex gap-2">
          {!isActive && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setActive(officine.id);
              }}
            >
              Activer
            </Button>
          )}
          {canDelete && <InviteDialog officineId={officine.id} officineNom={officine.nom} />}
          {canDelete && (
            <Button
              variant="ghost"
              size="sm"
              disabled={deleteMutation.isPending}
              onClick={() => {
                if (window.confirm(`Supprimer "${officine.nom}" ?`)) {
                  deleteMutation.mutate({ params: { path: { id: officine.id } } });
                }
              }}
            >
              {deleteMutation.isPending ? 'Suppression…' : 'Supprimer'}
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

function NewOfficineDialog() {
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [nom, setNom] = useState('');
  const [type, setType] = useState<'perso' | 'patient'>('perso');

  const createMutation = $api.useMutation('post', '/v1/officines', {
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/officines'] });
      setOpen(false);
      setNom('');
      setType('perso');
    },
  });

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>+ Nouvelle officine</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Nouvelle officine</DialogTitle>
          <DialogDescription>
            Une officine = un carnet de médicaments (le tien ou celui d&apos;un patient si tu es
            pro).
          </DialogDescription>
        </DialogHeader>

        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!nom.trim()) return;
            createMutation.mutate({ body: { nom: nom.trim(), type } });
          }}
          className="space-y-4"
        >
          <div className="space-y-2">
            <Label htmlFor="nom">Nom</Label>
            <Input
              id="nom"
              value={nom}
              onChange={(e) => {
                setNom(e.target.value);
              }}
              placeholder="Maison, Mme Dubois, …"
              required
              autoFocus
            />
          </div>
          <div className="space-y-2">
            <Label>Type</Label>
            <div className="flex gap-2">
              <Button
                type="button"
                variant={type === 'perso' ? 'default' : 'outline'}
                size="sm"
                onClick={() => {
                  setType('perso');
                }}
              >
                Perso
              </Button>
              <Button
                type="button"
                variant={type === 'patient' ? 'default' : 'outline'}
                size="sm"
                onClick={() => {
                  setType('patient');
                }}
              >
                Patient
              </Button>
            </div>
          </div>
          {createMutation.error && (
            <p className="text-sm text-destructive">Erreur : impossible de créer.</p>
          )}
          <DialogFooter>
            <Button type="submit" disabled={createMutation.isPending || !nom.trim()}>
              {createMutation.isPending ? 'Création…' : 'Créer'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
