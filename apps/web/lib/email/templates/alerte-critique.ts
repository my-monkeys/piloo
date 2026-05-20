// Template email "alerte critique" (#134, parent #16).
//
// 4ème template requis par #134. Couvre les 5 types d'alerte définis
// dans le schéma (cf. typeAlerteEnum) : péremption 30j / 7j, stock bas,
// prise oubliée, manque signalé. Le template adapte le wording selon le
// type mais garde une structure unique (HTML + texte responsives).
//
// Important non-MDR : le mail décrit un état factuel (stock = X, péremption
// dans X jours) — pas de recommandation clinique. Aide-mémoire personnel.

export type AlerteEmailType =
  | 'peremption_30j'
  | 'peremption_7j'
  | 'stock_bas'
  | 'prise_oubliee'
  | 'manque_signale';

export interface AlerteCritiqueTemplateInput {
  type: AlerteEmailType;
  prenom?: string;
  officineNom: string;
  /** Nom lisible du médicament concerné (DCI ou texte libre). */
  medicament: string;
  /** Détail spécifique au type — affiché en gros sous le titre. */
  detail: string;
  /** URL d'atterrissage (web pour l'instant ; mobile Universal Links plus tard). */
  ctaUrl: string;
}

const CONFIG: Record<AlerteEmailType, { titre: string; cta: string; intro: string }> = {
  peremption_7j: {
    titre: 'Péremption imminente',
    cta: 'Voir la boîte',
    intro: 'Une boîte va périmer dans moins de 7 jours.',
  },
  peremption_30j: {
    titre: 'Péremption à 30 jours',
    cta: 'Voir la boîte',
    intro: 'Une boîte arrive en fin de validité dans le mois qui vient.',
  },
  stock_bas: {
    titre: 'Stock bas',
    cta: 'Voir le médicament',
    intro: 'Il vous reste peu de doses pour ce médicament.',
  },
  prise_oubliee: {
    titre: 'Prise oubliée',
    cta: 'Ouvrir Piloo',
    intro: "Une prise n'a pas été validée à l'heure prévue.",
  },
  manque_signale: {
    titre: 'Manque signalé',
    cta: 'Voir le détail',
    intro: 'Un proche a signalé un manque dans cette officine.',
  },
};

export function renderAlerteCritique(input: AlerteCritiqueTemplateInput): {
  subject: string;
  html: string;
  text: string;
} {
  const cfg = CONFIG[input.type];
  const greeting = input.prenom?.trim() ? `Bonjour ${escapeHtml(input.prenom)},` : 'Bonjour,';
  const subject = `${cfg.titre} — ${input.medicament} (${input.officineNom})`;

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<title>${escapeHtml(subject)}</title>
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F6F4F0;margin:0;padding:24px;color:#1F2A2A;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" align="center" width="560" style="background:#FFFFFF;border-radius:16px;padding:32px;">
    <tr><td>
      <p style="font-size:12px;color:#9AA5A4;letter-spacing:0.3px;margin:0 0 6px;text-transform:uppercase;">${escapeHtml(input.officineNom)}</p>
      <h1 style="font-size:22px;margin:0 0 6px;">${escapeHtml(cfg.titre)}</h1>
      <p style="font-size:15px;line-height:1.55;margin:0 0 16px;color:#3F8A75;font-weight:600;">
        ${escapeHtml(input.medicament)}
      </p>
      <p style="font-size:15px;line-height:1.55;margin:0 0 8px;">
        ${escapeHtml(cfg.intro)}
      </p>
      <p style="font-size:15px;line-height:1.55;margin:0 0 16px;color:#1F2A2A;">
        <strong>${escapeHtml(input.detail)}</strong>
      </p>
      <p style="text-align:center;margin:28px 0;">
        <a href="${input.ctaUrl}" style="display:inline-block;background:#3F8A75;color:#FFFFFF;text-decoration:none;padding:12px 24px;border-radius:10px;font-weight:600;">
          ${escapeHtml(cfg.cta)}
        </a>
      </p>
      <hr style="border:none;border-top:1px solid #E4E1DC;margin:24px 0;" />
      <p style="font-size:11px;color:#9AA5A4;line-height:1.5;margin:0 0 8px;">
        Vous recevez cet email parce que vous suivez cette officine sur Piloo. Vous pouvez modifier vos préférences de notification dans l'application.
      </p>
      <p style="font-size:11px;color:#9AA5A4;line-height:1.5;margin:0;">
        Piloo est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien.
      </p>
    </td></tr>
  </table>
  <p style="font-size:11px;color:#9AA5A4;line-height:1.5;margin:16px auto 0;text-align:center;max-width:560px;">
    ${greeting} Cet email a été envoyé automatiquement par Piloo.
  </p>
</body>
</html>`;

  const text = `${cfg.titre} — ${input.officineNom}

${cfg.intro}
Médicament : ${input.medicament}
${input.detail}

Ouvrir : ${input.ctaUrl}

—
Vous recevez cet email parce que vous suivez cette officine sur Piloo. Vous pouvez modifier vos préférences dans l'application.

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
