// Sender Firebase Cloud Messaging (#122 — stub MVP).
//
// Le vrai pipeline FCM HTTP v1 demande :
//   - un projet Firebase configuré (côté Google Cloud)
//   - un service account JSON
//   - une route OAuth2 pour échanger ce JSON contre un access token
//   - APNS configuré pour iOS (Apple Auth Key + Team ID)
//
// Ce ticket (#126 scheduler) peut être livré indépendamment : on
// expose ici une interface `sendPush(...)` qui sera implémentée
// "pour de vrai" quand #122 sera complet. Pour l'instant, sans
// `FCM_SERVICE_ACCOUNT_JSON` configuré, on log "would send" et
// on retourne success — le cron peut quand même marquer `notified_at`
// et l'utilisateur ne reçoit juste pas de push.
//
// Quand #122 atterrira : remplacer `_send` par un vrai POST FCM.
import { log } from '@/lib/server/logger';

export interface PushPayload {
  /** Titre court (max ~40 chars). */
  title: string;
  /** Corps (1-3 lignes). */
  body: string;
  /** Données envoyées au handler côté mobile (route deep-link, ids). */
  data?: Record<string, string>;
}

export interface PushTarget {
  token: string;
  platform: 'ios' | 'android' | 'web';
}

export interface SendPushResult {
  /** Nombre de tokens envoyés avec succès. */
  sent: number;
  /** Nombre de tokens en erreur (token invalide, FCM down…). */
  failed: number;
  /** Tokens à supprimer côté DB (UNREGISTERED / INVALID_ARGUMENT). */
  invalidTokens: string[];
}

const STUB_MODE = !process.env['FCM_SERVICE_ACCOUNT_JSON'];

/**
 * Envoie un push à plusieurs devices. En mode stub (env var manquante)
 * on log "would send" — utile pour le dev / le déploiement sans
 * Firebase config encore prête.
 */
// eslint-disable-next-line @typescript-eslint/require-await
export async function sendPushBatch(
  targets: PushTarget[],
  payload: PushPayload,
): Promise<SendPushResult> {
  if (STUB_MODE) {
    log.info('fcm.stub.would_send', {
      count: targets.length,
      title: payload.title,
      platforms: targets.map((t) => t.platform),
    });
    return { sent: targets.length, failed: 0, invalidTokens: [] };
  }
  // TODO #122 : implémenter FCM HTTP v1
  //   1. service account JSON → google-auth-library → access token (cached 50 min)
  //   2. POST /v1/projects/{projectId}/messages:send par token
  //   3. parser les erreurs UNREGISTERED / SENDER_ID_MISMATCH → invalidTokens
  log.warn('fcm.not_implemented', { count: targets.length });
  return { sent: 0, failed: targets.length, invalidTokens: [] };
}
