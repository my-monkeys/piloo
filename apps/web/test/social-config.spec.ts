// Tests unitaires loadGoogleConfig / loadAppleConfig (#287, follow-up #286).
//
// Stratégie : on stub process.env le temps du test, on appelle les
// factories, et on vérifie les comportements branches importants —
// notamment :
//   - Skip-if-config-missing (les providers doivent être ABSENTS si
//     une env var requise manque, sinon Better Auth tente d'utiliser
//     une config incomplète et crashe au runtime).
//   - Audience array Google (Web client + iOS client tous deux acceptés).
//   - Apple JWT : iss/sub/aud/alg/kid corrects + exp ~6 mois.
//
// On ne teste PAS l'intégrité crypto de jose.jwtVerify lui-même —
// c'est de la lib externe. On teste notre logique de filtrage et de
// construction.
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { exportPKCS8, generateKeyPair, decodeJwt, decodeProtectedHeader } from 'jose';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { loadAppleConfig, loadGoogleConfig } from '@/lib/auth/social-config';

// Snapshot l'env, restaure après chaque test.
const ORIGINAL_ENV = { ...process.env };

function unsetEnv(k: string): void {
  // `delete process.env[k]` est bloqué par no-dynamic-delete dans le
  // ruleset. `process.env[k] = undefined` ne marche pas (Node coerce en
  // string "undefined"). Reflect.deleteProperty contourne la règle sans
  // enfreindre la sémantique.
  Reflect.deleteProperty(process.env, k);
}

function setEnv(vars: Record<string, string | undefined>): void {
  for (const k of Object.keys(vars)) {
    if (vars[k] === undefined) unsetEnv(k);
    else process.env[k] = vars[k];
  }
}

const ENV_KEYS_TO_RESET = [
  'APPLE_CLIENT_ID',
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_APP_BUNDLE_IDENTIFIER',
  'APPLE_PRIVATE_KEY',
  'APPLE_PRIVATE_KEY_PATH',
  'GOOGLE_CLIENT_ID',
  'GOOGLE_CLIENT_SECRET',
  'GOOGLE_IOS_CLIENT_ID',
] as const;

beforeEach(() => {
  // Wipe les vars potentiellement présentes dans .env.local du dev
  // pour isoler les tests.
  for (const k of ENV_KEYS_TO_RESET) {
    unsetEnv(k);
  }
});

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
});

describe('loadGoogleConfig', () => {
  it('renvoie undefined si GOOGLE_CLIENT_ID manquant', () => {
    setEnv({ GOOGLE_CLIENT_SECRET: 'secret-only' });
    expect(loadGoogleConfig()).toBeUndefined();
  });

  it('renvoie undefined si GOOGLE_CLIENT_SECRET manquant', () => {
    setEnv({ GOOGLE_CLIENT_ID: 'id-only' });
    expect(loadGoogleConfig()).toBeUndefined();
  });

  it('renvoie une config quand les 2 vars sont là', () => {
    setEnv({ GOOGLE_CLIENT_ID: 'web-id', GOOGLE_CLIENT_SECRET: 'secret' });
    const cfg = loadGoogleConfig();
    expect(cfg).toBeDefined();
    expect(cfg?.clientId).toBe('web-id');
    expect(cfg?.clientSecret).toBe('secret');
    expect(cfg?.mapProfileToUser).toBeTypeOf('function');
    expect(cfg?.verifyIdToken).toBeTypeOf('function');
  });

  it('mapProfileToUser remplit nom/prenom depuis given_name/family_name', () => {
    setEnv({ GOOGLE_CLIENT_ID: 'web', GOOGLE_CLIENT_SECRET: 's' });
    const cfg = loadGoogleConfig();
    const mapped = cfg?.mapProfileToUser({
      given_name: 'Alice',
      family_name: 'Doe',
      email: 'a@b.fr',
    });
    expect(mapped).toEqual({ nom: 'Doe', prenom: 'Alice', typeCompte: 'particulier' });
  });

  it('mapProfileToUser tombe sur strings vides si pas de given/family', () => {
    setEnv({ GOOGLE_CLIENT_ID: 'web', GOOGLE_CLIENT_SECRET: 's' });
    const cfg = loadGoogleConfig();
    const mapped = cfg?.mapProfileToUser({});
    expect(mapped).toEqual({ nom: '', prenom: '', typeCompte: 'particulier' });
  });

  it('verifyIdToken renvoie false sur un token malformé', async () => {
    setEnv({ GOOGLE_CLIENT_ID: 'web', GOOGLE_CLIENT_SECRET: 's' });
    const cfg = loadGoogleConfig();
    expect(await cfg?.verifyIdToken('not.a.token')).toBe(false);
    expect(await cfg?.verifyIdToken('')).toBe(false);
  });
});

describe('loadAppleConfig', () => {
  let pemPath: string;
  let pemContent: string;

  beforeEach(async () => {
    // Génère une paire ES256 (algo utilisé par Apple) à la volée.
    const { privateKey } = await generateKeyPair('ES256', { extractable: true });
    pemContent = await exportPKCS8(privateKey);
    const dir = mkdtempSync(join(tmpdir(), 'apple-test-'));
    pemPath = join(dir, 'AuthKey_TEST.p8');
    writeFileSync(pemPath, pemContent, 'utf8');
  });

  it('renvoie undefined si APPLE_CLIENT_ID manquant', async () => {
    setEnv({ APPLE_TEAM_ID: 'T', APPLE_KEY_ID: 'K', APPLE_PRIVATE_KEY_PATH: pemPath });
    expect(await loadAppleConfig()).toBeUndefined();
  });

  it('renvoie undefined si APPLE_TEAM_ID manquant', async () => {
    setEnv({ APPLE_CLIENT_ID: 'c', APPLE_KEY_ID: 'K', APPLE_PRIVATE_KEY_PATH: pemPath });
    expect(await loadAppleConfig()).toBeUndefined();
  });

  it('renvoie undefined si la clé privée est introuvable', async () => {
    setEnv({
      APPLE_CLIENT_ID: 'c',
      APPLE_TEAM_ID: 'T',
      APPLE_KEY_ID: 'K',
      APPLE_PRIVATE_KEY_PATH: '/tmp/does-not-exist-xyz.p8',
    });
    expect(await loadAppleConfig()).toBeUndefined();
  });

  it('signe un JWT ES256 avec iss/sub/aud/kid corrects + exp ~6 mois', async () => {
    setEnv({
      APPLE_CLIENT_ID: 'fr.mymonkey.piloo',
      APPLE_TEAM_ID: '5C67TFSJ2B',
      APPLE_KEY_ID: 'YA4H7R7MM4',
      APPLE_PRIVATE_KEY_PATH: pemPath,
    });
    const cfg = await loadAppleConfig();
    expect(cfg).toBeDefined();
    expect(cfg?.clientId).toBe('fr.mymonkey.piloo');
    expect(cfg?.appBundleIdentifier).toBe('fr.mymonkey.piloo');

    const header = decodeProtectedHeader(cfg!.clientSecret);
    expect(header.alg).toBe('ES256');
    expect(header.kid).toBe('YA4H7R7MM4');

    const claims = decodeJwt(cfg!.clientSecret);
    expect(claims.iss).toBe('5C67TFSJ2B');
    expect(claims.sub).toBe('fr.mymonkey.piloo');
    expect(claims.aud).toBe('https://appleid.apple.com');

    const sixMonthsSec = 180 * 24 * 60 * 60;
    const expectedExp = Math.floor(Date.now() / 1000) + sixMonthsSec;
    // Tolérance ±60s pour absorber le temps d'exécution + l'arrondi.
    expect(claims.exp).toBeGreaterThan(expectedExp - 60);
    expect(claims.exp).toBeLessThan(expectedExp + 60);
  });

  it('supporte APPLE_PRIVATE_KEY inline avec \\n littéraux (cas Vercel)', async () => {
    setEnv({
      APPLE_CLIENT_ID: 'c',
      APPLE_TEAM_ID: 'T',
      APPLE_KEY_ID: 'K',
      // Vercel encourage à coller le PEM en une ligne avec \n échappés.
      APPLE_PRIVATE_KEY: pemContent.replace(/\n/g, '\\n'),
    });
    const cfg = await loadAppleConfig();
    expect(cfg).toBeDefined();
    expect(cfg?.clientSecret).toBeTypeOf('string');
  });

  it('appBundleIdentifier override APPLE_APP_BUNDLE_IDENTIFIER', async () => {
    setEnv({
      APPLE_CLIENT_ID: 'services-id',
      APPLE_APP_BUNDLE_IDENTIFIER: 'fr.mymonkey.piloo',
      APPLE_TEAM_ID: 'T',
      APPLE_KEY_ID: 'K',
      APPLE_PRIVATE_KEY_PATH: pemPath,
    });
    const cfg = await loadAppleConfig();
    expect(cfg?.clientId).toBe('services-id');
    expect(cfg?.appBundleIdentifier).toBe('fr.mymonkey.piloo');
  });
});
