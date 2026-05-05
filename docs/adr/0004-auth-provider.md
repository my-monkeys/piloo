# ADR 0004 — Choix du provider d'authentification (Better Auth vs Clerk)

- **Date** : 2026-05-05
- **Statut** : Accepté
- **Décideurs** : équipe Piloo (M1 — Fondations techniques)
- **Ticket** : [#39](https://github.com/my-monkeys/piloo/issues/39)
- **POC d'intégration** : [#40](https://github.com/my-monkeys/piloo/issues/40)

## Contexte

Piloo est un carnet numérique de médicaments **multi-plateforme** (Next.js 15
App Router côté web, Flutter 3.x côté mobile) avec un backend API Routes
Next.js + Postgres/Drizzle. Le ticket [#39](https://github.com/my-monkeys/piloo/issues/39)
demande de trancher entre **Better Auth** et **Clerk** pour M1.

L'auth doit couvrir les exigences suivantes (sources : `docs/spec.md`,
`docs/architecture.md`, tickets #62/#63/#64/#65/#157) :

- **Email + mot de passe** (utilisateurs FR, parcours principal).
- **Vérification d'email par lien magique** valable 1h ([#62](https://github.com/my-monkeys/piloo/issues/62)).
- **Reset de mot de passe** par lien expirant 1h, qui invalide les sessions actives ([#63](https://github.com/my-monkeys/piloo/issues/63)).
- **Sign in with Apple** sur iOS — **obligation App Store** dès qu'un autre
  social provider est présent ([#64](https://github.com/my-monkeys/piloo/issues/64)).
- **Sign in with Google** sur web + iOS + Android ([#65](https://github.com/my-monkeys/piloo/issues/65)).
- **2FA TOTP** pour le compte pro (P2, M2, [#157](https://github.com/my-monkeys/piloo/issues/157)).
- **Deux types de compte** dans `users.type_compte` : `particulier` | `pro`
  (cf. `docs/data-model.md`).
- **Multi-device, multi-officine, partages RBAC** (table `partages`, rôles
  `proprietaire` / `editeur` / `lecteur`). La logique d'autorisation reste
  dans Postgres — l'auth provider ne gère que l'identité.
- **Mobile offline-first** : les tokens d'auth doivent survivre à un redémarrage
  d'app et se rafraîchir de manière transparente, y compris après une longue
  période hors-ligne. Toute écriture passe par `pending_operations`
  (cf. `CLAUDE.md` racine).
- **RGPD + données de santé** : hébergement EU dès le MVP. La conformité **HDS**
  (Hébergement de Données de Santé, ASIP/HAS) est explicitement post-MVP, mais
  le provider retenu **ne doit pas bloquer** une migration HDS ultérieure
  (`docs/architecture.md` §"Sécurité").
- **Coût** : POC d'abord, cible quelques milliers de MAU à terme. Pas de licence
  enterprise pour valider le produit.

## Options considérées

### 1. Better Auth

[Better Auth](https://www.better-auth.com/) est une bibliothèque d'auth
**open-source TypeScript** (MIT, dépôt
[`better-auth/better-auth`](https://github.com/better-auth/better-auth)),
framework-agnostic mais avec un excellent support Next.js. Elle s'installe en
NPM dans le projet et utilise **votre propre base de données** via un adapter
(Drizzle, Prisma, Kysely, MongoDB…). Pas de SaaS, pas de dashboard externe.

**Capacités vérifiées via context7 (`/better-auth/better-auth`)** :

- Adapter Drizzle natif :
  ```ts
  import { drizzleAdapter } from "better-auth/adapters/drizzle";
  database: drizzleAdapter(db, { provider: "pg" })
  ```
  Source : [docs/guides/optimizing-for-performance.mdx](https://github.com/better-auth/better-auth/blob/main/docs/content/docs/guides/optimizing-for-performance.mdx).
- Email/password de base (`emailAndPassword: { enabled: true }`).
- Plugin **magic link** officiel (`better-auth/plugins`), `expiresIn` configurable
  (10 min par défaut, on mettra 3600 pour [#62](https://github.com/my-monkeys/piloo/issues/62)).
  Source : [docs/concepts/client.mdx](https://github.com/better-auth/better-auth/blob/main/docs/content/docs/concepts/client.mdx).
- **Reset password** côté client via `authClient.resetPassword({ newPassword, token })`.
  Source : [docs/authentication/email-password.mdx](https://github.com/better-auth/better-auth/blob/main/docs/content/docs/authentication/email-password.mdx).
- Plugin **2FA TOTP** officiel (`twoFactor()` plugin) avec issuer custom et
  `sendOTP` hook pour fallback email/SMS.
- **Apple Sign-In** : provider officiel avec génération JWT client secret
  (helper `importPKCS8` + `SignJWT` de `jose`), supporte le flow natif iOS via
  `appBundleIdentifier`. Source :
  [docs/authentication/apple.mdx](https://github.com/better-auth/better-auth/blob/main/docs/content/docs/authentication/apple.mdx).
- **Google** : provider officiel `socialProviders.google` avec `clientId` /
  `clientSecret`.
- **Compatibilité Flutter** : Better Auth expose une **API REST** standard
  (`POST /api/auth/sign-in/email`, `/api/auth/sign-up/email`, `/api/auth/get-session`,
  etc.). Pas de SDK Dart officiel mais le contrat REST est documenté et stable,
  donc consommable proprement depuis Flutter (Dio + secure storage). Une
  bibliothèque communautaire `better_auth_flutter` existe sur pub.dev mais
  reste embryonnaire au 2026-05-05 — **à vérifier avant le POC #40**.
- **Bearer / JWT mobile** : plugin officiel `bearer()` qui accepte
  `Authorization: Bearer <session-token>` à la place du cookie de session, ce
  qui colle au pattern mobile. Refresh automatique côté client avec rotation
  configurable.

**Hébergement / RGPD** : Better Auth tourne dans **votre** Next.js, donc l'EU
data residency est **garantie par construction** dès lors qu'on déploie
l'app sur Vercel EU (Frankfurt `fra1`) + Postgres Neon EU. Aucun transfert vers
un tiers, pas de DPA externe requis pour l'auth.

**HDS** : neutre — comme tout vit dans notre stack, la migration HDS dépend
**uniquement** du choix d'hébergeur Postgres + Next.js. Aucun lock-in tiers.

**Pricing** : MIT, gratuit, pas de tier MAU.

**Maturité** (au 2026-05-05, à vérifier avant #40) : projet actif depuis 2024,
versions stables `1.3.x`, plus de 10k stars GitHub, releases fréquentes,
écosystème de plugins riche (admin, organization, passkey, multi-session…).
Risque : projet plus jeune que Clerk, moins de "battle-tested" en prod à grande
échelle. Mitigé par le fait qu'on **possède** le code et la DB.

**Limitations connues** :

- Pas de dashboard "admin users" out-of-the-box — il faut le construire (ou
  utiliser le plugin `admin()` qui expose les endpoints, mais l'UI est à faire).
- Pas de SDK Flutter officiel (mais REST stable).
- Email delivery à câbler nous-mêmes (Brevo via Nodemailer / API REST ; déjà
  prévu dans la stack notif Piloo).

### 2. Clerk

[Clerk](https://clerk.com/) est un **SaaS d'authentification** managé. Vous
intégrez leur SDK (`@clerk/nextjs`, `@clerk/expo`, `@clerk/clerk-ios`,
`@clerk/clerk-android`) et toute la logique tourne sur **leur infrastructure**.
Les utilisateurs sont stockés chez Clerk, on les synchronise dans notre Postgres
via webhooks (`user.created`, `user.updated`).

**Capacités vérifiées via context7 (`/clerk/clerk-docs`)** :

- **Email/password, magic link (email link), OTP email** disponibles.
- **Apple Sign-In iOS natif** via `@clerk/expo/apple`
  (`useSignInWithApple()`) ou via Clerk iOS Swift SDK
  (`clerk.auth.signUpWithApple()`). Source :
  [docs/reference/native-mobile/auth.ios.mdx](https://github.com/clerk/clerk-docs/blob/main/docs/reference/native-mobile/auth.ios.mdx).
- **Google** : provider OAuth standard + composant
  [`<GoogleOneTap />`](https://github.com/clerk/clerk-docs/blob/main/docs/reference/components/authentication/google-one-tap.mdx)
  pour le web.
- **TOTP MFA** : `mfa.verifyTOTP()` côté JS, `SignIn.verifyMfaCode(code, MfaType.TOTP)`
  côté Kotlin / Swift.
- **Webhooks** `user.created` / `user.updated` pour sync vers notre
  `users` Postgres (payload JSON documenté). Source :
  [docs/guides/development/webhooks/overview.mdx](https://github.com/clerk/clerk-docs/blob/main/docs/guides/development/webhooks/overview.mdx).
- **Pas de SDK Flutter officiel.** Clerk publie : `@clerk/nextjs`,
  `@clerk/expo` (React Native), `@clerk/clerk-ios` (Swift), `@clerk/clerk-android`
  (Kotlin), `@clerk/astro`, `@clerk/vue`, `@clerk/tanstack-react-start`,
  `@clerk/react-router`. **Aucun SDK Dart / Flutter officiel.** La doc Clerk
  mentionne explicitement que les SDK communautaires existent sans support
  officiel ([SDK community devs Discord](https://github.com/clerk/clerk-docs/blob/main/docs/guides/development/sdk-development/overview.mdx)).
  → Pour Flutter, on consommerait la **Frontend API REST** de Clerk à la main, ce
  qui annule une partie de la valeur ajoutée du provider.

**Hébergement / RGPD** : Clerk propose une option **EU data residency**
(instances hébergées en Europe) — **à confirmer sur le pricing courant avant
#40**, l'offre EU était historiquement gated sur les plans payants. Données
utilisateur (email, password hash, OAuth tokens, sessions) **stockées chez
Clerk**, pas dans notre Postgres. DPA à signer.

**HDS** : ⚠️ bloquant à terme. Clerk **n'est pas certifié HDS** au 2026-05-05
(à vérifier). Une migration HDS post-MVP impliquerait soit un changement de
provider (réauthentification forcée de tous les utilisateurs, perte d'historique
OAuth), soit attendre une certification Clerk EU/HDS hypothétique.

**Pricing** (à vérifier avant commit final, voir test plan PR) : tier **Free**
historiquement à 10 000 MAU avec rate limits, puis **Pro** payant par seat /
features (organizations, custom session, etc.) avec un palier d'inclusion MAU
puis surcharge à l'utilisateur. **Ne pas figer un nombre dans cette ADR** —
vérifier sur [clerk.com/pricing](https://clerk.com/pricing) avant le POC.

**Maturité** : très mature, multi-année de prod, dashboard polyvalent,
documentation excellente, support enterprise réel.

**Limitations connues pour Piloo** :

- **Pas de Flutter officiel** = perte de la moitié de la valeur sur mobile.
- **Données utilisateur hors de notre Postgres** = sync via webhook (latence,
  failure modes à gérer, source de vérité ambiguë).
- **Lock-in** : la table `users` est dérivée d'un `clerk_user_id` externe. Sortir
  de Clerk implique de re-hasher tous les mots de passe (ou forcer un reset
  global) et de re-lier les comptes OAuth.
- **Coût qui scale avec les MAU** — moins prédictible qu'une lib MIT.

### 3. Autres options écartées (rapidement)

- **Auth.js / NextAuth** : couvre bien le web Next.js, mais pas de support
  natif mobile (pas de mobile SDK, pas de bearer flow propre), 2FA absent du
  core, et l'écosystème reste fragmenté côté plugins. Better Auth est l'évolution
  spirituelle pensée pour combler ces manques.
- **Lucia** : excellent en termes de design, **abandonné/archivé** par son
  auteur en 2025 (en tout cas plus de releases majeures). Risque trop élevé.
- **Supabase Auth** : très bon mais nous force à **adopter Supabase** comme DB,
  ce qui contredit le choix Postgres Drizzle managé (Neon) acté dans
  `docs/architecture.md`. Hors-scope.
- **Firebase Auth** : pas de support clean côté Drizzle/Postgres, vendor lock-in
  Google sévère, et CLAUDE.md interdit Firebase Firestore (bien que Firebase
  Auth soit un autre service, on évite l'écosystème pour la cohérence
  privacy-first / EU residency).

## Tableau comparatif

| Dimension                                  | Better Auth                       | Clerk                              |
| ------------------------------------------ | --------------------------------- | ---------------------------------- |
| **Licence / coût**                         | ✅ MIT, gratuit                   | ⚠️ Free puis usage-based (à vérifier 2026-05-05) |
| **Email + password**                       | ✅ Core                           | ✅ Core                            |
| **Magic link (1h, [#62](https://github.com/my-monkeys/piloo/issues/62))**            | ✅ Plugin officiel                | ✅ Email link / OTP                |
| **Reset password ([#63](https://github.com/my-monkeys/piloo/issues/63))**            | ✅ `authClient.resetPassword()`   | ✅ Géré côté hosted UI             |
| **Apple Sign-In iOS ([#64](https://github.com/my-monkeys/piloo/issues/64))**          | ✅ Provider natif + JWT helper    | ✅ SDK iOS Swift natif             |
| **Google Sign-In web + mobile ([#65](https://github.com/my-monkeys/piloo/issues/65))** | ✅ Provider officiel              | ✅ Provider + Google One Tap web   |
| **2FA TOTP ([#157](https://github.com/my-monkeys/piloo/issues/157))**           | ✅ Plugin `twoFactor()`           | ✅ MFA TOTP                        |
| **SDK Flutter / Dart**                     | ⚠️ REST stable, pas de SDK officiel | ❌ Pas de SDK officiel ni REST simple |
| **SDK Next.js**                            | ✅ Excellent                      | ✅ Excellent                       |
| **Drizzle + Postgres BYO DB**              | ✅ Adapter natif                  | ❌ Sync par webhook depuis Clerk DB |
| **Source de vérité utilisateur**           | ✅ Notre Postgres                 | ⚠️ Clerk + webhook → Postgres      |
| **Mobile offline-first (token persistant)** | ✅ Plugin `bearer()`              | ✅ Tokens via SDK natif (mais pas Flutter) |
| **EU data residency (RGPD MVP)**           | ✅ Notre infra Vercel EU + Neon EU | ⚠️ Option EU à activer, à vérifier sur tier choisi |
| **HDS post-MVP (sans changer de provider)** | ✅ Dépend uniquement de notre hébergeur | ❌ Clerk pas certifié HDS au 2026-05-05 |
| **Self-hostable**                          | ✅ Par design                     | ❌ SaaS uniquement                 |
| **Lock-in**                                | ✅ Faible (lib NPM)               | ❌ Fort (DB externe + IDs Clerk)   |
| **Maturité / prod-readiness**              | ⚠️ Plus jeune (2024+, v1.3.x)     | ✅ Multi-année, très mature        |
| **Dashboard admin users out-of-the-box**   | ⚠️ À construire                   | ✅ Inclus                          |
| **Coût qui scale avec MAU**                | ✅ Non (lib)                      | ⚠️ Oui                             |

## Décision

**On retient Better Auth.**

> **TL;DR** : Better Auth est la seule option qui couvre **Flutter sans SDK
> communautaire branlant ni proxy maison**, qui garde nos utilisateurs **dans
> notre Postgres EU** (RGPD + futur HDS), qui est **gratuite à toute échelle**,
> et qui couvre toutes les exigences fonctionnelles de M1/M2 via ses plugins
> officiels (magic link, 2FA TOTP, Apple, Google).

Raisons principales, ancrées dans les contraintes Piloo :

1. **Flutter est notre mobile, pas Expo.** L'absence de SDK Flutter officiel
   chez Clerk est rédhibitoire : on devrait soit consommer une Frontend API
   non documentée pour le mobile, soit packager un wrapper maison. Better Auth
   expose au contraire une **REST API stable et documentée** que Flutter (Dio +
   `flutter_secure_storage` pour les tokens) consomme proprement, avec un
   plugin `bearer()` officiellement prévu pour ce cas.
2. **Postgres + Drizzle = source de vérité unique.** L'app est offline-first
   avec un journal `pending_operations` qui référence `users.id`. Avoir les
   utilisateurs **dans notre DB** (adapter Drizzle natif Better Auth) supprime
   tout un axe de complexité (webhook lag, double source de vérité, gestion des
   échecs de sync, FK qui ne peuvent pas être posées vers une table fantôme).
   Cohérent avec les principes "soft delete partout" et la sync custom de
   `docs/architecture.md`.
3. **RGPD MVP + voie HDS post-MVP propre.** Avec Better Auth, l'hébergement EU
   est garanti par notre choix d'hébergeur (Vercel `fra1` + Neon EU), et la
   migration HDS post-MVP ne dépend **que** du fait de bouger Postgres + Next.js
   chez un hébergeur HDS-certifié. Avec Clerk, on dépendrait de leur roadmap
   HDS (incertaine) ou d'une migration douloureuse forçant un reset password
   global.
4. **Coût prévisible.** Pour un POC qui vise quelques milliers de MAU sans
   modèle de revenu activé (`docs/dossier-cadrage.md`), une lib MIT évite de
   commencer à payer un SaaS avant d'avoir validé le produit. Si Piloo cartonne,
   le calcul "MAU × $/MAU Clerk vs heures dev économisées" pourra se refaire,
   mais pas avant.
5. **Pas de lock-in.** Better Auth est une lib NPM ; si on doit en changer,
   c'est un refactor lib-à-lib avec nos données déjà chez nous. Avec Clerk, on
   sortirait avec des hash de mot de passe non exportables (politique Clerk) →
   reset global obligatoire.

## Conséquences

### Ticket [#40 — Intégration auth provider choisi](https://github.com/my-monkeys/piloo/issues/40)

POC à scoper sur :

- Installer `better-auth` + `better-auth/adapters/drizzle` dans `apps/web`.
- Brancher l'adapter sur `packages/db-schema` (tables `users` + extensions
  Better Auth `account`, `session`, `verification`).
- Endpoints `/api/auth/[...all]` (handler unique Better Auth) côté Next.js.
- Activer email/password, plugin `bearer()` pour le mobile, plugin `magicLink()`
  configuré sur 1h pour préparer [#62](https://github.com/my-monkeys/piloo/issues/62).
- Tests d'intégration sign-up / sign-in / get-session web + REST (curl)
  pour le mobile.
- Côté Flutter : un client `AuthApi` minimal (Dio) qui POST `/api/auth/sign-up/email`,
  stocke le `bearer-token` dans `flutter_secure_storage`, et reload la session
  au boot.

### Ticket [#62 — Vérification email lien magique 1h](https://github.com/my-monkeys/piloo/issues/62)

Plugin `magicLink({ expiresIn: 60 * 60 })` côté Better Auth + intégration Brevo
pour l'envoi (cf. stack notif). Page `/auth/verify` côté web qui consomme le
token, deep link `piloo://auth/verify?token=...` côté Flutter.

### Ticket [#63 — Reset password](https://github.com/my-monkeys/piloo/issues/63)

`authClient.forgetPassword({ email, redirectTo })` + `authClient.resetPassword({ newPassword, token })`,
expiresIn 1h. Sur succès, **invalider toutes les sessions actives** de l'user
(API `auth.api.revokeUserSessions({ userId })`).

### Ticket [#64 — Apple Sign-In iOS](https://github.com/my-monkeys/piloo/issues/64)

Provider `apple` Better Auth avec helper JWT client secret
(`generateAppleClientSecret` côté serveur, ES256, expiration 180j). Côté
Flutter : package [`sign_in_with_apple`](https://pub.dev/packages/sign_in_with_apple)
pour récupérer le `identityToken` → POST vers `/api/auth/sign-in/social`
avec `{ provider: "apple", idToken }`. `appBundleIdentifier` à configurer.

### Ticket [#65 — Google Sign-In](https://github.com/my-monkeys/piloo/issues/65)

Provider `google` Better Auth (web). Flutter : package
[`google_sign_in`](https://pub.dev/packages/google_sign_in) pour récupérer
l'`idToken` natif → même flow `/api/auth/sign-in/social`. Pour Android et iOS,
chaque plateforme a son `clientId` OAuth Google distinct.

### Ticket [#157 — 2FA TOTP compte pro](https://github.com/my-monkeys/piloo/issues/157)

Plugin `twoFactor()` officiel. Activable depuis l'écran Settings du compte
`pro` (gating sur `users.type_compte = 'pro'`). Codes de secours générés à
l'activation. UI QR code via `qrcode` côté web et `qr_flutter` côté mobile.

### Risques à surveiller

- **Maturité Better Auth** : releases v1.x rapides, changements de plugins
  possibles. → Pinner la version dans `package.json` et auditer le changelog
  avant chaque bump majeur.
- **Pas de SDK Flutter officiel** : on consomme la REST API. → Geler le contrat
  REST utilisé dans un client Dart maison sous `apps/mobile/lib/auth/`,
  couvrir avec des tests d'intégration contre l'API réelle. Si une lib
  communautaire stable émerge avant M2, on pourra évaluer.
- **Pas de dashboard admin** : pour le POC ce n'est pas grave (queries SQL
  directes en debug). À terme, prévoir un écran `/admin/users` interne.
- **Email delivery est notre responsabilité** : Brevo doit être branché
  proprement pour magic link et reset. Failure mode = utilisateur bloqué dehors.
  Couvert par la stack notif déjà prévue.
- **HDS reste à faire** : la décision Better Auth ne crée **pas** la conformité
  HDS automatiquement, elle ne la **bloque pas**. Cf. `CLAUDE.md` racine — ne
  pas prétendre HDS-compliant tant qu'on ne l'est pas.

### Points à reverifier avant ouverture du POC #40

- Confirmer la dernière version stable Better Auth et son changelog
  (`pnpm view better-auth versions --json`).
- Vérifier que l'adapter Drizzle Better Auth supporte bien notre version
  Postgres / Drizzle pinnée dans `packages/db-schema`.
- Évaluer l'état de la lib communautaire `better_auth_flutter` (au cas où, mais
  on n'en dépend pas pour le MVP).
