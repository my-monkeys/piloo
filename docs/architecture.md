# Architecture technique — Piloo

Ce document décrit l'architecture technique du projet et les décisions clés. Il est structuré en deux parties :
- Vue d'ensemble et patterns globaux
- ADR (Architecture Decision Records) pour les décisions non-évidentes

---

## Vue d'ensemble

```
┌─────────────────────┐         ┌─────────────────────┐
│  App mobile Flutter │         │  Next.js Web        │
│  - Dart / Widgets   │         │  - React (App Rtr)  │
│  - Riverpod (state) │         │  - Tailwind/shadcn  │
│  - Drift SQLite     │         │  - TanStack Query   │
│  - Sync custom      │◄───────►│                     │
└──────────┬──────────┘         └──────────┬──────────┘
           │                               │
           │  HTTP REST (OpenAPI contract) │
           └───────────────┬───────────────┘
                           ▼
          ┌────────────────────────────────┐
          │   Backend (Next.js API Routes) │
          │   - Validation Zod             │
          │   - Génération OpenAPI         │
          │   - Auth (Better Auth/Clerk)   │
          │   - Sync engine (custom)       │
          │   - Notifications (FCM/Brevo)  │
          └────────────────┬───────────────┘
                           ▼
          ┌────────────────────────────────┐
          │  PostgreSQL (Drizzle ORM)      │
          │  + Redis (queues notifs, v2)   │
          └────────────────────────────────┘
```

---

## Monorepo

### Structure

```
mon-officine/
├── apps/
│   ├── web/              Next.js 15 (UI web + backend API)
│   └── mobile/           Application Flutter (structure pub classique)
├── packages/
│   ├── db-schema/        Drizzle schemas + migrations Postgres
│   └── api-contract/     Schémas Zod + OpenAPI généré
├── scripts/
│   ├── generate-openapi.ts       → zod → openapi.yaml
│   ├── generate-ts-client.sh     → openapi → types TS pour web
│   └── generate-dart-client.sh   → openapi → client Dart pour mobile
├── turbo.json            Turborepo config
└── package.json          Root package
```

### Tooling

- **Turborepo** pour le JS/TS (`apps/web`, `packages/*`).
- **pnpm** comme package manager (meilleur pour les monorepos).
- **Flutter** vit à côté, piloté par son propre `flutter pub` et `flutter build`. Turbo l'ignore.
- **CI/CD** :
  - GitHub Actions pour le backend/web (lint, tests, deploy Vercel).
  - **Codemagic** pour Flutter (build iOS/Android, upload TestFlight/Play Console). Voir [ADR 001](./adr/001-flutter-ci.md).

---

## Stack technique

### Mobile (Flutter)

| Couche | Techno | Rôle |
|---|---|---|
| Framework | Flutter 3.x + Dart | UI cross-platform natif |
| State | Riverpod | Provider moderne, typé, testable |
| Navigation | go_router | URL-based, deep linking |
| Modèles | freezed + json_serializable | Classes immuables + JSON |
| DB locale | Drift (SQLite) | ORM typé avec génération de code |
| HTTP | Dio + client généré OpenAPI | Requêtes typées |
| Scan | mobile_scanner | MLKit sous le capot, GS1 DataMatrix natif |
| GS1 parser | Custom (lib interne ou package communautaire) | Décomposition AI (01/10/17/21) |
| Notifs | firebase_messaging + flutter_local_notifications | Push + rappels locaux |
| Connectivité | connectivity_plus | Détection réseau pour sync |
| Tests | test + integration_test | Unit + E2E |

### Web (Next.js)

| Couche | Techno | Rôle |
|---|---|---|
| Framework | Next.js 15 App Router | SSR + API Routes |
| Lang | TypeScript strict | |
| Styling | Tailwind CSS + shadcn/ui | Components accessibles |
| Forms | React Hook Form + Zod | Validation partagée avec backend |
| Server state | TanStack Query | Cache, invalidation |
| Client state | Zustand | Léger, typé |
| ORM | Drizzle | Typage TS natif, migrations SQL |
| Auth | Better Auth ou Clerk | À trancher en M1 |
| Validation API | Zod + zod-to-openapi | Contrat partagé |
| Tests | Vitest + Playwright | Unit + E2E |
| Deploy | Vercel (POC) ou Railway | |

### Backend (dans Next.js)

- **Routes API** : Next.js App Router route handlers.
- **Validation** : chaque endpoint wrappe son body/query avec Zod.
- **OpenAPI** : généré automatiquement via `zod-to-openapi` + script post-build.
- **Auth** : JWT côté mobile, session cookies côté web.
- **Sync** : endpoints `/api/sync/push` et `/api/sync/pull`.
- **Jobs background** : cron Vercel ou Railway pour :
  - Refresh BDPM mensuel
  - Génération des résumés IA pour nouveaux médicaments
  - Envoi emails/SMS en queue

### Infrastructure

- **Hébergement** : Vercel (web + API) + Neon ou Railway (Postgres managé).
- **Storage** : S3 compatible (Scaleway Object Storage, BackBlaze) pour les photos d'ordonnances OCR.
- **Notifications** : Firebase Cloud Messaging (push), Brevo (email + SMS).
- **Monitoring** : Sentry (erreurs) + Plausible (analytics privacy-first, en dehors des écrans médicaux) en v2.

---

## Patterns et décisions

### Sync offline custom

Cf. spec.md section 7. Pattern détaillé :

**Table locale** `pending_operations`
```
id (UUID client)
type         // 'create_boite' | 'update_boite' | 'mark_empty' | 'mark_prise' | ...
entity_type  // 'boite' | 'prise' | 'ordonnance' | ...
entity_id
payload      // JSON
timestamp_local
statut       // 'pending' | 'syncing' | 'synced' | 'failed'
attempts     // int pour backoff exponentiel
last_error   // string si failed
```

**Endpoints serveur**
- `POST /api/sync/push` → reçoit `{ operations: [...] }`, applique en transaction, retourne `{ acks: [...], conflicts: [...] }`.
- `GET /api/sync/pull?since=timestamp` → retourne `{ entities: [...], deleted: [...], server_time: timestamp }`.

**Règles**
- Toutes les tables métier ont `created_at`, `updated_at`, `deleted_at` (soft delete).
- Les IDs sont des UUID v4 générés côté client pour éviter les collisions à la sync.
- Conflits résolus en `last-write-wins` sur `updated_at`.
- Sync scheduler : tentative dès qu'on a du réseau + toutes les 5 min en background si changements locaux.

### Contrat API via OpenAPI

**Pipeline**
```
Schémas Zod (backend Next.js)
    ↓ zod-to-openapi
openapi.yaml  (artefact commité)
    ├→ openapi-typescript → types TS (web)
    └→ openapi-generator → client Dart + modèles (mobile)
```

**Conventions**
- Tous les endpoints sous `/api/v1/...`.
- Versionning via URL.
- Types snake_case côté API, convertis en camelCase côté clients via generators.
- Pagination : `?limit=N&cursor=X`.
- Erreurs au format `{ error: { code: "...", message: "...", details?: {...} } }`.

### Base BDPM locale

**Côté serveur**
- Table `medicaments_bdpm` en Postgres, read-only.
- Job cron mensuel qui télécharge les TSV BDPM, les parse, et upsert dans la table.
- Versioning : chaque import note `version_bdpm` (date de publication du fichier source).

**Côté mobile**
- Au premier lancement, l'app télécharge `bdpm_v{date}.sqlite.gz` depuis un CDN/S3.
- Décompresse et attache la DB à Drift (base read-only séparée).
- Un endpoint `GET /api/bdpm/version` retourne la dernière version. Au lancement, si la version locale < version serveur, téléchargement du nouveau fichier.
- Taille attendue : 20-30 Mo compressé, 60-80 Mo décompressé.

### Résumés IA des médicaments

- **Généré une seule fois** par médicament (pour les 15 800 entrées BDPM).
- Stockés dans la table `medicaments_resumes_ia` côté serveur.
- Embarqués dans la SQLite locale au même titre que la BDPM.
- Prompt type : *"Résume en 2-3 phrases courtes à quoi sert ce médicament [nom + DCI + indication BDPM]. Langage simple, pas de conseil médical, mention des précautions majeures."*
- Modèle recommandé : Claude Haiku (rapide, pas cher, qualité suffisante).
- Re-génération uniquement sur nouveaux médicaments (diff BDPM mensuel).

---

## Architecture Decision Records (ADR)

Les ADR suivants documentent les décisions structurantes. Chaque nouveau ADR suit le format : contexte, décision, alternatives considérées, conséquences.

### ADR-001 : Flutter pour le mobile

**Contexte** : besoin d'une app mobile iOS + Android. Choix entre React Native, Flutter, ou natif séparé.

**Décision** : **Flutter 3.x**.

**Alternatives** : React Native + Expo (rejeté en raison du churn d'écosystème, des mises à jour de paquets qui cassent fréquemment, des incompatibilités entre versions de Node.js).

**Conséquences**
- + Stabilité, pas de galères d'environnement à froid.
- + Excellent tooling (hot reload, DevTools).
- − Pas de partage de code avec le web Next.js (Dart ≠ TypeScript) → compensé par génération OpenAPI.
- − Double implémentation UI mobile / web.

### ADR-002 : Next.js 15 pour le web

**Contexte** : besoin d'une app web pro + API backend.

**Décision** : **Next.js 15 (App Router) + TypeScript**.

**Alternatives** : SvelteKit (moins mature écosystème), Remix (devenu React Router), Nuxt (on voulait du React).

**Conséquences**
- + SSR + API Routes dans un seul deploy.
- + Vercel zero-config pour le POC.
- + App Router moderne avec Server Components.
- − Migration App Router demande une maîtrise un peu plus poussée que Pages Router.

### ADR-003 : Sync offline custom (pas PowerSync/Electric)

**Contexte** : offline-first est critique (aides-soignants sans réseau). Choix entre solution SaaS (PowerSync, Electric SQL) et implémentation maison.

**Décision** : **sync custom** avec pattern pending_operations + push/pull.

**Alternatives**
- PowerSync : SDK Flutter mature, mais vendor lock-in + coût à l'échelle.
- Electric SQL : moins mature en Flutter.
- Firebase Firestore : modèle NoSQL inadapté aux relations médicament/boîte/prise.

**Conséquences**
- + Zéro vendor lock-in.
- + Contrôle total du comportement.
- − Plus de code à écrire en M1 (3-5 jours).
- − Responsabilité sur la gestion des conflits.
- − À documenter : pattern standard append-only operations log, tests à écrire.

### ADR-004 : API REST + OpenAPI (pas tRPC)

**Contexte** : web (TS) et mobile (Dart) partagent le backend. tRPC aurait été idéal en TS/TS mais marche mal avec Dart.

**Décision** : **API REST classique + génération OpenAPI**.

**Alternatives**
- tRPC pur : pas de client Dart viable.
- GraphQL : complexité inutile pour notre périmètre.
- REST manuel sans contrat : risque de désynchronisation clients/serveur.

**Conséquences**
- + Clients Dart et TS générés automatiquement, toujours synchrones.
- + API documentée via Swagger UI.
- − Pipeline de génération à maintenir (mais amortisable dès M1).

### ADR-005 : Carnet de suivi, pas dispositif médical

**Contexte** : le suivi des médicaments peut être considéré comme dispositif médical (règlement MDR), ce qui implique marquage CE, certifications, documentation lourde.

**Décision** : **positionnement carnet de suivi personnel**. Aucune recommandation clinique, aucune validation d'ordonnance, aucune alerte d'interaction.

**Alternatives** : viser dispositif médical = +12 mois de délai, +50k€ de budget compliance.

**Conséquences**
- + Développement allégé, pas de certification.
- + Positionnement clair dans la communication.
- − Limitation fonctionnelle : pas d'alerte interaction, pas de conseil médical automatisé.
- − Mentions "n'est pas un dispositif médical" obligatoires dans CGU/UI.

### ADR-006 : HDS reporté à la prod commerciale

**Contexte** : les données manipulées sont des données de santé au sens RGPD. L'hébergement HDS certifié est normalement requis.

**Décision** : **ignorer HDS au POC**, basculer vers un hébergeur HDS avant toute mise en prod avec de vrais patients.

**Alternatives** : démarrer HDS dès M1 = +5k€/mois de budget + lenteur de mise en œuvre.

**Conséquences**
- + Démarrage rapide sur Vercel/Railway.
- − Blocage légal pour la vraie prod : à prévoir dans la roadmap post-MVP.
- − Documentation explicite de cette dette technique.
- − Les tests réels avec vrais patients doivent être couverts par un consentement éclairé explicite au POC, ou se limiter à des données de test.

### ADR-007 : Pas de React Native Web

**Contexte** : on pourrait partager la codebase avec un framework cross-platform web+mobile.

**Décision** : **deux codebases distincts** (Flutter mobile + Next.js web).

**Alternatives** : Expo + React Native Web, ou Flutter Web.

**Conséquences**
- + Chaque plateforme a sa stack optimale.
- + Qualité native mobile préservée.
- + Pas de bricolage RN Web qui a des limitations.
- − UI à implémenter 2 fois (mitigé par design system simple et focus mobile-first).

---

## Sécurité

### Authentification

- JWT courts (15 min) + refresh tokens (7 jours) côté mobile.
- Session cookies HTTPOnly + Secure + SameSite=Strict côté web.
- 2FA TOTP optionnel, recommandé pour pros.
- Rate limiting sur `/api/auth/*` (10 req/min par IP).

### Autorisation

- Chaque endpoint vérifie que l'utilisateur a les droits sur l'officine concernée.
- Middleware Next.js : `requireAuth` + `requireRole(officine_id, role)`.
- Les partages sont vérifiés à chaque requête (pas de cache long).

### Chiffrement

- HTTPS obligatoire (certificat Let's Encrypt via Vercel).
- Base Postgres : chiffrement at-rest (Neon/Railway le font par défaut).
- Photos d'ordonnances stockées chiffrées avec une clé par utilisateur (v2 recommandée).
- Secrets applicatifs : variables d'environnement + Vault géré par l'hébergeur.

### RGPD & vie privée

- Registre des traitements à constituer avant beta publique.
- Politique de confidentialité explicite.
- Droit à l'effacement : suppression de compte = DELETE réel après 7 jours.
- Export de données : au format JSON sur demande.
- Pas d'analytics tiers sur les écrans médicaux.

---

## Déploiements

### Environnements

| Env | Hébergement | Usage |
|---|---|---|
| Local | `pnpm dev` + `flutter run` | Développement |
| Preview | Vercel preview par PR | Tests internes |
| Staging | Vercel + Postgres staging | Tests utilisateurs beta |
| Production | Vercel + Postgres prod | À partir de v1 HDS |

### Migrations DB

- Drizzle Kit pour générer les migrations SQL.
- Commitées dans `packages/db-schema/migrations`.
- Appliquées automatiquement au déploiement (hook CI).

### Builds mobile

- **Codemagic** pour iOS + Android (cf. [ADR 001](./adr/001-flutter-ci.md)).
- Versioning synchronisé avec les tags git.
- TestFlight pour iOS beta, Play Console internal track pour Android.
