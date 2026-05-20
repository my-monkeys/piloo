// Template email reset de mot de passe (#63, parent #134).
//
// Lien expirant 1h. Click → ouvre /reset-password?token=X côté web.
// Pas de deep-link mobile (Universal Links arrive avec piloo.fr).

export interface ResetPasswordTemplateInput {
  prenom?: string;
  resetUrl: string;
}

export function renderResetPassword(input: ResetPasswordTemplateInput): {
  subject: string;
  html: string;
  text: string;
} {
  const greeting = input.prenom?.trim() ? `Bonjour ${escapeHtml(input.prenom)},` : 'Bonjour,';
  const subject = 'Réinitialisez votre mot de passe Piloo';

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>${subject}</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F6F4F0;margin:0;padding:24px;color:#1F2A2A;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" width="560" style="background:#FFFFFF;border-radius:16px;padding:32px;">
    <tr><td>
      <h1 style="font-size:22px;margin:0 0 16px;">${greeting}</h1>
      <p style="font-size:15px;line-height:1.55;margin:0 0 16px;">
        Vous avez demandé à réinitialiser votre mot de passe Piloo. Cliquez sur le bouton ci-dessous pour en choisir un nouveau.
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${input.resetUrl}" style="display:inline-block;background:#3F8A75;color:#FFFFFF;text-decoration:none;padding:12px 24px;border-radius:10px;font-weight:600;">
          Choisir un nouveau mot de passe
        </a>
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Ce lien expire dans <strong>1 heure</strong>. Une fois utilisé, toutes vos sessions actives seront déconnectées par sécurité.
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Si vous n'êtes pas à l'origine de cette demande, ignorez ce message — votre mot de passe actuel reste inchangé.
      </p>
      <hr style="border:none;border-top:1px solid #E4E1DC;margin:24px 0;" />
      <p style="font-size:11px;color:#9AA5A4;line-height:1.5;margin:0;">
        Piloo est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien.
      </p>
    </td></tr>
  </table>
</body>
</html>`;

  const text = `${greeting}

Vous avez demandé à réinitialiser votre mot de passe Piloo. Ouvrez le lien ci-dessous pour en choisir un nouveau :

${input.resetUrl}

Ce lien expire dans 1 heure. Une fois utilisé, toutes vos sessions actives seront déconnectées par sécurité.

Si vous n'êtes pas à l'origine de cette demande, ignorez ce message — votre mot de passe actuel reste inchangé.

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
