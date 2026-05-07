// Tests sanitization logger (#97).
import { describe, expect, it } from 'vitest';

import { sanitizePayload, sanitizeString } from '@/lib/server/logger';

describe('sanitizeString', () => {
  it('redacte les CIP13 FR', () => {
    expect(sanitizeString('lookup CIP=3400934567890')).toBe('lookup CIP=[CIP13]');
  });

  it('redacte les GTIN-14 FR', () => {
    expect(sanitizeString('GTIN 03400934567890 scannée')).toBe('GTIN [GTIN] scannée');
  });

  it('redacte les emails', () => {
    expect(sanitizeString('user alice@example.com login')).toBe('user [EMAIL] login');
  });

  it('redacte les tokens Bearer', () => {
    expect(sanitizeString('Authorization: Bearer abc.def-ghi_123')).toBe(
      'Authorization: Bearer [REDACTED]',
    );
  });

  it('redacte les JWT', () => {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NSJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV';
    expect(sanitizeString(`token=${jwt}`)).toBe('token=[JWT]');
  });

  it('laisse passer les chaînes neutres', () => {
    expect(sanitizeString('officine 12 boîtes')).toBe('officine 12 boîtes');
  });

  it('cumule plusieurs patterns dans une seule string', () => {
    expect(sanitizeString('alice@x.fr a scanné 3400934567890')).toBe('[EMAIL] a scanné [CIP13]');
  });
});

describe('sanitizePayload', () => {
  it('redacte les clés sensibles peu importe la valeur', () => {
    const out = sanitizePayload({
      userId: 'usr_42',
      email: 'alice@example.com',
      password: 'hunter2',
    });
    expect(out).toEqual({
      userId: 'usr_42',
      email: '[REDACTED]',
      password: '[REDACTED]',
    });
  });

  it('descend récursivement dans les objets imbriqués', () => {
    const out = sanitizePayload({
      officineId: 'off_1',
      patient: { firstName: 'Marie', lastName: 'Dubois', age: 42 },
    });
    expect(out).toEqual({
      officineId: 'off_1',
      patient: {
        firstName: '[REDACTED]',
        lastName: '[REDACTED]',
        age: 42,
      },
    });
  });

  it('sanitize les strings dans les valeurs non sensibles', () => {
    const out = sanitizePayload({
      message: 'CIP 3400934567890 introuvable',
      reason: 'unknown',
    });
    expect(out).toEqual({
      message: 'CIP [CIP13] introuvable',
      reason: 'unknown',
    });
  });

  it('gère les arrays', () => {
    const out = sanitizePayload(['alice@x.fr', 'bob']);
    expect(out).toEqual(['[EMAIL]', 'bob']);
  });

  it('réduit les Error en {name, message} sans stack', () => {
    const err = new Error('contact alice@example.com refusé');
    const out = sanitizePayload(err) as Record<string, string>;
    expect(out['name']).toBe('Error');
    expect(out['message']).toBe('contact [EMAIL] refusé');
    expect(out).not.toHaveProperty('stack');
  });

  it('tronque la profondeur excessive (DOS protection)', () => {
    interface Nested {
      next?: Nested;
    }
    const root: Nested = {};
    let cur = root;
    for (let i = 0; i < 10; i++) {
      cur.next = {};
      cur = cur.next;
    }
    const out = JSON.stringify(sanitizePayload(root));
    expect(out).toContain('DEPTH_LIMIT');
  });

  it('case-insensitive sur les clés sensibles', () => {
    const out = sanitizePayload({ Email: 'a@b.c', PASSWORD: 'x' });
    expect(out).toEqual({ Email: '[REDACTED]', PASSWORD: '[REDACTED]' });
  });

  it('null / undefined / nombres / bools passés tels quels', () => {
    expect(sanitizePayload(null)).toBeNull();
    expect(sanitizePayload(undefined)).toBeUndefined();
    expect(sanitizePayload(42)).toBe(42);
    expect(sanitizePayload(true)).toBe(true);
  });
});
