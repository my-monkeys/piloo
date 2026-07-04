# Design — Support fuseau horaire réel pour les prises (#363)

**Date** : 2026-07-03
**Ticket** : #363
**Statut** : validé (brainstorming)

## Problème

Un rappel posé sur un moment (ex. « coucher » à 22:00) apparaît dans le mauvais
créneau sur l'app mobile : « coucher » → affiché en **Matin**, « soir » → affiché
en **Coucher**. Le décalage est visible **en été** (UTC+2) et invisible en hiver
(UTC+1 ne franchit pas les frontières de créneaux) — signature d'un bug de fuseau.

### Cause racine

Deux couches ont des modèles de temps incompatibles :

- **Serveur** (`apps/web/lib/prises/generate.ts`, `composeDatetime`) : les heures
  murales par défaut (matin 08:00, midi 12:00, soir 19:00, coucher 22:00) sont
  écrites comme **UTC** via `setUTCHours`. Toute la logique serveur assume
  « heure serveur = Europe/Paris traité comme UTC » (documenté comme provisoire
  dans `serialize.ts`, TODO multi-tz).
- **Mobile** (`apps/mobile/lib/features/today/presentation/today_screen.dart`,
  `_groupByMoment`) : la prise est reconvertie dans le fuseau **du téléphone**
  (`.toLocal()`) avant d'être rangée dans un créneau et affichée.

Résultat en UTC+2 : coucher 22:00Z → `toLocal` 00:00 → créneau `< 12` = **Matin** ;
soir 19:00Z → `toLocal` 21:00 → créneau `_` = **Coucher**.

## Décision

`datetime_prevue` devient un **vrai instant UTC**. Chaque **officine** porte un
**fuseau IANA** (`Europe/Paris` par défaut). Le serveur convertit _heure murale
officine → instant UTC_ à la génération ; le mobile fait l'inverse (instant UTC →
heure murale officine) à l'affichage, **quel que soit le fuseau du téléphone**.

Décisions produit (brainstorming) :

1. Le fuseau vit **par officine** (chaque carnet = un patient qui vit quelque part ;
   un pro/proche à l'étranger voit chaque patient à SON heure locale).
2. Le mobile affiche **toujours dans le fuseau de l'officine** (cas pro/proche géré),
   pas dans celui du téléphone.
3. Le fuseau est **déduit du téléphone à la création** de l'officine, `Europe/Paris`
   par défaut pour les existantes, et **modifiable via un picker** dans les réglages
   de l'officine.

Faisabilité : le mobile a **déjà** `timezone` (base tz) et `flutter_timezone`
(les notifs les utilisent) → pas de nouvelle dépendance. Le serveur n'a pas de lib
tz mais Node fournit `Intl` (IANA, DST-aware) → conversion via un petit helper testé,
sans dépendance.

## Composants & flux

### 1. Schéma (`packages/db-schema`)

- Nouvelle colonne `officines.timezone` : `text NOT NULL DEFAULT 'Europe/Paris'`.
- Migration Drizzle : ajoute la colonne, backfill implicite via le `DEFAULT` pour
  toutes les officines existantes.
- Contrainte de validité : le fuseau est une chaîne IANA validée à la frontière
  (Zod côté API) — pas de contrainte DB (une CHECK sur la liste IANA serait fragile).

### 2. Serveur — helper de conversion (nouveau, `apps/web/lib/prises/timezone.ts`)

- `zonedWallClockToUtc(year, month, day, hours, minutes, timeZone): Date`
  — compose une heure murale dans `timeZone` et retourne l'instant UTC correspondant.
  Implémentation via `Intl.DateTimeFormat` (calcul de l'offset du fuseau à cette
  date, DST-aware). Gère les cas limites DST (gap de printemps = choisit l'instant
  post-transition ; overlap d'automne = choisit la première occurrence) de façon
  déterministe et documentée.
- `utcToZonedParts(instant, timeZone): { hour, minute, ... }` — pour le bucketing
  serveur (voir §4). Basé sur `Intl.DateTimeFormat().formatToParts`.

### 3. Serveur — génération (`apps/web/lib/prises/generate.ts`)

- `composeDatetime` prend un `timeZone` et compose l'instant via
  `zonedWallClockToUtc` au lieu de `setUTCHours`.
- `GenerateOptions`, `WindowGenerateOptions`, `RappelGenerateOptions` gagnent un
  champ `timeZone: string`.
- Les 3 générateurs (`generatePrisesForPrescription/Window/Rappel`) le propagent.
- Les routes appelantes (`app/api/v1/officines/[officineId]/rappels/route.ts`,
  les routes prescriptions, le cron `lib/prises/cron-glissant.ts`) lisent
  `officine.timezone` et le passent.

### 4. Serveur — mapping quantité (`apps/web/lib/prises/serialize.ts`)

- `rappelQuantityForDatetime` bucketait sur `prise.datetimePrevue.getUTCHours()`.
  Comme l'instant est désormais un vrai instant UTC, on convertit d'abord en heure
  **locale officine** (`utcToZonedParts(prise.datetimePrevue, officine.timezone)`)
  puis on bucket sur cette heure. La signature reçoit le fuseau (via l'officine).

### 5. Contrat API (`packages/api-contract`)

- Ajoute `timezone: z.string()` au schéma `Officine` (et à l'input de mise à jour
  d'officine pour le PATCH du picker).
- Régénère OpenAPI (`pnpm openapi:generate`) + le client Dart généré
  (`lib/gen/openapi`).

### 6. Mobile — affichage (`today_screen.dart`)

- Le fuseau de l'officine active est disponible via `activeOfficineProvider`
  (l'`Officine` porte maintenant `timezone`).
- `_groupByMoment` et `_mapApiPrise` : remplacent `.toLocal()` par
  `tz.TZDateTime.from(instant, tz.getLocation(officine.timezone))` pour le
  bucketing des créneaux **et** le libellé d'heure.
- `_onPriseLongPress` (édition d'horaire) : le picker présente l'heure en tz
  officine ; l'heure murale choisie est convertie tz officine → UTC avant l'envoi
  (`TZDateTime` dans la location officine puis `.toUtc()`).

### 7. Mobile — réglage du fuseau

- Création d'officine (`activeOfficineProvider._resolve`, officine « Maison »
  auto) : envoie le fuseau **de l'appareil** via `flutter_timezone`
  (`FlutterTimezone.getLocalTimezone()`).
- Écran **Réglages officine** (`RoutePath.officineSettings`, aujourd'hui un
  `PlaceholderScreen`) : sélecteur de fuseau (liste IANA depuis la base `timezone`,
  recherche/filtre), PATCH `timezone` sur l'officine. Après changement, invalide
  les prises du jour pour réafficher aux bons créneaux.

### 8. Migration des prises existantes

- Script de backfill **one-shot** (lancé post-deploy, à la main comme les
  migrations) : pour chaque rappel/prescription actif, supprime les prises
  **futures au statut `prevue`** et les régénère avec le fuseau de l'officine
  (Europe/Paris par défaut). Les prises **passées ou validées** (prise/sautée/
  oubliée) ne sont pas touchées (historique).
- Idempotent : re-run ne régénère que ce qui existe encore comme `prevue` future.

### 9. Notifications (`apps/mobile/lib/shared/notifications/notifications_service.dart`)

- `scheduleForPrises` planifie déjà via `tz.TZDateTime` à l'instant réel → correct
  une fois les instants vrais stockés (l'alarme sonne au bon moment absolu quel que
  soit le fuseau du téléphone).
- Le **libellé d'heure** de la notification passe en tz officine (cohérent avec
  l'affichage timeline).

## Modèle de données / invariants

- `datetime_prevue` (`timestamptz`) = **vrai instant UTC**. Ne jamais y écrire une
  heure murale « telle quelle ».
- `officines.timezone` = nom IANA valide. Source de vérité de l'affichage et de la
  planification des prises de cette officine.
- Les frontières de créneaux existantes s'appliquent désormais sur l'**heure locale
  officine**, jamais sur l'heure UTC ni l'heure device. Note : les seuils diffèrent
  aujourd'hui entre le serveur (`rappelQuantityForDatetime` : matin `< 10`) et le
  mobile (`< 12`). Ce spec **ne les unifie pas** (hors périmètre) — il change
  seulement la base horaire (UTC → locale officine). Un alignement des seuils est un
  follow-up possible.

## Tests

- **Serveur** :
  - `zonedWallClockToUtc` : été (Europe/Paris +2), hiver (+1), un fuseau non-Paris
    (ex. America/New_York), et les cas limites DST (dernier dimanche de mars/octobre).
  - `generate` : un rappel « coucher » 22:00 en Europe/Paris (été) → instant
    `20:00Z` attendu ; idem prescription/window.
  - `rappelQuantityForDatetime` : instant `20:00Z` en Europe/Paris → bucket coucher.
- **Mobile** :
  - bucketing `today_screen` : instant `20:00Z` + officine Europe/Paris → créneau
    Coucher, libellé « 22:00 », device en UTC **et** device en un autre fuseau
    (mêmes résultats).

## Hors périmètre (follow-ups)

- **Bug clavier** (#364) : modale « Rappel rapide » non scrollable — fix indépendant.
- Persistance des **horaires par moment** de l'utilisateur (`horaires_screen`
  aujourd'hui non câblé au serveur) : orthogonal au fuseau, ticket séparé.
- Historique : re-calage des prises passées (non nécessaire, on garde l'historique
  tel quel).
