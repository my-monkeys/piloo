// Page Réglages → Officines (#73). CRUD UI, harmonisée au système du
// redesign (#370) : PageHeader + cartes avec avatar + badge de rôle.
'use client';

import { CheckCircleIcon as CheckCircle, PlusIcon as Plus } from '@phosphor-icons/react';
import { $api, type components } from '@piloo/api-client';
import { useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { Badge, type BadgeTone } from '@/components/app/badge';
import { officineAvatar, roleLabel, typeLabel } from '@/components/app/officine-display';
import { PageHeader } from '@/components/app/page-header';
import { Panel } from '@/components/app/panel';
import { InviteDialog } from '@/components/app/officines/invite-dialog';
import { Button } from '@/components/ui/button';
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
import { cn } from '@/lib/utils';

type Officine = components['schemas']['Officine'];

const ROLE_TONE: Record<Officine['role'], BadgeTone> = {
  owner: 'ok',
  editor: 'info',
  viewer: 'neutral',
};

export default function OfficinesSettingsPage() {
  const { data, isLoading, error } = $api.useQuery('get', '/v1/officines');

  return (
    <>
      <PageHeader eyebrow="Réglages" title="Officines" action={<NewOfficineDialog />} />

      {isLoading && <Muted>Chargement…</Muted>}
      {error && (
        <Panel>
          <Muted>Tu n&apos;es pas connecté ou la session a expiré.</Muted>
        </Panel>
      )}
      {data?.items.length === 0 && (
        <Panel>
          <Muted>Aucune officine pour le moment. Crée la première avec le bouton ci-dessus.</Muted>
        </Panel>
      )}

      <PendingInvitationsSection />

      {data?.items.length ? (
        <div className="flex flex-col gap-3">
          {data.items.map((o) => (
            <OfficineRow key={o.id} officine={o} />
          ))}
        </div>
      ) : null}
    </>
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

  if (isLoading || !data?.items.length) return null;

  return (
    <section className="mb-4 flex flex-col gap-2">
      <h2 className="text-[13px] font-bold uppercase tracking-[.06em] text-[var(--piloo-color-text-tertiary)]">
        Invitations en attente
      </h2>
      {data.items.map((inv) => (
        <div
          key={inv.token}
          className="flex items-center justify-between gap-3 rounded-2xl border border-piloo-primary-soft bg-piloo-surface p-4"
        >
          <div>
            <p className="font-semibold">{inv.officine_nom}</p>
            <p className="text-[12px] text-[var(--piloo-color-text-tertiary)]">
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
        </div>
      ))}
    </section>
  );
}

function OfficineRow({ officine }: { officine: Officine }) {
  const queryClient = useQueryClient();
  const { activeOfficineId, setActive } = useActiveOfficine();
  const isActive = officine.id === activeOfficineId;
  const canManage = officine.role === 'owner';
  const avatar = officineAvatar(officine.type);

  const deleteMutation = $api.useMutation('delete', '/v1/officines/{id}', {
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['get', '/v1/officines'] });
      if (isActive) setActive(null);
    },
  });

  return (
    <div
      className={cn(
        'flex flex-wrap items-center gap-3 rounded-2xl border bg-piloo-surface p-4',
        isActive
          ? 'border-piloo-primary'
          : 'border-[var(--piloo-color-border-soft,var(--piloo-color-border))]',
      )}
    >
      <span
        className={cn(
          'grid h-[38px] w-[38px] shrink-0 place-items-center rounded-[10px]',
          avatar.cls,
        )}
      >
        <avatar.Icon size={19} weight="fill" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <h3 className="truncate font-semibold">{officine.nom}</h3>
          {isActive && (
            <span className="inline-flex items-center gap-1 text-[11.5px] font-semibold text-piloo-primary">
              <CheckCircle size={14} weight="fill" />
              active
            </span>
          )}
        </div>
        <p className="text-[12px] text-[var(--piloo-color-text-tertiary)]">
          {typeLabel(officine.type)}
        </p>
      </div>
      <Badge tone={ROLE_TONE[officine.role]}>{roleLabel(officine.role)}</Badge>
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
        {canManage && <InviteDialog officineId={officine.id} officineNom={officine.nom} />}
        {canManage && (
          <Button
            variant="ghost"
            size="sm"
            className="text-[var(--piloo-color-text-tertiary)]"
            disabled={deleteMutation.isPending}
            onClick={() => {
              if (window.confirm(`Supprimer "${officine.nom}" ?`)) {
                deleteMutation.mutate({ params: { path: { id: officine.id } } });
              }
            }}
          >
            {deleteMutation.isPending ? '…' : 'Supprimer'}
          </Button>
        )}
      </div>
    </div>
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
        <Button size="sm">
          <Plus size={17} />
          Nouvelle officine
        </Button>
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
            <p className="text-sm text-piloo-error-on">Erreur : impossible de créer.</p>
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

function Muted({ children }: { children: React.ReactNode }) {
  return <p className="text-sm text-[var(--piloo-color-text-tertiary)]">{children}</p>;
}
