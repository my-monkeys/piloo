# ADR 0003 — Cron mensuel d'import BDPM

- **Date** : 2026-05-02
- **Statut** : Accepté
- **Décideurs** : équipe infra Piloo

## Contexte

La Base de Données Publique des Médicaments (BDPM) est mise à jour deux fois
par jour sur data.gouv.fr (TSV `CIS_bdpm.txt`, `CIS_CIP_bdpm.txt`, …). Le
serveur Piloo doit en garder une copie locale (table `medicaments_bdpm` en
Postgres + dump SQLite poussé en S3 pour les clients mobiles offline-first).

Le rythme d'import côté serveur n'a pas besoin de coller au rythme de
publication amont :

- Les changements quotidiens BDPM concernent surtout des changements de
  conditionnement / RCP qui n'ont pas d'impact immédiat sur le carnet
  utilisateur.
- Le bundle SQLite mobile est volumineux (~quelques Mo). Pousser un
  diff/full mensuel est suffisant ; plus fréquent gaspille de la bande
  passante côté clients (cf. `docs/architecture.md` §"BDPM mobile").

Il faut donc un déclencheur automatique, fiable, peu coûteux, qui exécute
`scripts/import-bdpm.ts` une fois par mois en environnement de production.

## Options

1. **Vercel Cron** sur le projet `apps/web` — endpoint `/api/cron/import-bdpm`
   exposé par Next.js, déclenché via la planification Vercel.
2. **Job Railway** déclenché par schedule sur un service `worker` séparé.
3. **GitHub Actions** schedule (`on: schedule: - cron`) qui SSH/CLI run le
   script.

## Décision

On retient l'**option 1 : Vercel Cron**.

- L'app web est déjà sur Vercel (cf. ADR 0001 §"Hook de migration"), pas de
  nouvelle infra à provisionner.
- Vercel Cron supporte un schedule par projet, géré dans `vercel.json`,
  versionné avec le code — pas de configuration "manuelle" à oublier.
- L'endpoint cron est protégé par un header `Authorization: Bearer
  ${CRON_SECRET}` que Vercel injecte automatiquement.

### Schedule retenu

```
0 3 5 * *
```

→ **Le 5 de chaque mois à 03:00 UTC** (= 04:00 ou 05:00 Paris selon DST).

Justification :
- **Le 5** plutôt que le 1er : laisse un buffer en cas de publication amont
  retardée en début de mois (jours fériés, maintenance ANSM). Un import
  mensuel suffit ; ce qui compte est la régularité, pas la fraîcheur à la
  journée près.
- **03:00 UTC** : creux de trafic côté web (≈ 04:00–05:00 Paris). Le job
  d'import est lourd (téléchargement TSV + diff Postgres + génération
  SQLite + upload S3) — on évite de se marcher dessus avec l'usage diurne.
- **Mensuel** : aligné avec la stratégie "diff mensuel" du bundle SQLite
  mobile (cf. `docs/architecture.md`).

### Endpoint et sécurité

- Path : `/api/cron/import-bdpm` (apps/web).
- Auth : `Authorization: Bearer ${CRON_SECRET}` validé par le handler.
  Toute requête sans header valide → `401`.
- Idempotence : le script BDPM doit être idempotent (un re-run ne casse
  rien). C'est sa responsabilité, pas celle du cron.
- Timeout : Vercel Cron exécute des fonctions serverless. Si l'import
  dépasse la limite (≤ 5 min en hobby, plus en pro), basculer sur un
  worker externe (option 2 ou 3) — re-décision à prendre à ce moment-là.

## Conséquences

- `vercel.json` contient le schedule, code-reviewable et propagé par
  déploiement.
- `CRON_SECRET` doit être ajouté dans l'env Vercel **prod uniquement**
  (les preview ne déclenchent pas le cron — Vercel Cron ne tourne que sur
  l'environnement Production).
- Si la limite de timeout serverless est atteinte un jour, on aura à
  re-trancher : Railway worker dédié ou GHA schedule. Documenter alors
  un nouvel ADR.
- Tant que `scripts/import-bdpm.ts` n'est pas implémenté (todos suivants
  du board infrastructure), l'endpoint peut renvoyer `501 Not Implemented`
  ou logger un no-op — le cron est inerte mais correctement câblé.

## Références

- `docs/architecture.md` §"BDPM" et §"Déploiements".
- `apps/web/vercel.json` (clé `crons`).
- `.env.example` clé `CRON_SECRET`.
- Vercel Cron Jobs : <https://vercel.com/docs/cron-jobs>.
