# Instructions Claude Code — apps/mobile

Ce dossier contient l'application mobile **Flutter** (iOS + Android).

> Lire `/CLAUDE.md` (racine) et `/docs/architecture.md` avant toute tâche complexe ici.

## ⚠️ Version Flutter — pin 3.38.7 (fvm) (#366)

Le projet est **épinglé sur Flutter 3.38.7** via `.fvmrc`. Raison : `phosphor_flutter`
2.1.0 fait `class PhosphorIconData extends IconData`, or `IconData` est devenue une
classe `final` dans les Flutter plus récents → l'app **ne compile pas** (kernel) sur
un Flutter trop neuf (ex. 3.44+), même si `flutter analyze` passe. 2.1.0 est la
dernière version publiée de phosphor → pas de bump possible.

**Toujours** lancer via fvm : `fvm flutter run`, `fvm flutter pub get`, `fvm dart run
build_runner build`. Les CI (`codemagic.yaml`, `.github/workflows/*mobile*`,
`*android*`) épinglent déjà 3.38.7. Setup : `fvm install` (lit `.fvmrc`).

Fix définitif à terme : migrer vers un set d'icônes compatible Flutter récent (ou
attendre une release phosphor corrigée), puis relever le pin.

## Stack spécifique

- **Flutter 3.x** + Dart
- **Riverpod** (state management)
- **go_router** (navigation)
- **Drift** (SQLite local, ORM typé)
- **Dio** (HTTP) + client généré depuis OpenAPI
- **mobile_scanner** (DataMatrix)
- **freezed** + **json_serializable** (modèles immuables)
- **firebase_messaging** + **flutter_local_notifications**
- **connectivity_plus** (détection réseau pour sync)

## Structure attendue

```
apps/mobile/
├── lib/
│   ├── main.dart
│   ├── app.dart                        → MaterialApp + router
│   ├── core/
│   │   ├── theme/                      → Couleurs, typographie, tokens
│   │   ├── router/                     → go_router config
│   │   ├── errors/                     → Gestion d'erreurs centralisée
│   │   └── utils/
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/                   → Repository, sources
│   │   │   ├── domain/                 → Models, use cases
│   │   │   └── presentation/           → Screens, widgets, providers
│   │   ├── officines/
│   │   ├── boites/
│   │   ├── scan/
│   │   ├── ordonnances/
│   │   ├── prises/
│   │   ├── alertes/
│   │   └── partages/
│   ├── shared/
│   │   ├── widgets/                    → Composants UI réutilisables
│   │   ├── db/                         → Drift setup + migrations
│   │   ├── api/                        → Client Dio + client OpenAPI généré
│   │   ├── sync/                       → Worker de synchronisation
│   │   └── bdpm/                       → Accès DB BDPM locale
│   └── gen/                            → Code généré (freezed, json, openapi)
├── test/                               → Tests unitaires
├── integration_test/                   → Tests E2E
├── android/
├── ios/
├── pubspec.yaml
└── CLAUDE.md                           → ce fichier
```

## Conventions

- **Architecture** : pattern Clean Architecture légère (data / domain / presentation) par feature.
- **State** : Riverpod uniquement. Pas de Provider vanilla, pas de BLoC au MVP.
- **Modèles** : tous les modèles métier sont des classes `freezed` + JSON. Pas de Map<String, dynamic> dans la logique.
- **DB** : Drift pour la base locale métier. Base BDPM chargée séparément en read-only.
- **HTTP** : toujours passer par le client généré OpenAPI, pas d'appel Dio direct ailleurs que dans la couche générée.
- **Naming** : fichiers `snake_case.dart`, classes `PascalCase`, variables `camelCase`.
- **Null safety** : strict, exploiter les types non-nullable partout où possible.

## Offline-first (critique)

**Toute modification utilisateur doit :**

1. Être appliquée immédiatement à la DB locale (Drift).
2. Être ajoutée à la table `pending_operations` avec `statut = 'pending'`.
3. Être propagée par le worker de sync quand réseau disponible.

**Le code ne doit jamais** :

- Bloquer l'UI en attendant une réponse réseau pour une action locale.
- Assumer que le réseau est disponible.
- Utiliser le résultat d'un appel API pour afficher un succès (l'optimistic update se base sur la DB locale).

## Scan DataMatrix

- Utiliser `mobile_scanner` avec le format `BarcodeFormat.dataMatrix`.
- Parsing GS1 : implémenter un parser dans `shared/gs1/` qui gère les AI (01), (10), (17), (21).
- Test sur 10+ boîtes réelles avant de considérer comme fonctionnel.

## BDPM locale

- Chargée au premier lancement depuis un endpoint serveur (`/api/v1/bdpm/version` → URL du fichier).
- Attachée en DB séparée via Drift (read-only).
- Mise à jour mensuelle via diff ou replacement complet.
- Toutes les résolutions CIP13 → infos médicament se font **sans réseau** via cette base.

## Tests

- Tests unitaires sur :
  - Parser GS1
  - Logique de sync (operations log, conflits)
  - Matching BDPM
  - Calculs de stock / prises planifiées
- Tests d'intégration sur les flux critiques (scan → ajout → affichage).

## Notifications

- FCM pour push (via `firebase_messaging`).
- `flutter_local_notifications` pour les rappels de prise programmés localement (même sans réseau).
- Permissions demandées à l'onboarding, pas au premier rappel (meilleur opt-in).

## Points d'attention

- **iOS background fetch** : la sync en background est capricieuse sur iOS. Documenter les limitations connues.
- **Permissions caméra / notifs** : gérer les cas de refus avec des fallbacks UX clairs.
- **Performance** : éviter les rebuilds inutiles, préférer `select` de Riverpod pour limiter le scope des rebuilds.
- **Taille de l'app** : l'inclusion de la BDPM (60-80 Mo) alourdit. Télécharger au 1er lancement plutôt que l'embarquer, sauf si c'est bloquant.

## Ce que Claude Code doit faire avant d'écrire du code ici

1. Lire `/CLAUDE.md` (racine) si pas déjà fait.
2. Lire `/docs/api-contract.md` si la tâche touche à des appels API.
3. Lire `/docs/data-model.md` si la tâche touche à la DB locale.
4. Vérifier si un endpoint existe dans `packages/api-contract/` et utiliser le client généré.
5. Toujours respecter le pattern offline-first.
6. Écrire des tests pour la logique métier significative.
