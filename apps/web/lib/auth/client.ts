// Wrappers fetch typés vers les endpoints Better Auth, côté client (#169).
//
// Pas besoin de `@better-auth/react` — les endpoints sont stables et
// posent les cookies HTTPOnly automatiquement via Set-Cookie. On garde
// un wrapper fin pour normaliser la gestion d'erreur (Better Auth
// retourne `{ code, message }` ou `{ error: { code, message } }` selon
// l'endpoint).
'use client';

interface AuthErrorBody {
  code?: string;
  message?: string;
  error?: { code?: string; message?: string };
}

export class WebAuthError extends Error {
  readonly code: string;
  readonly statusCode: number;
  constructor(code: string, message: string, statusCode: number) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

async function postJson(path: string, body: unknown): Promise<Response> {
  return fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    credentials: 'same-origin',
  });
}

async function parseError(res: Response): Promise<WebAuthError> {
  let body: AuthErrorBody = {};
  try {
    body = (await res.json()) as AuthErrorBody;
  } catch {
    // Body non-JSON — on garde un message générique.
  }
  const code = body.error?.code ?? body.code ?? 'unknown_error';
  const message = body.error?.message ?? body.message ?? 'Erreur inconnue';
  return new WebAuthError(code, message, res.status);
}

export interface SignUpInput {
  email: string;
  password: string;
  name: string;
  nom: string;
  prenom: string;
  typeCompte: 'particulier' | 'pro';
  telephone?: string;
}

export async function signUpEmail(input: SignUpInput): Promise<void> {
  const res = await postJson('/api/auth/sign-up/email', input);
  if (res.status !== 200) throw await parseError(res);
}

export async function signInEmail(email: string, password: string): Promise<void> {
  const res = await postJson('/api/auth/sign-in/email', { email, password });
  if (res.status !== 200) throw await parseError(res);
}

export async function signOut(): Promise<void> {
  const res = await postJson('/api/auth/sign-out', {});
  if (res.status !== 200) throw await parseError(res);
}

/**
 * Flow OAuth Google sur web : POST /api/auth/sign-in/social retourne
 * un body `{ url, redirect: true }` que le client doit suivre lui-même
 * (Better Auth en mode `disableRedirect: true` côté serveur quand on
 * appelle via fetch sans Accept: text/html).
 */
export async function signInWithGoogleRedirect(callbackURL = '/dashboard'): Promise<string> {
  const res = await postJson('/api/auth/sign-in/social', {
    provider: 'google',
    callbackURL,
  });
  if (res.status !== 200) throw await parseError(res);
  const body = (await res.json()) as { url?: string };
  if (!body.url) {
    throw new WebAuthError('missing_url', 'Réponse OAuth sans URL de redirection.', 500);
  }
  return body.url;
}
