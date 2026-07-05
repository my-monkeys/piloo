# Déploiement Vercel — Piloo Web

> **⚠️ OBSOLÈTE (2026-06-18, #357/#368)** — Piloo n'est **plus déployé sur
> Vercel**. La prod tourne en **self-hosté sur cookie-server (Docker)**. Pour
> le déploiement actuel (build image + migrations + restart), voir
> **`deploy/README.md`**. Ce document est conservé à titre historique.

Ce document décrit la configuration Vercel pour `apps/web` (Next.js 15). Il couvre :

1. Le lien GitHub (preview par PR, prod sur `main`)
2. La configuration projet (Root Directory, build, install)
3. La liste des variables d'environnement à configurer **par environnement**
4. Les actions à faire **manuellement** dans le dashboard Vercel

> Le code de ce repo contient **uniquement** `apps/web/vercel.json`. Toutes les opérations dashboard listées ci-dessous sont **manuelles** — pas de secrets ni d'import automatique côté repo.

---

## 1. Lien GitHub (Production + Preview)

### Création du projet Vercel

1. Dashboard Vercel → **Add New… → Project**
2. **Import** le repo GitHub `piloo` (autoriser l'app GitHub Vercel si pas encore fait).
3. **Configure Project** :
   - **Framework Preset** : Next.js
   - **Root Directory** : `apps/web`
   - **Build & Output Settings** : laisser par défaut, le `vercel.json` du repo prend le relais (commande `pnpm turbo run build --filter=web...`).
   - **Node.js Version** : 20.x (LTS)
4. **Deploy** une première fois (peut échouer si les env vars manquent — c'est attendu).

### Branches & environnements

Vercel mappe automatiquement :

| Branche / event             | Environnement Vercel | URL                                                      |
| --------------------------- | -------------------- | -------------------------------------------------------- |
| `main` (push)               | **Production**       | `piloo.vercel.app` (ou domaine custom)                   |
| Toute PR ouverte            | **Preview**          | `piloo-<hash>-<team>.vercel.app` (URL unique par commit) |
| Toute autre branche poussée | **Preview**          | idem                                                     |

Côté `vercel.json` :

```json
"git": { "deploymentEnabled": { "main": true } }
```

→ seul `main` déclenche un build de prod. Les autres branches → preview uniquement (pas de déploiement prod accidentel depuis une feature branch).

### Protections recommandées (dashboard)

- **Settings → Git → Production Branch** : `main`
- **Settings → Deployment Protection → Vercel Authentication** : activer pour les preview (lecture par membres de l'équipe uniquement, pas de leak public).
- **Settings → Git → Ignored Build Step** : laisser vide, le `ignoreCommand` du `vercel.json` (`turbo-ignore`) fait le job — pas de rebuild si seuls `apps/mobile/` ou `docs/` ont changé.

---

## 2. Variables d'environnement

⚠️ **Aucune valeur n'est commitée dans le repo.** Toutes les variables suivantes sont à renseigner **manuellement** dans :

> Dashboard Vercel → Project Settings → **Environment Variables**

Pour chaque variable, cocher les environnements concernés : `Production`, `Preview`, `Development` (le `Development` est tiré par `vercel env pull` localement).

### Convention

- **Production** : valeurs réelles (DB prod, API keys live).
- **Preview** : valeurs **distinctes** de la prod — DB de staging, comptes Brevo/FCM sandbox. **Jamais** réutiliser les credentials prod en preview.
- **Development** : utilisé par `vercel env pull` pour générer un `.env.local` côté dev. Optionnel.

### Liste des clés attendues

| Clé                    | Description                                                                                                                                                             | Production |         Preview         |              Dev              | Sensible |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------: | :---------------------: | :---------------------------: | :------: |
| `DATABASE_URL`         | URL Postgres complète (Drizzle). Inclut user/pwd/host/db.                                                                                                               |     ✅     |     ✅ (DB staging)     | ✅ (DB locale ou neon branch) |    🔐    |
| `JWT_SECRET`           | Secret signature JWT (auth maison ou complément Better Auth). 32+ bytes random.                                                                                         |     ✅     |           ✅            |              ✅               |    🔐    |
| `BREVO_API_KEY`        | Clé API Brevo (transactional email + SMS).                                                                                                                              |     ✅     |   ✅ (compte sandbox)   |              ✅               |    🔐    |
| `FCM_SERVER_KEY`       | Server key Firebase Cloud Messaging (push notifications mobile).                                                                                                        |     ✅     | ✅ (projet FCM staging) |              ⚪               |    🔐    |
| `S3_ENDPOINT`          | Endpoint S3 (ex: `https://s3.eu-west-3.amazonaws.com` ou endpoint compatible R2/Scaleway).                                                                              |     ✅     |           ✅            |              ✅               |    ⚪    |
| `S3_REGION`            | Région S3 (ex: `eu-west-3`).                                                                                                                                            |     ✅     |           ✅            |              ✅               |    ⚪    |
| `S3_BUCKET`            | Nom du bucket (photos boîtes, ordonnances).                                                                                                                             |     ✅     |  ✅ (bucket distinct)   |              ✅               |    ⚪    |
| `S3_ACCESS_KEY_ID`     | Access key IAM/compatible.                                                                                                                                              |     ✅     |           ✅            |              ✅               |    🔐    |
| `S3_SECRET_ACCESS_KEY` | Secret key IAM/compatible.                                                                                                                                              |     ✅     |           ✅            |              ✅               |    🔐    |
| `NEXT_PUBLIC_APP_URL`  | URL publique de l'app (ex: `https://piloo.fr` en prod, vide en preview pour laisser Vercel injecter).                                                                   |     ✅     |           ⚪            |              ✅               |    ⚪    |
| `CRON_SECRET`          | Secret partagé Vercel Cron ↔ endpoint `/api/cron/*` (header `Authorization: Bearer …`). 32+ bytes random. **Production uniquement** — le cron ne tourne pas en preview. |     ✅     |           ⚪            |              ⚪               |    🔐    |

Légende :

- ✅ requis dans cet env
- ⚪ optionnel / dérivable
- 🔐 secret (ne jamais logger, jamais commit)

### Variables auto-injectées par Vercel (ne pas configurer)

Vercel pose ces variables tout seul, on peut les utiliser dans le code :

- `VERCEL_URL` — URL du deployment courant (utile en preview pour callbacks).
- `VERCEL_ENV` — `production` | `preview` | `development`.
- `VERCEL_GIT_COMMIT_SHA`, `VERCEL_GIT_COMMIT_REF` — métadonnées git.

### Pull local

Pour récupérer un `.env.local` synchronisé avec l'env `Development` :

```bash
cd apps/web
vercel link              # une seule fois, lie le dossier au projet Vercel
vercel env pull .env.local
```

→ génère `apps/web/.env.local`. Déjà ignoré par `.gitignore` racine (vérifier avant le premier commit).

---

## 3. Domaines (manuel, dashboard)

À configurer une fois le DNS prêt :

- **Production** : `piloo.fr` (ou sous-domaine décidé) → Settings → Domains → Add.
- **Preview** : laisser le pattern `<project>-<hash>.vercel.app` par défaut. Pas de domaine custom pour les previews.

---

## 4. Cron jobs

Le projet déclare des cron jobs dans `apps/web/vercel.json` (clé `crons`).
Vercel Cron ne tourne que sur l'environnement **Production** — les previews
n'invoquent jamais ces endpoints.

| Path                    | Schedule                              | Description                                                 | ADR                                   |
| ----------------------- | ------------------------------------- | ----------------------------------------------------------- | ------------------------------------- |
| `/api/cron/import-bdpm` | `0 3 5 * *` (le 5 du mois, 03:00 UTC) | Import mensuel BDPM (TSV data.gouv → Postgres → SQLite/S3). | [0003](adr/0003-bdpm-monthly-cron.md) |

**Sécurité** : chaque endpoint `/api/cron/*` doit valider le header
`Authorization: Bearer ${CRON_SECRET}` avant d'exécuter le job. Toute
requête sans ce header → `401`. Le secret est une env var prod (cf.
tableau §2).

**Vérification post-deploy** :

1. Dashboard Vercel → Project → **Cron Jobs** : vérifier que les entrées
   du `vercel.json` sont listées avec le bon schedule.
2. **Run Cron** manuellement depuis le dashboard (bouton ▶️) pour valider
   l'authentification et l'exécution end-to-end.
3. Inspecter les logs (`Logs → Cron`) — pas de CIP / nom médicament en
   clair.

---

## 5. À faire manuellement (récap)

Ce qui ne peut pas être automatisé depuis le repo :

- [ ] Importer le repo dans Vercel (UI dashboard).
- [ ] Sélectionner Root Directory = `apps/web`.
- [ ] Renseigner toutes les variables d'env du tableau ci-dessus, **par environnement**.
- [ ] Configurer la branche de production = `main`.
- [ ] Activer la **Deployment Protection** sur les previews (Vercel Authentication).
- [ ] Lier le domaine de prod (DNS).
- [ ] (Optionnel) Inviter les membres de l'équipe avec le rôle adéquat.
- [ ] (Optionnel) Configurer les **Notifications** Slack/email sur deployment failed.

---

## 6. Notes

- **Pas de HDS sur Vercel**. Tant que l'app contient des données médicales en prod réelle, l'hébergement Vercel ne suffit pas (cf. `CLAUDE.md` racine — "HDS obligatoire avant toute prod commerciale"). Vercel = OK pour le **POC** et la **démo**, à migrer vers un hébergeur HDS-certifié avant ouverture grand public.
- **Pas de tracking tiers** côté Vercel Analytics sur les écrans avec données médicales — utiliser au mieux le mode "anonymous" ou se passer de l'outil.
- **Logs Vercel** : ne jamais y envoyer de CIP, nom de médicament, ou identifiant patient (cf. règle 4 du CLAUDE.md racine).
