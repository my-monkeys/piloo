# Contrat API — Piloo

Conventions et référence des endpoints REST. Les schémas précis sont maintenus en Zod dans `packages/api-contract/` et exposés en OpenAPI généré automatiquement (voir `docs/architecture.md` section contrat OpenAPI).

---

## Principes généraux

- **Base URL** : `https://app.piloo.fr/api/v1/` (prod) ou équivalent local/preview.
- **Format** : JSON en entrée/sortie. Content-Type `application/json`.
- **Casing** : snake_case côté API, converti en camelCase côté clients via generators.
- **Auth** :
  - Web : cookie de session HTTPOnly.
  - Mobile : header `Authorization: Bearer <JWT>`.
- **Pagination** : `?limit=N&cursor=X`. Retour inclut `next_cursor` (null = fin).
- **Dates** : toutes les dates sont en ISO 8601 UTC (ex : `2026-04-21T14:30:00Z`).

---

## Format des erreurs

Toutes les erreurs suivent ce format :

```json
{
  "error": {
    "code": "validation_error",
    "message": "Le champ 'email' est requis.",
    "details": {
      "field": "email"
    }
  }
}
```

**Codes d'erreur standards**

| Code HTTP | Code applicatif | Usage |
|---|---|---|
| 400 | `validation_error` | Body/query invalide |
| 401 | `unauthorized` | Token absent/expiré |
| 403 | `forbidden` | Pas les droits sur la ressource |
| 404 | `not_found` | Ressource inexistante ou soft-deleted |
| 409 | `conflict` | Conflit (ex : email déjà utilisé) |
| 422 | `business_rule_error` | Règle métier violée |
| 429 | `rate_limited` | Trop de requêtes |
| 500 | `internal_error` | Erreur serveur non gérée |

---

## Endpoints

### Auth

```
POST   /api/v1/auth/register        → { email, password, nom, prenom, type_compte }
POST   /api/v1/auth/login           → { email, password }
POST   /api/v1/auth/logout
POST   /api/v1/auth/refresh         → { refresh_token }  (mobile)
POST   /api/v1/auth/verify-email    → { token }
POST   /api/v1/auth/forgot-password → { email }
POST   /api/v1/auth/reset-password  → { token, new_password }
GET    /api/v1/auth/me              → profil utilisateur courant
PATCH  /api/v1/auth/me              → mise à jour profil
DELETE /api/v1/auth/me              → suppression compte (grâce 7j)
```

### Officines

```
GET    /api/v1/officines                    → liste des officines accessibles (owned + shared)
POST   /api/v1/officines                    → créer une officine
GET    /api/v1/officines/:id                → détail
PATCH  /api/v1/officines/:id                → update (nom, notes, date_naissance)
DELETE /api/v1/officines/:id                → soft-delete (owner only)
```

### Partages

```
GET    /api/v1/officines/:id/partages       → liste des partages de l'officine
POST   /api/v1/officines/:id/partages       → créer une invitation { email, role }
PATCH  /api/v1/partages/:id                 → modifier le rôle
DELETE /api/v1/partages/:id                 → révoquer (owner only) ou quitter (pour soi)
POST   /api/v1/invitations/:token/accept    → accepter une invitation
```

### Boîtes

```
GET    /api/v1/officines/:id/boites         → liste paginée, filtres query : statut, cip13, groupby=cip13|dci
POST   /api/v1/officines/:id/boites         → créer { cip13, lot, numero_serie, peremption, unites_initiales, unites_restantes }
GET    /api/v1/boites/:id                   → détail (avec infos BDPM jointes)
PATCH  /api/v1/boites/:id                   → update (unites_restantes, statut, notes)
DELETE /api/v1/boites/:id                   → soft-delete

POST   /api/v1/officines/:id/boites/find-by-triplet
                                            → body { cip13, lot, numero_serie }
                                              retourne la boîte existante ou 404
                                              (utilisé avant scan pour popup vs. ajout)
```

### Ordonnances & prescriptions

```
GET    /api/v1/officines/:id/ordonnances    → liste
POST   /api/v1/officines/:id/ordonnances    → créer avec prescriptions imbriquées
GET    /api/v1/ordonnances/:id              → détail avec prescriptions
PATCH  /api/v1/ordonnances/:id              → update
DELETE /api/v1/ordonnances/:id              → soft-delete (cascade prescriptions + prises planifiées)

POST   /api/v1/ordonnances/:id/prescriptions     → ajouter une prescription
PATCH  /api/v1/prescriptions/:id                 → update (régénère les prises futures)
DELETE /api/v1/prescriptions/:id                 → soft-delete
```

### Prises

```
GET    /api/v1/officines/:id/prises?from=YYYY-MM-DD&to=YYYY-MM-DD
                                            → timeline par plage
PATCH  /api/v1/prises/:id                   → update statut (prise/sautee)
POST   /api/v1/prises/:id/reporter          → { delay_minutes }  reporte
```

### Alertes

```
GET    /api/v1/alertes                      → toutes alertes non lues
PATCH  /api/v1/alertes/:id/read             → marquer comme lue
POST   /api/v1/alertes/read-all             → toutes lues
```

### OCR ordonnance (v2 prévu MVP)

```
POST   /api/v1/ocr/ordonnance
       Content-Type: multipart/form-data
       body: image file
       → { raw_text, structured: { prescripteur, date, prescriptions: [...] } }
```

### Synchronisation (mobile)

Les endpoints les plus critiques. Détaillés ci-dessous.

```
POST   /api/v1/sync/push
GET    /api/v1/sync/pull
```

### BDPM

```
GET    /api/v1/bdpm/version                 → { version: "2026-04-01", url: "...sqlite.gz" }
GET    /api/v1/bdpm/search?q=doliprane      → recherche textuelle (fallback si app offline obsolète)
GET    /api/v1/bdpm/medicament/:cip13       → détail médicament + résumé IA
```

### Notifications (config)

```
GET    /api/v1/notifications/preferences    → récupérer prefs utilisateur
PATCH  /api/v1/notifications/preferences    → { push, email, sms, digest_quotidien }
POST   /api/v1/notifications/device         → enregistrer un token FCM { token, platform }
DELETE /api/v1/notifications/device/:token  → désenregistrer
```

---

## Endpoints de sync — détail

### POST /api/v1/sync/push

Envoie un batch d'opérations locales au serveur.

**Request**
```json
{
  "client_id": "uuid-du-device",
  "operations": [
    {
      "id": "uuid-operation-client",
      "type": "create_boite",
      "entity_type": "boite",
      "entity_id": "uuid-entity",
      "payload": { ... },
      "timestamp_local": 1713700000000
    },
    ...
  ]
}
```

**Response 200**
```json
{
  "acks": [
    { "operation_id": "...", "entity_id": "...", "status": "applied" },
    { "operation_id": "...", "entity_id": "...", "status": "conflict", "server_version": { ... } },
    { "operation_id": "...", "entity_id": "...", "status": "rejected", "reason": "forbidden" }
  ],
  "server_time": "2026-04-21T14:30:00Z"
}
```

**Règles**
- Batch max 100 opérations.
- Chaque opération est idempotente (rejouer ne modifie pas l'état).
- En cas de conflit, le serveur gagne (last-write-wins serveur), le client resolver met à jour sa copie locale au prochain pull.

### GET /api/v1/sync/pull

Récupère les modifs serveur postérieures à un timestamp.

**Query params**
- `since` : ISO timestamp du dernier pull réussi
- `limit` : max 500 (défaut 200)
- `cursor` : pagination

**Response 200**
```json
{
  "entities": {
    "boites": [...],
    "ordonnances": [...],
    "prescriptions": [...],
    "prises_planifiees": [...],
    "alertes": [...],
    "partages": [...]
  },
  "deleted": {
    "boites": ["uuid1", "uuid2"],
    ...
  },
  "server_time": "2026-04-21T14:30:00Z",
  "next_cursor": "..."
}
```

**Règles**
- Renvoie uniquement les entités que l'utilisateur peut voir (filtrage d'autorisation serveur-side).
- Les entités marquées `deleted_at` sont retournées dans `deleted[]`, pas dans `entities[]`.
- Le client est responsable d'appliquer les deletes en local (soft ou hard selon stratégie).

---

## Schémas Zod (exemple)

Côté `packages/api-contract/`, chaque endpoint a ses schémas d'entrée et de sortie, source de vérité du contrat. Exemple :

```ts
// packages/api-contract/src/boites.ts
import { z } from 'zod';

export const BoiteSchema = z.object({
  id: z.string().uuid(),
  officine_id: z.string().uuid(),
  cip13: z.string().length(13),
  lot: z.string().nullable(),
  numero_serie: z.string().nullable(),
  peremption: z.string().date(),
  unites_initiales: z.number().int().positive().nullable(),
  unites_restantes: z.number().int().min(0).nullable(),
  statut: z.enum(['active', 'vide', 'perimee']),
  notes: z.string().nullable(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export const CreateBoiteInputSchema = BoiteSchema.pick({
  cip13: true,
  lot: true,
  numero_serie: true,
  peremption: true,
  unites_initiales: true,
  unites_restantes: true,
  notes: true,
});

export type Boite = z.infer<typeof BoiteSchema>;
export type CreateBoiteInput = z.infer<typeof CreateBoiteInputSchema>;
```

Ces schémas sont ensuite :
- Utilisés par les routes Next.js pour valider les requêtes (`schema.parse(body)`).
- Utilisés par le front web via `z.infer`.
- Exportés en OpenAPI via `zod-to-openapi`.
- Utilisés pour générer le client Dart via `openapi-generator`.

---

## Versioning

- La version est dans l'URL (`/api/v1/...`).
- Une future `/api/v2/...` cohabitera avec v1 pendant la période de transition.
- Les breaking changes (renommage de champ, suppression d'endpoint) bumpent la version majeure.
- Les additions non-breaking se font dans la version courante.

---

## Rate limiting

| Route | Limite |
|---|---|
| `/auth/login`, `/auth/register` | 10 req/min par IP |
| `/auth/forgot-password` | 3 req/h par email |
| `/sync/push` | 120 req/min par user |
| `/sync/pull` | 60 req/min par user |
| Autres routes authentifiées | 600 req/min par user |

Retour 429 avec header `Retry-After`.
