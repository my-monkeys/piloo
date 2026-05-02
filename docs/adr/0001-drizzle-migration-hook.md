# ADR 0001 — Hook de migration Drizzle au déploiement

- **Date** : 2026-05-02
- **Statut** : Accepté
- **Décideurs** : équipe infra Piloo

## Contexte

Le serveur utilise Drizzle ORM sur PostgreSQL. Les migrations sont générées
(`drizzle-kit generate`) et committées dans `packages/db-schema/migrations/`.
Il faut un mécanisme automatique et fiable pour appliquer ces migrations en
production avant que la nouvelle version applicative ne soit promue, sans
risque pour les déploiements de preview.

Deux options principales :

1. **`buildCommand` Vercel** — chaîner `pnpm db:migrate && pnpm build` dans
   `vercel.json`.
2. **Workflow GitHub Actions dédié** — `migrate` puis `deploy` au push sur
   `main`, déclenché en dehors du build Vercel.

## Décision

On part sur l'**option 2 : workflow GHA `deploy-prod.yml`**.

Étapes :
1. `actions/checkout` + setup pnpm + `pnpm install --frozen-lockfile`
2. `pnpm db:migrate` (avec `DATABASE_URL = secrets.DATABASE_URL_MIGRATIONS`)
3. Job `deploy` (dépend de `migrate`) qui appelle la CLI Vercel pour build +
   promote en prod.

Le script racine `pnpm db:migrate` délègue à `packages/db-schema` via le
filtre pnpm (`pnpm --filter @piloo/db-schema migrate`), qui exécute
`drizzle-kit migrate`. Tant que le package n'est pas implémenté, c'est un
placeholder qui définit le contrat.

## Conséquences

**Positives**
- Les **previews Vercel ne touchent pas la base de prod** : le build Vercel
  reste pur (pas d'effet de bord DB), seul le workflow `deploy-prod`
  applique le DDL.
- Le rôle PG utilisé pour migrer (`DATABASE_URL_MIGRATIONS`) est isolé du
  rôle runtime : l'app n'a pas besoin de droits DDL, ce qui réduit le blast
  radius si la `DATABASE_URL` runtime fuit.
- Si la migration plante, le déploiement est bloqué avant promotion → pas
  de version applicative en avance de phase sur la DB.
- Concurrency `deploy-prod` empêche deux migrations de tourner en parallèle.

**Négatives**
- Deux endroits à maintenir : GHA + projet Vercel. Le déploiement n'est
  plus 100 % « git push → Vercel », il passe par GHA.
- Légère latence supplémentaire (le workflow doit installer + builder).
- Nécessite trois secrets côté GitHub : `DATABASE_URL_MIGRATIONS`,
  `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`.

**Pourquoi pas l'option 1 (`buildCommand`)**
- Chaque preview lancerait un `db:migrate`. Soit on partage la base prod
  (très mauvais : DDL appliqué depuis chaque PR), soit on provisionne une
  branche/DB par preview (complexe, hors scope MVP).
- Un guard `if [ "$VERCEL_ENV" = "production" ]` est possible mais fragile
  et ne résout pas l'isolation des credentials DDL.
- Le build Vercel n'a pas de garantie de retry/idempotence côté DB en cas
  d'échec partiel — moins traçable qu'un job GHA dédié.

## Suivi

- À implémenter quand `packages/db-schema/` aura un vrai schéma + premières
  migrations (ticket à créer dans la phase M1).
- Renseigner les secrets GitHub avant le premier merge sur `main` qui
  inclut une migration.
- Si on bascule plus tard sur Neon avec branches éphémères, réévaluer
  l'option 1 (buildCommand) avec une DB par preview.
