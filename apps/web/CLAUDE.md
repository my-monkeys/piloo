# Instructions Claude Code — apps/web

Ce dossier contient l'application **Next.js 15** qui sert à la fois :
- le front web (UI pour utilisateurs bureau)
- le backend API consommé par le front web et par l'app mobile Flutter

> Lire `/CLAUDE.md` (racine) et `/docs/architecture.md` avant toute tâche complexe ici.

## Stack spécifique

- **Next.js 15** App Router + TypeScript strict
- **Tailwind CSS** + **shadcn/ui**
- **React Hook Form** + **Zod**
- **TanStack Query** pour le server state
- **Zustand** pour le state client
- **Drizzle ORM** pour Postgres (schéma dans `packages/db-schema`)
- **Better Auth** ou **Clerk** (à trancher en M1)

## Structure attendue

```
apps/web/
├── app/                    → App Router pages et API routes
│   ├── (auth)/             → Routes auth (login, register, ...)
│   ├── (dashboard)/        → Routes authentifiées
│   └── api/
│       └── v1/             → Endpoints API REST
├── components/
│   ├── ui/                 → shadcn/ui components
│   └── features/           → Composants métier (OfficineCard, BoiteList, ...)
├── lib/
│   ├── api/                → Client API (fetcher, hooks TanStack)
│   ├── db/                 → Accès DB (Drizzle)
│   ├── auth/               → Middleware, helpers auth
│   └── validation/         → Schémas Zod partagés (→ openapi-contract)
├── public/
├── next.config.js
├── tsconfig.json
├── package.json
└── CLAUDE.md               → ce fichier
```

## Conventions

- **API routes** : toutes sous `/api/v1/...`, validation Zod systématique du body/query, gestion d'erreur uniformisée.
- **Server Components par défaut** : préférer les Server Components quand possible. Les `"use client"` uniquement quand nécessaire (interactivité, hooks).
- **Data fetching** : dans les Server Components, appeler Drizzle directement. Dans les Client Components, TanStack Query.
- **Styling** : Tailwind. Éviter le CSS modules sauf cas très spécifique. Pas d'inline style sauf valeurs dynamiques.
- **Forms** : React Hook Form + `zodResolver`. Les schémas Zod du form sont partagés avec l'API quand applicable.

## Auth

- **Web** : sessions cookies HTTPOnly (SameSite=Strict).
- **API pour mobile** : JWT Bearer.
- Middleware Next.js vérifie la session sur les routes `(dashboard)`.
- Les API routes vérifient l'auth via helper `requireAuth(request)`.
- Les vérifications de rôle sur une officine se font via `requireRole(userId, officineId, 'owner' | 'editor' | 'viewer')`.

## Tests

- **Vitest** pour les unit tests (logique, utils, validation).
- **Playwright** pour quelques tests E2E sur les flux critiques (login, création officine, invitation).
- Pas de course aux 100% de couverture au MVP.

## Scripts importants

- `pnpm dev` : dev server local
- `pnpm build` : build prod
- `pnpm test` : tests Vitest
- `pnpm db:generate` : générer migrations Drizzle
- `pnpm db:migrate` : appliquer migrations
- `pnpm openapi:generate` : générer `openapi.yaml` depuis les schémas Zod

## Points d'attention

- **Pas d'analytics tiers** (Google Analytics, Mixpanel) sur les pages avec données médicales. Si on veut des analytics, Plausible self-hosted ou équivalent privacy-first.
- **Logs serveur** : jamais de noms de médicaments, CIP, ou noms de patients en clair. Utiliser des IDs pour tracer.
- **Rate limiting** : à implémenter sur `/auth/*` et `/sync/*` en priorité.
- **OpenAPI** : à chaque modif de schéma Zod exposé, regénérer le fichier OpenAPI (CI doit échouer si désynchronisé).

## Ce que Claude Code doit faire avant d'écrire du code ici

1. Lire `/CLAUDE.md` (racine) si pas déjà fait.
2. Lire `/docs/api-contract.md` si la tâche touche à l'API.
3. Lire `/docs/data-model.md` si la tâche touche à la DB.
4. Vérifier si un schéma Zod existe déjà dans `packages/api-contract/` pour l'entité concernée.
5. Écrire les tests unitaires en parallèle du code métier significatif.
