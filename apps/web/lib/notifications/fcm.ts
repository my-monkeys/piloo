// Sender Firebase Cloud Messaging (#122).
//
// Implémentation FCM HTTP v1 via firebase-admin. La service account
// JSON est lue depuis l'env `FIREBASE_SERVICE_ACCOUNT_JSON` (JSON
// inline — peut être un string base64 ou JSON direct selon comment
// on l'a poussé dans Vercel).
//
// En mode stub (env manquante), on log "would send" — utile en local
// sans Firebase, et permet aux crons de tourner sans crasher.
//
// Erreurs FCM remontées comme `invalidTokens` :
//   - messaging/registration-token-not-registered (UNREGISTERED) : token
//     révoqué (uninstall, désactivation push) → à supprimer côté DB.
//   - messaging/invalid-argument : payload ou token mal formé.
// Le cleanup côté Drizzle est laissé au caller (cron) pour garder cette
// couche pure.
import { type App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, type Messaging, type Message } from 'firebase-admin/messaging';

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

let _app: App | undefined;
let _messaging: Messaging | undefined;

function getMessagingClient(): Messaging | null {
  const raw = process.env['FIREBASE_SERVICE_ACCOUNT_JSON'];
  if (!raw) return null;
  if (_messaging) return _messaging;
  try {
    // Vercel env val peut être stockée en JSON direct ou base64. On
    // tente JSON, fallback base64.
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      const decoded = Buffer.from(raw, 'base64').toString('utf8');
      parsed = JSON.parse(decoded);
    }
    // Réutilise l'app si déjà init (cold reuse Vercel).
    _app = getApps()[0];
    _app ??= initializeApp({
      credential: cert(parsed as Parameters<typeof cert>[0]),
    });
    _messaging = getMessaging(_app);
    return _messaging;
  } catch (e) {
    log.error('fcm.init_failed', {
      message: e instanceof Error ? e.message : 'unknown',
    });
    return null;
  }
}

export async function sendPushBatch(
  targets: PushTarget[],
  payload: PushPayload,
): Promise<SendPushResult> {
  if (targets.length === 0) {
    return { sent: 0, failed: 0, invalidTokens: [] };
  }
  const messaging = getMessagingClient();
  if (!messaging) {
    log.info('fcm.stub.would_send', {
      count: targets.length,
      title: payload.title,
      platforms: targets.map((t) => t.platform),
    });
    return { sent: targets.length, failed: 0, invalidTokens: [] };
  }

  // FCM HTTP v1 demande un POST par token (ou batch via legacy API
  // qui est dépréciée). firebase-admin gère ça via sendEach.
  const messages: Message[] = targets.map((t) => ({
    token: t.token,
    notification: { title: payload.title, body: payload.body },
    ...(payload.data && { data: payload.data }),
    apns: {
      payload: {
        aps: {
          // alert/sound/badge gérés via notification ci-dessus.
          // mutable-content permet une extension de notif (rich push).
          'mutable-content': 1,
        },
      },
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'piloo_fcm',
      },
    },
  }));

  try {
    const res = await messaging.sendEach(messages);
    const invalidTokens: string[] = [];
    res.responses.forEach((r, i) => {
      if (!r.success && r.error) {
        const code = r.error.code;
        const target = targets[i];
        if (
          target &&
          (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-argument' ||
            code === 'messaging/invalid-registration-token')
        ) {
          invalidTokens.push(target.token);
        }
      }
    });
    return {
      sent: res.successCount,
      failed: res.failureCount,
      invalidTokens,
    };
  } catch (e) {
    log.error('fcm.send_failed', {
      message: e instanceof Error ? e.message : 'unknown',
      count: targets.length,
    });
    return { sent: 0, failed: targets.length, invalidTokens: [] };
  }
}
