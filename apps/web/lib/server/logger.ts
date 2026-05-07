// Logger serveur avec sanitization automatique (#97).
//
// Règle produit : aucune donnée patient en clair dans les logs.
// On scrub les patterns sensibles connus (CIP13, GTIN-14, emails) et
// on redacte les clés réputées sensibles dans les payloads structurés.
//
// Usage :
//   import { log } from '@/lib/server/logger';
//   log.info('boite.create', { officineId, boiteId });
//   log.warn('sync.conflict', { userId, opId, reason: '...' });
//
// Anti-pattern (audit CI échoue) :
//   console.log('boite créée pour patient', user.email, medicament.nom);
//
// Voir `scripts/audit-logs.mjs` pour la grep CI.

export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/// Clés dont la valeur est systématiquement redactée si présente dans
/// un payload structuré. La liste est volontairement large : on
/// préfère sur-redacter que de fuiter par oubli.
const REDACTED_KEYS = new Set([
  'email',
  'mail',
  'phone',
  'tel',
  'password',
  'token',
  'secret',
  'authorization',
  'cookie',
  'cip',
  'cip13',
  'gtin',
  'lot',
  'serial',
  'medicament',
  'medicament_nom',
  'nom_medicament',
  'patient_nom',
  'patient_prenom',
  'patient_email',
  'firstname',
  'lastname',
  'dob',
  'date_naissance',
  'address',
  'adresse',
]);

const REDACTED = '[REDACTED]';

// Patterns à scrubber dans les chaînes libres (messages, errors).
const PATTERNS: [RegExp, string][] = [
  // CIP13 FR (commence par 3400) — 13 chiffres consécutifs.
  [/\b3400\d{9}\b/g, '[CIP13]'],
  // GTIN-14 FR (03400 + 9 chiffres).
  [/\b03400\d{9}\b/g, '[GTIN]'],
  // Emails.
  [/\b[\w.+-]+@[\w-]+\.[\w.-]+\b/g, '[EMAIL]'],
  // Tokens "Bearer xxx" ou JWT-like.
  [/\bBearer\s+[A-Za-z0-9._-]+/g, 'Bearer [REDACTED]'],
  [/\beyJ[A-Za-z0-9._-]{20,}/g, '[JWT]'],
];

/// Scrub une chaîne libre des patterns sensibles connus.
export function sanitizeString(input: string): string {
  let s = input;
  for (const [pattern, replacement] of PATTERNS) {
    s = s.replace(pattern, replacement);
  }
  return s;
}

/// Sanitize un payload structuré : redacte les clés sensibles, scrub
/// les valeurs string, descend récursivement (limité à 6 niveaux pour
/// éviter les références circulaires explosives).
export function sanitizePayload(value: unknown, depth = 0): unknown {
  if (depth > 6) return '[DEPTH_LIMIT]';
  if (value === null || value === undefined) return value;
  if (typeof value === 'string') return sanitizeString(value);
  if (typeof value === 'number' || typeof value === 'boolean') return value;
  if (value instanceof Error) {
    return {
      name: value.name,
      message: sanitizeString(value.message),
      // stack volontairement omis : peut contenir des valeurs locales.
    };
  }
  if (Array.isArray(value)) {
    return value.map((v) => sanitizePayload(v, depth + 1));
  }
  if (typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value as Record<string, unknown>)) {
      if (REDACTED_KEYS.has(key.toLowerCase())) {
        out[key] = REDACTED;
      } else {
        out[key] = sanitizePayload(val, depth + 1);
      }
    }
    return out;
  }
  // Fallback (functions, symbols, …) — on ignore.
  return undefined;
}

interface LogEntry {
  ts: string;
  level: LogLevel;
  event: string;
  data?: unknown;
}

function emit(level: LogLevel, event: string, data?: unknown): void {
  const entry: LogEntry = {
    ts: new Date().toISOString(),
    level,
    event,
    ...(data !== undefined ? { data: sanitizePayload(data) } : {}),
  };
  // JSON line — facile à parser côté observabilité (Datadog, Loki…).
  // En test, on rend silencieux pour ne pas polluer la sortie.
  if (process.env.NODE_ENV === 'test' && !process.env['PILOO_LOG_IN_TESTS']) {
    return;
  }
  const line = JSON.stringify(entry);
  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.log(line);
  }
}

export const log = {
  debug: (event: string, data?: unknown) => {
    emit('debug', event, data);
  },
  info: (event: string, data?: unknown) => {
    emit('info', event, data);
  },
  warn: (event: string, data?: unknown) => {
    emit('warn', event, data);
  },
  error: (event: string, data?: unknown) => {
    emit('error', event, data);
  },
};
