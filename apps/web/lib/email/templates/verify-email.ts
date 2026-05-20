// Template email vérification de compte (#62, parent #134).
//
// Lien magique 1h. URL primaire = web (ouvre le navigateur, Better Auth
// verifie le token et redirige vers /email-verified). Sur mobile, un
// Universal Link / App Link redirigera vers l'app si elle est installée
// (à configurer côté plist/manifest dans une étape distincte de la chaîne
// universal links — pour l'instant le lien web fait foi).

export interface VerifyEmailTemplateInput {
  prenom?: string;
  verifyUrl: string;
}

export function renderVerifyEmail(input: VerifyEmailTemplateInput): {
  subject: string;
  html: string;
  text: string;
} {
  const greeting = input.prenom?.trim() ? `Bonjour ${escapeHtml(input.prenom)},` : 'Bonjour,';
  const subject = 'Vérifiez votre adresse email Piloo';

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
        Bienvenue sur Piloo, votre carnet numérique de médicaments. Pour activer votre compte, confirmez votre adresse email en cliquant sur le bouton ci-dessous.
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${input.verifyUrl}" style="display:inline-block;background:#3F8A75;color:#FFFFFF;text-decoration:none;padding:12px 24px;border-radius:10px;font-weight:600;">
          Confirmer mon adresse
        </a>
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Ce lien expire dans <strong>1 heure</strong>. S'il a expiré, vous pouvez en demander un nouveau depuis l'écran de connexion.
      </p>
      <p style="font-size:13px;color:#6B7C7B;line-height:1.55;margin:0 0 12px;">
        Si vous n'avez pas créé de compte Piloo, ignorez ce message.
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

Bienvenue sur Piloo, votre carnet numérique de médicaments. Pour activer votre compte, confirmez votre adresse email en ouvrant le lien suivant :

${input.verifyUrl}

Ce lien expire dans 1 heure.

Si vous n'avez pas créé de compte Piloo, ignorez ce message.

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
