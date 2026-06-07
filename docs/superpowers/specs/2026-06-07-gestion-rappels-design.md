# Design — Gestion des rappels (« Mes rappels »)

- **Date** : 2026-06-07
- **Statut** : validé (brainstorming) → à implémenter
- **Plateformes** : mobile (Flutter) + web (Next.js)

## Contexte & problème

Les rappels rapides (`rappels`) se **créent** depuis une boîte de l'inventaire (quick-sheet, `#98`/`#343`) et génèrent des `prises_planifiees`. Mais il n'existe **aucune surface pour gérer les rappels déjà créés** : impossible de les lister, les éditer, les mettre en pause ou les supprimer depuis l'app.

L'API CRUD est **déjà complète** : `GET/POST /v1/officines/{id}/rappels`, `GET/PATCH/DELETE /v1/rappels/{id}` (le PATCH gère `actif`, quantités, dates, notes ; le DELETE est un soft-delete). Côté mobile, `rappelsProvider` **liste déjà** les rappels par officine. Le manque est donc surtout **UI + câblage des mutations**, plus une **réconciliation des prises** côté backend (voir §5).

## Périmètre

**Inclus**

- Écran « Mes rappels » : liste des rappels de l'officine active.
- Opérations : voir / mettre en pause–réactiver / modifier / supprimer.
- Réconciliation des `prises_planifiees` futures sur pause/édition/suppression.
- Mobile + web.

**Exclus (non-goals)**

- Création de rappel (reste depuis l'inventaire, inchangée).
- Offline-first mobile pour les mutations rappels (cohérent avec le ship actuel : `rappels_provider` est online-only ; un enqueue suivra avec le worker de sync).
- Toute logique clinique (positionnement carnet, pas dispositif médical).

## Décisions (issues du brainstorming)

| Sujet                 | Décision                                                              |
| --------------------- | --------------------------------------------------------------------- |
| Plateformes           | Mobile **et** web                                                     |
| Opérations            | Voir + pause/réactiver + modifier + supprimer                         |
| Point d'entrée mobile | `Plus` → section _MON APP_ → **« Mes rappels »**, après _Ordonnances_ |
| Point d'entrée web    | Sidebar, item **« Rappels »** après _Ordonnances_                     |
| Formulaire d'édition  | **Formulaire partagé create/edit** (refactor de la quick-sheet)       |
| Prises                | **Réconcilier les prises futures** sur pause/édition/suppression      |

## Architecture

### 1. Points d'entrée

- **Mobile** : ajouter une `_Row` « Mes rappels » (icône cloche) dans `_monAppRows` de `more_screen.dart`, après _Ordonnances_ ; nouvelle `RouteName.rappels` + route go_router → `RappelsScreen`.
- **Web** : ajouter `{ href: '/rappels', label: 'Rappels' }` à `NAV_TOP` (sidebar) après _Ordonnances_ ; nouvelle page `app/(app)/rappels/page.tsx` (client component, `$api`).

### 2. Écran liste (officine active)

- Source : `GET /v1/officines/{officineId}/rappels` (existant).
- Carte / row par rappel :
  - **Nom** du médicament (`nomTexte`).
  - **Résumé horaires** : moments cochés + quantités, ex. « Matin 1 · Soir 2 » (unité du rappel).
  - **Période** : « Depuis le 12 mai » (date_fin null) ou « 12 mai → 19 mai ».
  - **Pastille statut** : _Actif_ / _En pause_ (`actif`).
- Tri : actifs d'abord, puis en pause ; secondaire par `nomTexte`.
- **Empty state** : « Aucun rappel — crée-en un depuis une boîte de ton inventaire. » + lien inventaire.
- **Viewer** : lecture seule (actions de mutation masquées).

### 3. Interactions

- **Pause / Réactiver** : toggle inline (Switch) → `PATCH {actif}`.
- **Modifier** : tap carte → formulaire pré-rempli (sheet mobile / dialog web) → `PATCH`.
- **Supprimer** : swipe/overflow (mobile) ou bouton (web) → **confirmation explicite** → `DELETE`.

### 4. Formulaire partagé create/edit

Refactorer `rappel_quick_sheet.dart` en `RappelFormSheet` à deux modes :

- **Création** (existant) : vide, `dateDebut = today`, durée via pills (`RappelDuree`).
- **Édition** : pré-rempli depuis le `Rappel` (quantités, unité, dates, notes). Ajoute un champ **notes** et la saisie de **dates explicites** (en plus des pills de durée) — bénéficie aussi à la création.
  Les widgets `_MomentRow` / `_QtyStepper` / `_DureeSelector` sont réutilisés tels quels.
  Web : un `RappelForm` (dialog) avec les mêmes champs.

### 5. Réconciliation des prises (backend)

**Constat actuel** : `PATCH`/`DELETE` d'un rappel **ne touchent pas** `prises_planifiees`. Conséquence sans correctif : un rappel en pause/supprimé continue de générer des entrées de timeline et des notifications.

**Comportement cible** — on ne touche QUE les prises **futures non encore prises** d'un rappel, définies par :
`prises_planifiees WHERE rappel_id = X AND statut = 'prevue' AND datetime_prevue >= now()`
(les prises passées ou déjà `prise`/`sautee` sont préservées — historique intact).

- **Suppression** (`DELETE`, soft-delete du rappel) → retirer (soft-delete) les prises futures du rappel.
- **Pause** (`PATCH actif=false`) → retirer les prises futures.
- **Réactivation** (`PATCH actif=true`) → retirer les prises futures puis **régénérer** sur la fenêtre initiale (réutiliser `generatePrisesForRappel` + `INITIAL_WINDOW_DAYS = 30`, borné par `dateFin`). Le cron de génération glissante (`#108`) prend le relais au-delà.
- **Édition** d'un rappel **actif** modifiant les horaires (quantités/moments) ou les dates → retirer les prises futures puis régénérer. Une édition ne touchant que `notes`/`unite` n'entraîne **pas** de régénération.

Implémentation : logique transactionnelle dans `lib/rappels/repo.ts` (ou un service `lib/rappels/reconcile-prises.ts`) appelée par les handlers `PATCH`/`DELETE`. Réutiliser `generatePrisesForRappel` (déjà pur) et le pattern du `POST /rappels`.

### 6. Câblage data

- **API** : GET/PATCH/DELETE existants. Ajout : réconciliation des prises dans PATCH/DELETE (§5).
- **Mobile** (`rappels_provider.dart`) : ajouter `updateRappel`, `deleteRappel`, `toggleRappelActif` (appellent `v1RappelsIdPatch` / `v1RappelsIdDelete` du client généré), puis invalider `rappelsProvider(officineId)` **et** `prisesDayProvider` (comme `createRappel`).
- **Web** : `$api.useMutation('patch'|'delete', '/v1/rappels/{id}')` + invalidation des queries `/v1/officines/{id}/rappels` et `/v1/prises/...`.

### 7. Rôles & i18n

- Mutations réservées **owner + editor** (déjà imposé par l'API : PATCH/DELETE exigent `['owner','editor']`). **Viewer** : lecture seule, actions masquées.
- Toutes les chaînes visibles via clés i18n (FR au MVP), pas de hardcode.

## Tests

- **Backend (vitest)** : réconciliation des prises — pause retire le futur ; suppression retire le futur ; édition d'horaires régénère ; les prises passées/`prise` sont préservées ; édition notes-only ne régénère pas.
- **Mobile (unit)** : `updateRappel` / `deleteRappel` / `toggleRappelActif` (statuts, invalidations).
- Pas de course aux tests UI (cf. CLAUDE.md).

## Découpage suggéré (pour le plan)

1. Backend : réconciliation des prises (PATCH/DELETE) + tests.
2. Mobile : mutations provider + `RappelsScreen` + entrée _Plus_ + refactor `RappelFormSheet` (édition).
3. Web : page `/rappels` + entrée sidebar + form d'édition + mutations `$api`.

## Suivis / hors scope

- Offline-first des mutations rappels (enqueue dans `pending_operations`) quand le worker de sync supportera l'entité.
- Création de rappel hors inventaire (non demandé).

## Workflow

Conformément au `CLAUDE.md` projet : créer un **ticket GitHub** avant l'implémentation, brancher `feat/<num>-gestion-rappels`, PR avec `Closes #<num>`.
