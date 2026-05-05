// Catch-all Better Auth — gère sign-up/sign-in/sign-out/get-session/etc.
// La liste exhaustive est documentée par Better Auth ; côté Piloo on
// expose surtout :
//   POST /api/auth/sign-up/email
//   POST /api/auth/sign-in/email
//   POST /api/auth/sign-out
//   GET  /api/auth/get-session
// Cf. ADR 0004 §"Conséquences" et docs/api-contract.md (à compléter
// quand l'OpenAPI couvrira l'auth).
import { toNextJsHandler } from 'better-auth/next-js';

import { getAuth } from '@/lib/auth/server';

export async function GET(request: Request): Promise<Response> {
  return toNextJsHandler(getAuth().handler).GET(request);
}

export async function POST(request: Request): Promise<Response> {
  return toNextJsHandler(getAuth().handler).POST(request);
}
