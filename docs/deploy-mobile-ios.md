# Déploiement mobile iOS — Codemagic + TestFlight

Doc opérateur du pipeline iOS de Piloo. Couvre le `codemagic.yaml`, les certificats et secrets nécessaires, et le runbook de release.

> **Stack** : Codemagic (cf. ADR `docs/adr/0002-flutter-ci.md`).
> **Trigger** : tag git `v*` (format strict `vX.Y.Z`).
> **Sortie** : build TestFlight, distribué au beta group `Piloo Internes`.

---

## Vue d'ensemble du pipeline

Workflow `ios-testflight` défini dans `codemagic.yaml` (à la racine du repo — Codemagic n'accepte que cet emplacement, les commandes Flutter utilisent `working_directory: apps/mobile`) :

1. **Trigger** — push d'un tag matchant `v*` sur le repo (ex. `git tag v0.3.1 && git push origin v0.3.1`).
2. **Validation tag** — refus si le tag ne matche pas `^v[0-9]+\.[0-9]+\.[0-9]+$`.
3. **Versioning** — `version: X.Y.Z+<BUILD_NUMBER>` injecté dans `pubspec.yaml` (build number monotone fourni par Codemagic, garantit l'unicité côté App Store).
4. **Build** — `flutter pub get`, génération de code (`build_runner` si présent), `flutter analyze`, `flutter test`, puis `flutter build ipa --release` signé.
5. **Signing** — auto via App Store Connect API (Codemagic `keychain` + `app-store-connect fetch-signing-files`).
6. **Upload** — `submit_to_testflight: true` vers le beta group `Piloo Internes`.

Un workflow secondaire `ios-pr-check` exécute `flutter analyze` + `flutter test` sur les PR (pas de build, pas de signing).

---

## Pré-requis Apple (one-time setup)

À faire **une fois** avant d'attendre un build vert. Tout passe par [App Store Connect](https://appstoreconnect.apple.com/) avec un Apple ID disposant des bons rôles.

### 1. Apple Developer Program

- Compte payant **Apple Developer Program** actif (99 $/an), team `Piloo`.
- Rôle requis pour le titulaire : **Account Holder** ou **Admin**.
- Note : un compte **Individual** suffit techniquement pour TestFlight, mais on recommande **Organization** dès qu'on a une entité légale (HDS, factures pro).

### 2. App Store Connect — création de l'app

- App déclarée dans App Store Connect avec :
  - **Bundle ID** : `app.piloo.mobile` (doit matcher `BUNDLE_ID` dans `codemagic.yaml` et `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`).
  - **SKU** : `piloo-mobile-ios`.
  - **Plateforme** : iOS.
- Le bundle ID doit aussi exister côté **Certificates, Identifiers & Profiles** (auto-créé via App Store Connect API si absent — cf. `--create` dans le script de signing).

### 3. Beta group TestFlight

- Créer le beta group `Piloo Internes` dans App Store Connect → TestFlight → Internal Testing.
- Y inviter manuellement les testeurs (max 100 internes, 10 000 externes).
- Le nom doit matcher exactement la valeur `beta_groups` dans `codemagic.yaml`. Si tu le renommes, sync les deux.

---

## Certificats & secrets requis

Tous les secrets sont stockés **dans le vault Codemagic** (UI : `Teams → Piloo → Environment variables`). **Aucun secret iOS ne doit atterrir dans `.env`, dans le repo ou dans GitHub Secrets.**

Deux groupes de variables :

### Groupe `app_store_credentials` — App Store Connect API

Crée une **API key** dans App Store Connect → Users and Access → Keys → App Store Connect API.

| Variable Codemagic                 | Source                                               | Description                                                                |
| ---------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------- |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Onglet "Keys" → colonne "Key ID"                     | ID public de la clé (10 caractères, ex. `AB12CD34EF`).                     |
| `APP_STORE_CONNECT_ISSUER_ID`      | Haut de la page "Keys"                               | UUID issuer (ex. `69a6de70-...`).                                          |
| `APP_STORE_CONNECT_PRIVATE_KEY`    | Bouton "Download API Key" → fichier `AuthKey_XXX.p8` | Contenu **brut** du `.p8` (lignes `-----BEGIN PRIVATE KEY-----` incluses). |

Permissions requises sur la clé : **App Manager** minimum (Admin si on veut aussi auto-créer les bundle IDs).

> ⚠️ Le `.p8` n'est téléchargeable **qu'une seule fois**. Si perdu, révoquer + recréer.

### Groupe `ios_signing` — Distribution certificate

Codemagic peut auto-générer le distribution certificate si on lui fournit la clé privée associée.

| Variable Codemagic        | Source                                              | Description                                                                                                  |
| ------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `CERTIFICATE_PRIVATE_KEY` | `openssl genrsa -out cert_key.pem 2048` puis upload | Clé RSA privée 2048 bits. Codemagic l'utilise pour générer/réutiliser le distribution certificate via l'API. |

Procédure de génération initiale :

```bash
# Sur une machine de confiance (ne PAS commiter le résultat)
openssl genrsa -out piloo_ios_distribution.key 2048
# Coller le contenu dans Codemagic → Environment variables → group ios_signing
# CERTIFICATE_PRIVATE_KEY = <contenu de piloo_ios_distribution.key>
```

### Intégration App Store Connect (Codemagic)

Côté UI Codemagic :

1. `Teams → Piloo → Integrations → Apple Developer Portal`.
2. Add API key, nom interne : **`piloo_appstore_api_key`** (doit matcher la ligne `app_store_connect: piloo_appstore_api_key` du yaml).
3. Coller `Issuer ID`, `Key ID`, et upload le `.p8`.

---

## Le `provisioning profile`, le `certificat`, qui fait quoi ?

| Élément                                            | À qui ça sert                                                                   | Géré par                                                   |
| -------------------------------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **API key App Store Connect** (`.p8`)              | Authentifier la CI auprès d'Apple pour fetch certs/profiles, upload TestFlight. | Toi (one-time setup).                                      |
| **Distribution certificate** (`.cer` + clé privée) | Signer l'IPA. Valide ~1 an, renouvelé auto par Codemagic.                       | Codemagic via `CERTIFICATE_PRIVATE_KEY`.                   |
| **Provisioning profile** (`.mobileprovision`)      | Lier `certificate × bundle_id × entitlements × type=AppStore`.                  | Auto via `app-store-connect fetch-signing-files --create`. |
| **App-Specific Password**                          | Non utilisé (Codemagic se passe de l'Apple ID password grâce à l'API key).      | —                                                          |

À retenir : avec l'API key, **on n'a JAMAIS à manipuler l'Apple ID + 2FA dans la CI**. C'est l'avantage majeur vs `fastlane match`.

---

## Runbook de release

### Release standard

```bash
# 1. Branche main propre + tests verts en local.
git checkout main
git pull --rebase
pnpm test          # côté backend/web
cd apps/mobile && flutter test && cd ../..

# 2. Tagger.
git tag v0.4.0
git push origin v0.4.0

# 3. Suivre le build : https://codemagic.io/app/<APP_ID>/builds
#    Durée typique : 8–12 min sur mac_mini_m2.

# 4. Une fois le build vert, le binaire apparaît dans App Store Connect → TestFlight (Processing ~5–15 min).
#    Apple envoie un mail aux testeurs internes.
```

### Release "demo navigator" (boot direct sur /\_dev)

Variante du workflow standard qui produit un build dont l'app boote directement sur `DevHomeScreen` (la liste cliquable des 32 écrans M1). Utile pour faire tourner sur device / présenter le produit sans avoir besoin de backend, de session ou de compléter l'onboarding.

```bash
# 1. Idem release standard pour la propreté du repo.
git checkout main && git pull --rebase

# 2. Tag avec le suffixe `-demo`. Le format reste vX.Y.Z-demo.
git tag v0.1.0-demo
git push origin v0.1.0-demo
```

Différences avec le workflow `ios-testflight` :

- Déclenché par `v*-demo` (les tags `v*` simples sont au contraire **exclus** de ce workflow et continuent d'être pris par `ios-testflight`).
- Build avec `--dart-define=PILOO_BOOT_ROUTE=/_dev`. Au lancement, l'app contourne le splash et atterrit sur la liste des écrans.
- Distribué au beta group **`Piloo Demos`** (pas `Piloo Internes`) pour ne pas envoyer un build navigateur aux testeurs habitués aux builds prod par erreur.
- Versioning : on retire le suffixe `-demo` du tag avant de l'écrire dans `pubspec.yaml` (Apple n'accepte que des semver stricts). Le `build_number` Codemagic incrémente quand même → pas de collision avec les builds prod de la même version.

Pré-requis Codemagic UI : créer le beta group **"Piloo Demos"** dans App Store Connect → TestFlight → Internal Testing **avant** de tagger, sinon `submit_to_testflight` échoue.

### En cas d'échec

| Symptôme                                                        | Diagnostic                                                                                                                                                                   |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `❌ Tag invalide` au début du build                             | Tag mal formé (ex. `v0.4` au lieu de `v0.4.0`). Supprimer + retagger : `git tag -d v0.4 && git push origin :refs/tags/v0.4`.                                                 |
| `app-store-connect: 401 Unauthorized`                           | API key révoquée / mauvais Issuer ID. Régénérer et mettre à jour `app_store_credentials`.                                                                                    |
| `No matching provisioning profiles found` + impossible de créer | API key sans permission `App Manager` ou bundle ID inexistant côté Apple.                                                                                                    |
| Build OK mais TestFlight ne reçoit rien                         | Vérifier App Store Connect → TestFlight → onglet "Builds" : status `Invalid Binary` (ITMS-91056 et co.) → consulter le log Codemagic, corriger plist/entitlements, retagger. |
| `submit_to_testflight: true` mais le beta group ne reçoit pas   | Le nom du beta_groups dans le yaml ne matche pas exactement le nom dans App Store Connect.                                                                                   |

### Rollback

TestFlight ne supporte pas de "rollback" d'un build (un build s'invalide naturellement après expiration). Pour redonner la dernière version stable aux testeurs :

```bash
# Créer un nouveau tag pointant sur le commit stable précédent.
git tag v0.4.1 <sha-du-commit-stable>
git push origin v0.4.1
# Le nouveau build remplacera le buggué côté testeurs.
```

---

## Rotation & expiration

| Item                           | Validité                                                              | Procédure de rotation                                                                                                                                                                                                  |
| ------------------------------ | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Distribution certificate iOS   | 1 an                                                                  | Codemagic le régénère auto si `CERTIFICATE_PRIVATE_KEY` est toujours valide. Si la clé doit changer (compromission) : générer une nouvelle clé, mettre à jour le secret, supprimer l'ancien cert dans Apple Developer. |
| Provisioning profile App Store | 1 an                                                                  | Auto-renouvelé à chaque build par `fetch-signing-files`.                                                                                                                                                               |
| API key App Store Connect      | Pas d'expiration auto, mais **rotation conseillée tous les 12 mois**. | Créer une nouvelle clé, mettre à jour les 3 variables `APP_STORE_CONNECT_*` côté Codemagic, vérifier qu'un build marche, puis révoquer l'ancienne.                                                                     |
| Apple Developer Program        | 1 an                                                                  | Renouveler côté Apple. Si expiré : tous les builds échouent + l'app peut être retirée de l'App Store.                                                                                                                  |

> Inscrire ces dates dans le calendrier d'équipe. Une expiration silencieuse est le scénario d'échec n°1 sur les pipelines iOS.

---

## Liens utiles

- ADR Codemagic : `docs/adr/0002-flutter-ci.md`.
- Pipeline : `codemagic.yaml` (racine du repo).
- Codemagic docs — code signing iOS : <https://docs.codemagic.io/yaml-code-signing/signing-ios/>.
- Codemagic docs — App Store Connect publishing : <https://docs.codemagic.io/yaml-publishing/app-store-connect/>.
- Apple — App Store Connect API : <https://developer.apple.com/documentation/appstoreconnectapi>.
