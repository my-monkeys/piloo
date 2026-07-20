# Déploiement self-hosté — cookie-server (#357)

Migration de la DB **Neon → Postgres self-hosté** + app Next.js sur cookie-server,
exposée en `https://piloo.my-monkey.fr` via le tunnel Cloudflare existant.
Motif : le free tier Neon (100 CU-hours/mois) était épuisé par un compute qui ne
s'endormait jamais (connexions persistantes). En self-host, plus de compteur.

Architecture : `Cloudflare (HTTP) → Caddy → piloo-web:3000 → piloo-db:5432`.
Postgres n'est **jamais** exposé publiquement (réseau Docker `internal`).

---

## 0. Pré-flight (poste local) — sauver les données Neon si encore lisible

Tant que Neon répond, faire un dump (sinon : repartir du schéma + ré-import BDPM,
acceptable en POC). Récupérer `DATABASE_URL` prod dans le dashboard Neon/Vercel :

```bash
pg_dump "postgresql://…neon.tech/…?sslmode=require" \
  -Fc --no-owner --no-privileges -f ~/piloo_neon_backup.dump
# pg_dump v17 requis (Neon = PG17) : brew install postgresql@17
```

## 1. Récupérer le repo sur cookie-server

```bash
ssh cookie-server.tailscale
git clone git@github.com:my-monkeys/piloo.git /home/maxim/piloo
cd /home/maxim/piloo
git checkout 357-choreinfra-migrer-la-db-neon-postgres-self-hoste-sur-cookie-server  # ou main après merge
```

## 2. Configurer l'environnement

```bash
cp deploy/.env.example deploy/.env
# Générer un mot de passe DB et le reporter dans POSTGRES_PASSWORD + les 2 DATABASE_URL :
openssl rand -base64 24
# Recopier les secrets applicatifs (BETTER_AUTH_SECRET, OAuth, Brevo, FCM, S3, IA…)
# depuis l'env Vercel actuel — voir .env.example racine pour la liste complète.
nano deploy/.env
```

## 3. Build + démarrage

```bash
# caddy-net doit exister (réseau de la stack Caddy). Sinon ajuster le compose.
docker network ls | grep caddy
docker compose -f deploy/docker-compose.yml up -d --build
```

## 4. Migrations + données

```bash
# Schéma (Drizzle) — one-shot
docker compose -f deploy/docker-compose.yml run --rm migrate

# Option A : restaurer le dump Neon (si fait en étape 0)
docker cp ~/piloo_neon_backup.dump piloo-db:/tmp/db.dump
docker exec -i piloo-db pg_restore -U piloo -d piloo --no-owner --clean --if-exists /tmp/db.dump

# Option B (POC, pas de dump) : repeupler la BDPM via la route cron
#   (hors Vercel, pas de limite de durée → l'import complet passe)
curl -fsS -H "Authorization: Bearer <CRON_SECRET>" https://piloo.my-monkey.fr/api/cron/import-bdpm
```

## 5. Exposer via Caddy + Cloudflare

**Caddy** — ajouter dans `/home/maxim/caddy/Caddyfile` :

```
piloo.my-monkey.fr {
    reverse_proxy piloo-web:3000
}
```

puis recharger Caddy (`docker compose -f /home/maxim/caddy/docker-compose.yml restart` ou `caddy reload`).

**Cloudflare** — exposer le hostname comme `uuu.my-monkey.fr` :

- Ajouter une route d'ingress `piloo.my-monkey.fr → localhost:80` dans
  `/etc/cloudflared-monkey/config.yml` (le tunnel pointe sur Caddy), puis
  `sudo systemctl restart cloudflared-monkey`.
- Créer l'enregistrement DNS (CNAME vers le tunnel) côté Cloudflare.

Vérifier : `curl -I https://piloo.my-monkey.fr`.

## 6. OAuth — autoriser le nouveau domaine

Sinon le login social casse (web **et** mobile) :

- **Google Cloud Console** → OAuth client → Authorized redirect URIs :
  `https://piloo.my-monkey.fr/api/auth/callback/google`
- **Apple** (Sign in with Apple) → Service ID → Return URLs :
  `https://piloo.my-monkey.fr/api/auth/callback/apple`

## 7. Mobile — repointer

Une fois l'API en ligne, flip dans `apps/mobile/lib/core/config/api_config.dart` :
`_defaultBaseUrl = 'https://piloo.my-monkey.fr'`, puis rebuild.
(Test rapide sans rebuild : `flutter run --dart-define=PILOO_API_BASE_URL=https://piloo.my-monkey.fr`.)

---

## Exploitation

```bash
docker compose -f deploy/docker-compose.yml logs -f web   # logs app
docker compose -f deploy/docker-compose.yml pull && \
  docker compose -f deploy/docker-compose.yml up -d --build   # mise à jour
```

## Crons applicatifs (self-host, #389)

Les crons de `apps/web/vercel.json` ne tournaient que sur Vercel Cron — depuis la
migration self-host ils sont déclenchés par la **crontab de `maxim` sur
cookie-server** (heure locale Europe/Paris), via
`/home/maxim/piloo/cron-api.sh <path> <GET|POST>` : curl authentifié
`Authorization: Bearer CRON_SECRET` (lu dans `deploy/.env`) vers
`https://piloo.my-monkey.fr<path>`, log dans `/home/maxim/piloo/logs/cron.log`.

| Horaire (Paris) | Route                               | Méthode |
| --------------- | ----------------------------------- | ------- |
| `0 3 5 * *`     | `/api/cron/import-bdpm`             | GET     |
| `0 4 5 * *`     | `/api/v1/cron/bdpm-auto-link`       | GET     |
| `0 2 * * *`     | `/api/v1/cron/generation-glissante` | POST    |
| `0 5 * * *`     | `/api/v1/cron/anonymize-accounts`   | POST    |
| `0 6 * * *`     | `/api/v1/cron/stock-bas`            | POST    |
| `0 7 * * *`     | `/api/v1/cron/rappels-prises`       | GET     |
| `0 12 * * *`    | `/api/v1/cron/rappels-retard`       | GET     |
| `0 22 * * *`    | `/api/v1/cron/prise-oubliee`        | POST    |

⚠️ La méthode HTTP varie selon la route (4 GET, 4 POST) — un mauvais verbe
renvoie 405. `/api/v1/cron/peremption` existe mais n'est volontairement pas
planifiée (elle ne l'était pas non plus sur Vercel).

**Backups** : `/home/maxim/piloo/backup-db.sh` en crontab (`0 4 * * *`) —
`pg_dump -Fc` de `piloo-db` vers `/home/maxim/backups/piloo/piloo_<date>.dump`,
rétention 30 jours, log dans `/home/maxim/piloo/logs/backup.log`. Restauration :

```bash
docker exec -i piloo-db pg_restore -U piloo -d piloo --clean --if-exists < piloo_<date>.dump
```
