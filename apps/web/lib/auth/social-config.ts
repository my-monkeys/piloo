// Configuration des providers OAuth pour Better Auth (#64 Apple, #65 Google).
//
// Lit les variables d'environnement et pré-calcule les éléments coûteux
// (JWT client secret Apple, ES256 signé via `jose`). Les providers ne sont
// activés que si toutes leurs variables sont présentes — sinon on n'expose
// rien, ce qui permet aux tests et aux environnements sans credentials de
// tourner sans configuration OAuth.
//
// Le JWT Apple a une durée de vie maximale de 6 mois ; il est regénéré à
// chaque démarrage du process. Un redéploiement régulier suffit pour rester
// frais — Vercel rebuild bien plus souvent.
import { readFile } from 'node:fs/promises';

import { importPKCS8, SignJWT } from 'jose';

export interface AppleProviderConfig {
  clientId: string;
  clientSecret: string;
  appBundleIdentifier: string;
}

export interface GoogleProviderConfig {
  clientId: string;
  clientSecret: string;
}

// 6 mois — durée max acceptée par Apple pour `client_secret`.
const APPLE_SECRET_TTL_SECONDS = 180 * 24 * 60 * 60;

export async function loadAppleConfig(): Promise<AppleProviderConfig | undefined> {
  const clientId = process.env['APPLE_CLIENT_ID'];
  const teamId = process.env['APPLE_TEAM_ID'];
  const keyId = process.env['APPLE_KEY_ID'];
  const bundleId = process.env['APPLE_APP_BUNDLE_IDENTIFIER'] ?? clientId;
  const privateKey = await readApplePrivateKey();

  if (!clientId || !teamId || !keyId || !privateKey || !bundleId) {
    return undefined;
  }

  const clientSecret = await signAppleClientSecret({
    clientId,
    teamId,
    keyId,
    privateKey,
  });

  return { clientId, clientSecret, appBundleIdentifier: bundleId };
}

export function loadGoogleConfig(): GoogleProviderConfig | undefined {
  const clientId = process.env['GOOGLE_CLIENT_ID'];
  const clientSecret = process.env['GOOGLE_CLIENT_SECRET'];
  if (!clientId || !clientSecret) {
    return undefined;
  }
  return { clientId, clientSecret };
}

async function readApplePrivateKey(): Promise<string | undefined> {
  const inline = process.env['APPLE_PRIVATE_KEY'];
  if (inline?.includes('BEGIN PRIVATE KEY')) {
    // Vercel encourage à coller le PEM en clair avec `\n` littéraux ; on
    // les ré-injecte pour obtenir un PEM correct.
    return inline.replace(/\\n/g, '\n');
  }
  const path = process.env['APPLE_PRIVATE_KEY_PATH'];
  if (!path) {
    return undefined;
  }
  try {
    return await readFile(path, 'utf8');
  } catch {
    return undefined;
  }
}

interface AppleSecretParams {
  clientId: string;
  teamId: string;
  keyId: string;
  privateKey: string;
}

async function signAppleClientSecret(params: AppleSecretParams): Promise<string> {
  const key = await importPKCS8(params.privateKey, 'ES256');
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: params.keyId })
    .setIssuer(params.teamId)
    .setSubject(params.clientId)
    .setAudience('https://appleid.apple.com')
    .setIssuedAt(now)
    .setExpirationTime(now + APPLE_SECRET_TTL_SECONDS)
    .sign(key);
}
