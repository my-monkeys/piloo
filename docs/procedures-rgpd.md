# Procédure droits RGPD utilisateur

Ce document décrit comment Piloo traite les demandes des utilisateurs liées
au RGPD (articles 15 à 22). Les trois droits clés (accès, rectification,
effacement) sont entièrement **self-service** dans l'app : pas de demande
manuelle, pas de SLA différé, fulfillment immédiat.

## Vue d'ensemble

| Droit RGPD          | Article | Fulfillment                                            | SLA        |
| ------------------- | ------- | ------------------------------------------------------ | ---------- |
| Accès / portabilité | 15, 20  | `POST /api/v1/me/export`                               | Instantané |
| Rectification       | 16      | `PATCH /api/v1/me`                                     | Instantané |
| Effacement          | 17      | `POST /api/v1/me/delete` + cron J+7                    | 7 jours    |
| Limitation          | 18      | `POST /api/v1/me/delete` (suspend l'usage)             | Instantané |
| Opposition          | 21      | Désinscription email/SMS via préférences notifications | Instantané |

## Détail par droit

### Droit d'accès (article 15) + portabilité (article 20)

Endpoint : `POST /api/v1/me/export`

Renvoie en téléchargement immédiat un JSON UTF-8 (`Content-Disposition: attachment`)
contenant :

- compte (id, email, identité, type, dates)
- préférences (notifications, paramètres app)
- devices push enregistrés
- officines détenues, avec contenu intégral : boîtes, ordonnances,
  prescriptions, prises planifiées, partages
- officines partagées (metadata uniquement — pas le contenu, qui est
  la donnée du propriétaire au sens RGPD)
- alertes adressées à l'utilisateur

Le format est documenté via `format_version: "1.0"` dans le payload pour
permettre l'évolution sans casser un dump existant. Détails techniques :
voir `apps/web/lib/me/export.ts`.

### Droit de rectification (article 16)

Endpoint : `PATCH /api/v1/me`

Champs modifiables :

- `nom`, `prenom`, `name` (affichage)
- `telephone` (peut être mis à null pour effacer)
- `image` (avatar)

Champs **non** modifiables par PATCH :

- `email` — passe par le flow Better Auth dédié avec vérification
- `type_compte` — changer particulier ↔ pro implique un re-onboarding
- `id`, `created_at`, etc.

### Droit à l'effacement (article 17)

Endpoints : `POST /api/v1/me/delete` + `POST /api/v1/me/restore`

Workflow :

1. **Demande** : `POST /api/v1/me/delete`
   - Set `users.deleted_at = now()`.
   - Calcule `scheduled_anonymization_at = now() + 7 jours`.
   - Le compte reste fonctionnel pour permettre la restauration.
   - Email de confirmation (#134, dépend Brevo #132 — TODO).

2. **Annulation** (dans la fenêtre 7j) : `POST /api/v1/me/restore`
   - Clear `users.deleted_at` si une demande est en cours.
   - Renvoie 404 sinon.

3. **Anonymisation finale** (cron quotidien `anonymize-accounts`, 5h UTC) :
   - email → `deleted-{uuid}@piloo.local` (reconnexion impossible)
   - nom / prenom / telephone / image / preferences → vidés
   - officines en propre → soft-deletées (les utilisateurs partagés perdent l'accès)
   - sessions + accounts Better Auth → hard-deletés

L'anonymisation est **idempotente** : un compte déjà anonymisé (préfixe
`deleted-` dans l'email) est skip lors d'un re-run.

### Droit à la limitation (article 18)

Le mécanisme de demande de suppression (`POST /api/v1/me/delete`) sert
aussi à la limitation : l'utilisateur peut "suspendre" son usage en
déclenchant la suppression, puis l'annuler à tout moment dans la fenêtre
7 jours.

### Droit d'opposition (article 21)

Endpoint : `PUT /api/v1/me/preferences/notifications`

L'utilisateur peut désactiver canal par canal (push / email / sms) et type
par type (péremption, stock_bas, prise_oubliee, etc.) ses notifications.
Pas d'opt-out global "marketing" car Piloo n'envoie pas de marketing.

## SLA et traçabilité

- **SLA** : tous les droits sont fulfillé en self-service, donc en <1
  seconde (sauf effacement qui est différé volontairement de 7 jours pour
  protéger l'utilisateur contre une suppression accidentelle).
- **Traçabilité** : les actions critiques (demande suppression,
  restauration, anonymisation) sont loggées via `log.info(...)` avec
  `user_id` (jamais l'email ou autre PII). Cf. `apps/web/lib/me/delete.ts`.

## Cas hors self-service

Si un utilisateur demande quelque chose qui n'est pas couvert par les
endpoints (par exemple : suppression d'un item précis sans supprimer tout
le compte, demande pour un mineur, demande post-décès), il doit écrire à
`contact@piloo.fr` (ou l'adresse DPO quand elle existera).

Délai légal max RGPD : **1 mois** à compter de la réception de la demande.
Pour ces cas hors self-service, le délai sera tenu manuellement.

## Vérification d'identité

Les endpoints self-service exigent une session Better Auth valide
(`requireAuth`), ce qui constitue la vérification d'identité (article 12.6).
Pas de vérification additionnelle nécessaire.

## Audit (futur)

Un endpoint admin de log des demandes RGPD pourra être ajouté quand le
volume de demandes hors self-service le justifiera. Pour l'instant, les
logs serveur sont la trace officielle.

## Références

- [Texte RGPD officiel](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [Guide CNIL pour les responsables de traitement](https://www.cnil.fr/fr/comprendre-le-rgpd)
- PRs implémentation : #307 (export #158), #308 (suppression #159),
  #309 (rectification + procédure #162)
