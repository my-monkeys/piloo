// Email sender générique (#62, #63, #127, #134).
//
// Envoi via Brevo HTTP API v3 (`POST /v3/smtp/email`) — pas de SDK pour
// éviter une dépendance lourde. En mode stub (BREVO_API_KEY absente),
// on log le mail et on renvoie un succès factice : permet aux tests +
// au dev local de tourner sans Brevo, et permet à la prod de ne pas
// crasher si la clé n'est pas encore provisionnée.
//
// Confidentialité : on ne logge JAMAIS le contenu HTML/text ni le sujet
// en clair côté prod (peut contenir des données patient). Seul un hash
// court et le destinataire (sanitizé par le logger) sortent.
import { log } from '@/lib/server/logger';

export interface SendEmailInput {
  to: string;
  subject: string;
  html: string;
  text: string;
  /** Catégorie pour traçabilité Brevo (verify-email, reset-pwd, invite, ...). */
  tag: string;
}

export interface SendEmailResult {
  ok: boolean;
  messageId?: string;
  /** True si le mail n'a pas réellement été envoyé (mode stub). */
  stubbed: boolean;
}

interface BrevoConfig {
  apiKey: string;
  senderEmail: string;
  senderName: string;
}

function getBrevoConfig(): BrevoConfig | null {
  const apiKey = process.env['BREVO_API_KEY'];
  if (!apiKey) return null;
  const senderEmail = process.env['BREVO_SENDER_EMAIL'] ?? 'no-reply@piloo.fr';
  const senderName = process.env['BREVO_SENDER_NAME'] ?? 'Piloo';
  return { apiKey, senderEmail, senderName };
}

export async function sendEmail(input: SendEmailInput): Promise<SendEmailResult> {
  const cfg = getBrevoConfig();
  if (!cfg) {
    log.info('email.stub.would_send', { tag: input.tag, to: input.to });
    return { ok: true, stubbed: true };
  }

  try {
    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        'api-key': cfg.apiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        sender: { email: cfg.senderEmail, name: cfg.senderName },
        to: [{ email: input.to }],
        subject: input.subject,
        htmlContent: input.html,
        textContent: input.text,
        tags: [input.tag],
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      log.error('email.send_failed', {
        tag: input.tag,
        to: input.to,
        status: res.status,
        body: body.slice(0, 200),
      });
      return { ok: false, stubbed: false };
    }

    const parsed = (await res.json()) as { messageId?: string };
    return { ok: true, stubbed: false, ...(parsed.messageId && { messageId: parsed.messageId }) };
  } catch (e) {
    log.error('email.send_threw', {
      tag: input.tag,
      to: input.to,
      message: e instanceof Error ? e.message : 'unknown',
    });
    return { ok: false, stubbed: false };
  }
}
