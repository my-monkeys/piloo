// Middleware Next.js (#169) — pose un header `x-pathname` avec l'URL
// courante pour que les Server Components puissent connaître la route
// active (utile pour les redirects deep-link, le breadcrumb, etc).
//
// Next.js n'expose pas le pathname depuis `next/headers` natif — ce
// header artificiel comble le manque.
//
// Périmètre : exclut les assets statiques et l'auth interne pour
// limiter l'overhead (le middleware tourne à chaque requête).
import { NextResponse, type NextRequest } from 'next/server';

export function middleware(request: NextRequest): NextResponse {
  const response = NextResponse.next();
  response.headers.set('x-pathname', request.nextUrl.pathname);
  return response;
}

export const config = {
  matcher: [
    // Tout sauf _next/*, fichiers statiques (favicon, etc.), et l'API
    // catch-all auth (qui poste son propre cookie response).
    '/((?!_next/|api/auth/|.*\\.).*)',
  ],
};
