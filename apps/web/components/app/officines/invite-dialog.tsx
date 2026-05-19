// Dialog "Inviter un proche" sur une officine (#139).
//
// Owner uniquement. POST /v1/officines/{id}/invitations, affiche le
// lien généré, propose un copier-coller. C'est l'UX MVP — l'envoi
// d'email (#127, besoin Brevo) viendra plus tard.
'use client';

import { $api } from '@piloo/api-client';
import { useState } from 'react';

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

type Role = 'owner' | 'editor' | 'viewer';

const roleLabel: Record<Role, string> = {
  owner: 'Propriétaire',
  editor: 'Éditeur',
  viewer: 'Lecteur',
};

const roleHelp: Record<Role, string> = {
  owner: 'Tout faire : modifier, inviter, supprimer.',
  editor: 'Modifier les boîtes, ordonnances et prises. Ne peut pas inviter.',
  viewer: 'Voir l’officine uniquement. Aucune modification.',
};

interface Props {
  officineId: string;
  officineNom: string;
}

export function InviteDialog({ officineId, officineNom }: Props) {
  const [open, setOpen] = useState(false);
  const [role, setRole] = useState<Role>('editor');
  const [email, setEmail] = useState('');
  const [link, setLink] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const createMutation = $api.useMutation('post', '/v1/officines/{officineId}/invitations', {
    onSuccess: (data) => {
      const origin = typeof window === 'undefined' ? '' : window.location.origin;
      setLink(`${origin}/invitations/${data.id}`);
    },
  });

  function reset() {
    setRole('editor');
    setEmail('');
    setLink(null);
    setCopied(false);
    createMutation.reset();
  }

  async function copyLink() {
    if (!link) return;
    await navigator.clipboard.writeText(link);
    setCopied(true);
    setTimeout(() => {
      setCopied(false);
    }, 2000);
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(o) => {
        setOpen(o);
        if (!o) reset();
      }}
    >
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          Inviter
        </Button>
      </DialogTrigger>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Inviter dans «&nbsp;{officineNom}&nbsp;»</DialogTitle>
          <DialogDescription>
            Génère un lien d&apos;invitation valable 72 heures. Partage-le par le moyen que tu veux
            (SMS, WhatsApp, email…).
          </DialogDescription>
        </DialogHeader>

        {link === null ? (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              createMutation.mutate({
                params: { path: { officineId } },
                body: {
                  role,
                  email: email.trim() === '' ? null : email.trim(),
                },
              });
            }}
            className="space-y-4"
          >
            <div className="space-y-2">
              <Label>Rôle</Label>
              <div className="flex gap-2">
                {(['editor', 'viewer'] as const).map((r) => (
                  <button
                    type="button"
                    key={r}
                    onClick={() => {
                      setRole(r);
                    }}
                    className={`rounded-full px-3 py-1 text-sm border transition-colors ${
                      role === r
                        ? 'bg-piloo-primary text-piloo-primary-on border-transparent'
                        : 'hover:bg-accent'
                    }`}
                  >
                    {roleLabel[r]}
                  </button>
                ))}
              </div>
              <p className="text-xs text-muted-foreground">{roleHelp[role]}</p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="invite-email">Email (optionnel)</Label>
              <Input
                id="invite-email"
                type="email"
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                }}
                placeholder="nom@exemple.fr"
                autoComplete="off"
              />
            </div>
            {createMutation.error && (
              <p className="text-sm text-destructive">
                Impossible de créer l&apos;invitation. Réessaie.
              </p>
            )}
            <DialogFooter>
              <Button type="submit" disabled={createMutation.isPending}>
                {createMutation.isPending ? 'Création…' : 'Générer le lien'}
              </Button>
            </DialogFooter>
          </form>
        ) : (
          <div className="space-y-3">
            <p className="text-sm">Lien valable 72 heures, à partager :</p>
            <div className="flex items-center gap-2">
              <Input value={link} readOnly className="font-mono text-xs" />
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  void copyLink();
                }}
              >
                {copied ? 'Copié !' : 'Copier'}
              </Button>
            </div>
            <DialogFooter>
              <Button
                type="button"
                onClick={() => {
                  setOpen(false);
                }}
              >
                Fermer
              </Button>
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
