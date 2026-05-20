// Template email invitation à rejoindre une officine (#127, parent #134).
//
// Envoyé quand l'owner d'une officine crée une invitation avec un email
// destinataire renseigné. Le lien pointe sur /invitations/{token} côté
// web (preview + accept). Mobile : Universal Links plus tard (piloo.fr).

const ROLE_LABELS: Record<'owner' | 'editor' | 'viewer', string> = {
  owner: 'propriétaire',
  editor: 'éditeur',
  viewer: 'lecteur',
};

export interface InvitationTemplateInput {
  inviteUrl: string;
  officineNom: string;
  invitedByName: string;
  role: 'owner' | 'editor' | 'viewer';
  expiresAt: Date;
}

export function renderInvitation(input: InvitationTemplateInput): {
  subject: string;
  html: string;
  text: string;
} {
  const officine = escapeHtml(input.officineNom);
  const inviter = escapeHtml(input.invitedByName);
  const role = ROLE_LABELS[input.role];
  const expires = formatExpiry(input.expiresAt);
  const subject = `${input.invitedByName} vous invite à rejoindre "${input.officineNom}" sur Piloo`;

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>${escapeHtml(subject)}</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F6F4F0;margin:0;padding:24px;color:#1F2A2A;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" width="560" style="background:#FFFFFF;border-radius:16px;padding:32px;">
    <tr><td>
      <h1 style="font-size:22px;margin:0 0 16px;">Bonjour,</h1>
      <p style="font-size:15px;line-height:1.55;margin:0 0 16px;">
        <strong>${inviter}</strong> vous invite à rejoindre l'officine <strong>${officine}</strong> en tant que <strong>${role}</strong> sur Piloo.
      </p>
      <p style="font-size:15px;line-height:1.55;margin:0 0 16px;">
        Une officine sur Piloo, c'est un carnet partagé de médicaments — pour suivre l'inventaire, les prises et les ordonnances à plusieurs.
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${input.inviteUrl}" style="display:inline-block;background:#3F8A75;color:#FFFFFF;text-decoration:none;padding:12px 24px;border-radius:10px;font-weight:600;">
          Voir l'invitation
        </a>
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Ce lien expire le <strong>${expires}</strong>. Vous devrez vous connecter ou créer un compte Piloo pour accepter.
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Si vous n'attendiez pas cette invitation, ignorez ce message — ${inviter} en sera informé(e).
      </p>
      <hr style="border:none;border-top:1px solid #E4E1DC;margin:24px 0;" />
      <p style="font-size:11px;color:#9AA5A4;line-height:1.5;margin:0;">
        Piloo est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien.
      </p>
    </td></tr>
  </table>
</body>
</html>`;

  const text = `Bonjour,

${input.invitedByName} vous invite à rejoindre l'officine "${input.officineNom}" en tant que ${role} sur Piloo.

Une officine sur Piloo, c'est un carnet partagé de médicaments — pour suivre l'inventaire, les prises et les ordonnances à plusieurs.

Acceptez l'invitation ici :
${input.inviteUrl}

Ce lien expire le ${expires}. Vous devrez vous connecter ou créer un compte Piloo pour accepter.

Si vous n'attendiez pas cette invitation, ignorez ce message.

—
Piloo est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien.`;

  return { subject, html, text };
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatExpiry(d: Date): string {
  return d.toLocaleString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit',
  });
}
