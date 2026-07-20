# Déploiement mobile iOS — GitHub Actions + TestFlight

Doc opérateur du pipeline iOS de Piloo. Couvre `.github/workflows/build-ios.yml`, les certificats et secrets nécessaires, et le runbook de release.

> **Stack** : GitHub Actions + fastlane (cf. ADR `docs/adr/0005-github-actions-ios.md`, remplace Codemagic).
> **Trigger** : tag git `v*` (format strict `vX.Y.Z`, hors `v*-demo`) ou bouton « Run workflow ».
> **Sortie** : build signé uploadé sur TestFlight.

---

## Vue d'ensemble du pipeline

Workflow `build-ios` (`.github/workflows/build-ios.yml`), runner `macos-latest` (Xcode GM du runner — jamais de beta, c'est ce qui a débloqué l'ITMS-90111) :

1. **Trigger** — push d'un tag `vX.Y.Z` (ex. `git tag v0.2.0 && git push origin v0.2.0`), ou `workflow_dispatch`.
2. **Versioning** — sur tag : `version: X.Y.Z+<epoch>` injecté dans `pubspec.yaml` (build number epoch Unix, croissant → unicité TestFlight). En dispatch : build-name du pubspec conservé, seul le build number est remplacé. Tag mal formé → échec immédiat.
3. **Client Dart OpenAPI** — `piloo_api_client` (gitignoré) régénéré via `pnpm openapi:generate-dart-client` (Java 17 + Node 22 + pnpm), sinon `flutter pub get` échoue.
4. **Qualité** — `flutter analyze --no-fatal-infos` + `flutter test` avant le build signé (fail fast).
5. **Signing** — certificat de distribution importé dans un trousseau dédié depuis les GitHub Secrets ; profil App Store « Piloo App Store CI » créé/récupéré par fastlane via la clé API App Store Connect (signature **manuelle** à l'export — évite l'erreur « Cloud signing permission »).
6. **Upload** — `fastlane beta` (`apps/mobile/ios/fastlane/`) : `build_app` + `upload_to_testflight`. L'IPA est aussi archivée en artefact du run.

Flutter est épinglé **3.38.7** (phosphor_flutter vs `IconData final`, cf. `apps/mobile/CLAUDE.md`). Les checks PR (analyze + test) vivent dans `mobile-ci.yml` ; l'Android release (APK signé sur GitHub Releases) dans `android-release.yml`, déclenché par le même tag `v*`.

---

## Pré-requis Apple (one-time setup — déjà en place)

- **Apple Developer Program** actif, team `5C67TFSJ2B` (Maxim Costa).
- App déclarée dans App Store Connect : bundle ID `fr.mymonkey.piloo` (cf. `apps/mobile/ios/fastlane/Appfile`).
- **Clé API App Store Connect** : key ID `4SD3G5C575`, rôle App Manager (la même que la recette de build local, cf. mémoire projet).

## Secrets GitHub requis (repo → Settings → Secrets → Actions)

| Secret                     | Description                                                                                                          |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `ASC_KEY_ID`               | Key ID de la clé API App Store Connect (`4SD3G5C575`).                                                               |
| `ASC_ISSUER_ID`            | Issuer ID App Store Connect (UUID).                                                                                  |
| `ASC_KEY_P8_BASE64`        | Contenu du `AuthKey_<ID>.p8` en base64. ⚠️ Le `.p8` n'est téléchargeable qu'une fois.                                |
| `IOS_DIST_CERT_P12_BASE64` | Certificat « Apple Distribution » + clé privée, export PKCS12 en base64 (`security export -t identities -f pkcs12`). |
| `IOS_DIST_CERT_PASSWORD`   | Mot de passe du `.p12`.                                                                                              |
| `IOS_KEYCHAIN_PASSWORD`    | Mot de passe arbitraire du trousseau temporaire du runner.                                                           |

Avec la clé API, **on ne manipule jamais l'Apple ID + 2FA dans la CI**.

---

## Runbook de release

```bash
# 1. main propre + CI verte.
git checkout main && git pull --rebase

# 2. Tagger (déclenche iOS TestFlight + Android APK).
git tag v0.2.0
git push origin v0.2.0

# 3. Suivre : gh run watch  (ou gh run list --workflow=build-ios.yml)
#    Durée typique : ~10-12 min.

# 4. Build vert → App Store Connect → TestFlight (Processing ~5-15 min).
```

Pour un build hors release : onglet Actions → « Build iOS » → « Run workflow » (garde la version du pubspec, build number epoch).

### En cas d'échec

| Symptôme                                  | Diagnostic                                                                                                                              |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `❌ Tag invalide`                         | Tag mal formé (`v0.4` au lieu de `v0.4.0`). Supprimer + retagger.                                                                       |
| `could not find package piloo_api_client` | La génération du client Dart a échoué en amont — voir le step « Generate Dart OpenAPI client ».                                         |
| `401 Unauthorized` (fastlane/ASC)         | Clé API révoquée / mauvais issuer → régénérer, mettre à jour les secrets `ASC_*`.                                                       |
| Erreur de signature / profil              | Vérifier que le cert du `.p12` n'est pas expiré et que le profil « Piloo App Store CI » existe (fastlane le recrée avec `force: true`). |
| Build vert mais rien dans TestFlight      | ASC → TestFlight → Builds : status `Invalid Binary` (ITMS-xxxxx) → lire le mail d'Apple, corriger, retagger.                            |

### Rollback

TestFlight ne « rollback » pas : retagger un nouveau `vX.Y.Z+1` sur le dernier commit stable.

---

## Rotation & expiration

| Item                      | Validité                                       | Rotation                                                                                                                              |
| ------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Distribution certificate  | 1 an                                           | Ré-exporter un `.p12` depuis le keychain (ou régénérer sur developer.apple.com), mettre à jour `IOS_DIST_CERT_P12_BASE64` + password. |
| Provisioning profile      | 1 an                                           | Recréé par fastlane (`get_provisioning_profile force: true`) à chaque build.                                                          |
| Clé API App Store Connect | Pas d'expiration, rotation conseillée /12 mois | Nouvelle clé → mettre à jour les 3 secrets `ASC_*` → vérifier un build → révoquer l'ancienne.                                         |
| Apple Developer Program   | 1 an                                           | Renouveler côté Apple, sinon tous les builds échouent.                                                                                |

---

## Liens utiles

- ADR : `docs/adr/0005-github-actions-ios.md` (et l'historique `0002-flutter-ci.md`).
- Pipeline : `.github/workflows/build-ios.yml` + `apps/mobile/ios/fastlane/`.
- Apple — App Store Connect API : <https://developer.apple.com/documentation/appstoreconnectapi>.
