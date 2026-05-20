// Helper d'envoi email pour les alertes critiques (#134).
//
// Couche fine au-dessus du template `alerte-critique.ts` et de `sendEmail`.
// Prend une alerte DB + le contexte minimum nécessaire (destinataire +
// nom officine + médicament) et envoie le mail correspondant.
//
// Pas de wiring automatique côté crons pour l'instant — le helper est
// prêt à l'emploi quand on décidera quels alertes spamment l'inbox
// (probablement uniquement peremption_7j + prise_oubliee critiques).
import type { Alerte } from '@piloo/db-schema';

import { sendEmail, type SendEmailResult } from './client';
import { renderAlerteCritique } from './templates/alerte-critique';

interface RenderHints {
  /** Nom lisible du médicament concerné (BDPM > prescription.nom_texte). */
  medicament: string;
  /** Détail affiché en gros (ex: "Reste 2 doses", "Périme le 12/06/2026"). */
  detail: string;
}

export interface SendAlerteEmailInput {
  alerte: Pick<Alerte, 'type' | 'payload' | 'officineId'>;
  recipient: { email: string; prenom?: string };
  officineNom: string;
  /** App URL absolue. Fallback NEXT_PUBLIC_APP_URL ou localhost. */
  appUrl?: string;
  /** Hints calculés par le caller (cron) à partir du payload. */
  hints: RenderHints;
}

/** Émet un mail "alerte critique" pour cette alerte/destinataire. */
export async function sendAlerteEmail(input: SendAlerteEmailInput): Promise<SendEmailResult> {
  const appUrl = input.appUrl ?? process.env['NEXT_PUBLIC_APP_URL'] ?? 'http://localhost:3000';
  const ctaUrl = buildCtaUrl(appUrl, input.alerte);
  const rendered = renderAlerteCritique({
    type: input.alerte.type,
    prenom: input.recipient.prenom,
    officineNom: input.officineNom,
    medicament: input.hints.medicament,
    detail: input.hints.detail,
    ctaUrl,
  });
  return sendEmail({
    to: input.recipient.email,
    subject: rendered.subject,
    html: rendered.html,
    text: rendered.text,
    tag: `alerte:${input.alerte.type}`,
  });
}

function buildCtaUrl(appUrl: string, alerte: Pick<Alerte, 'type' | 'payload'>): string {
  // Atterrissages distincts par type. Les routes web n'existent pas
  // toutes encore — celles non câblées renvoient au dashboard qui
  // les listera (#171 inventaire + alertes).
  const payload = alerte.payload;
  if (alerte.type === 'prise_oubliee') {
    return `${appUrl}/dashboard`;
  }
  if (
    (alerte.type === 'peremption_7j' || alerte.type === 'peremption_30j') &&
    typeof payload['boite_id'] === 'string'
  ) {
    return `${appUrl}/inventory#${payload['boite_id']}`;
  }
  return `${appUrl}/dashboard`;
}
