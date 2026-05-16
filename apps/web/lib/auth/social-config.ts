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

import { createRemoteJWKSet, decodeProtectedHeader, importPKCS8, jwtVerify, SignJWT } from 'jose';

// Champs additionnels requis par notre table `users` (cf. additionalFields
// dans server.ts) : nom, prenom, typeCompte. Apple ne fournit pas le nom
// dans son id_token (seulement à la 1ère connexion, via la "credential"
// retournée côté natif iOS), donc on accepte de stocker des valeurs vides
// au signup social — un écran de complétion de profil (#TODO) demandera
// ces champs ensuite.
interface SocialProfileMapping {
  nom: string;
  prenom: string;
  typeCompte: 'particulier';
}

export interface AppleProviderConfig {
  clientId: string;
  clientSecret: string;
  appBundleIdentifier: string;
  mapProfileToUser: (profile: AppleProfile) => SocialProfileMapping;
}

export interface GoogleProviderConfig {
  clientId: string;
  clientSecret: string;
  mapProfileToUser: (profile: GoogleProfile) => SocialProfileMapping;
  verifyIdToken: (token: string) => Promise<boolean>;
}

// Champs lus dans l'id_token décodé par Better Auth.
// Apple ne renvoie PAS name/given_name dans le JWT — uniquement `email`
// (et `sub` géré par Better Auth en interne). Le nom complet n'est
// disponible que dans la `ASAuthorizationAppleIDCredential` côté natif iOS
// à la 1ère connexion, et devrait être forwardé via un endpoint dédié
// dans un follow-up.
interface AppleProfile {
  email?: string;
}

interface GoogleProfile {
  email?: string;
  name?: string;
  given_name?: string;
  family_name?: string;
}

function mapAppleProfile(_profile: AppleProfile): SocialProfileMapping {
  // nom/prenom vides au signup Apple — un écran de complétion de profil
  // est prévu en follow-up pour les récupérer (Apple ne les expose que
  // via la credential native, pas dans l'id_token).
  return { nom: '', prenom: '', typeCompte: 'particulier' };
}

function mapGoogleProfile(profile: GoogleProfile): SocialProfileMapping {
  return {
    nom: profile.family_name ?? '',
    prenom: profile.given_name ?? '',
    typeCompte: 'particulier',
  };
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

  return {
    clientId,
    clientSecret,
    appBundleIdentifier: bundleId,
    mapProfileToUser: mapAppleProfile,
  };
}

// JWKS Google — instancié une fois pour profiter du cache jose intégré
// (sinon chaque verify déclenche un fetch de https://.../oauth2/v3/certs).
const googleJWKS = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export function loadGoogleConfig(): GoogleProviderConfig | undefined {
  const clientId = process.env['GOOGLE_CLIENT_ID'];
  const clientSecret = process.env['GOOGLE_CLIENT_SECRET'];
  if (!clientId || !clientSecret) {
    return undefined;
  }
  // google_sign_in 7.x sur iOS issue l'id_token pour le client *iOS*
  // (GIDClientID dans Info.plist), pas pour le client Web même quand
  // `serverClientId` est passé à initialize() — quirk du plugin. On
  // accepte donc les deux audiences. La valid' par défaut de Better
  // Auth ne prend qu'un seul `clientId` ; ce custom verifier la remplace.
  const acceptedAudiences = [clientId];
  const iosClientId = process.env['GOOGLE_IOS_CLIENT_ID'];
  if (iosClientId) acceptedAudiences.push(iosClientId);

  const verifyIdToken = async (token: string): Promise<boolean> => {
    try {
      const { kid, alg } = decodeProtectedHeader(token);
      if (!kid || !alg) return false;
      const { payload } = await jwtVerify(token, googleJWKS, {
        algorithms: [alg],
        issuer: ['https://accounts.google.com', 'accounts.google.com'],
        audience: acceptedAudiences,
        maxTokenAge: '1h',
      });
      // Défense en profondeur : quand on accepte plusieurs audiences, la
      // spec OIDC §3.1.3.7 demande de vérifier `azp` (authorized party)
      // contre la liste autorisée — sinon un token émis pour un autre
      // de NOS clients pourrait être rejoué.
      const azp = payload['azp'];
      if (typeof azp === 'string' && !acceptedAudiences.includes(azp)) {
        return false;
      }
      return true;
    } catch {
      return false;
    }
  };
  return { clientId, clientSecret, mapProfileToUser: mapGoogleProfile, verifyIdToken };
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
