# CI Android — build APK signé → GitHub Releases

Pipeline défini dans `.github/workflows/android-release.yml` (GitHub Actions — Codemagic abandonné, cf. `docs/adr/0005-github-actions-ios.md`).

## Déclencheur

Tag git `v*` (hors `v*-demo`, géré par `android-demo-release.yml`) — le même tag déclenche la release iOS (`build-ios.yml`). Aucun build signé sur PR : la CI PR (`mobile-ci.yml`) reste limitée à `flutter analyze` + `flutter test`.

## Sortie

- **APK signé publié sur la GitHub Release du tag** — distribution interne hors Play (sideload équipe, beta-testeurs sans compte Google Play).
- Pas d'upload Play Console : abandonné avec Codemagic (l'app n'est pas publiée sur le Play Store). À recréer le jour où elle sort réellement — le keystore et un service account `piloo-play-publisher` suffiraient (action `r0adkll/upload-google-play` ou `fastlane supply`).

## Versioning

Le tag git est la source de vérité : `v1.2.3` → `pubspec.yaml` réécrit en `version: 1.2.3+<count>` où `<count>` = `git rev-list --count HEAD` (croissant).

## Secrets requis (GitHub Secrets)

| Secret                      | Description                                                 |
| --------------------------- | ----------------------------------------------------------- |
| `ANDROID_KEYSTORE_BASE64`   | Keystore JKS encodé base64 (`base64 -i piloo-release.jks`). |
| `ANDROID_KEYSTORE_PASSWORD` | Mot de passe du keystore.                                   |
| `ANDROID_KEY_ALIAS`         | Alias de la clé (ex. `piloo-release`).                      |
| `ANDROID_KEY_PASSWORD`      | Mot de passe de la clé.                                     |

Le `.jks` source est sauvegardé hors-repo (coffre-fort). `key.properties` et `keystore.jks` sont gitignorés et régénérés à chaque build.

## Deep links (App Links)

Le manifest déclare `https://piloo.my-monkey.fr/invitations/*` en `autoVerify`.
La vérification s'appuie sur `apps/web/public/.well-known/assetlinks.json`, qui
contient l'empreinte SHA-256 de **notre** clé de signature (celle du keystore
`ANDROID_KEYSTORE_BASE64`, CN=Piloo) :

```
EF:E2:71:C5:D6:FB:CE:CC:39:E8:EB:6E:06:D2:C0:FE:3A:C6:9C:86:3F:35:F9:75:4C:73:19:6D:7E:45:0D:BF
```

⚠️ **Le jour où l'app passe sur le Play Store** : avec Play App Signing, Google
re-signe le binaire avec _sa_ clé, et notre keystore devient une simple _upload
key_. Les liens ne se vérifieront plus tant que l'empreinte affichée dans
`Play Console → Configuration → Intégrité de l'app` n'aura pas été **ajoutée**
au tableau `sha256_cert_fingerprints` (garder les deux : sideload + Play).
Récupérer l'empreinte d'un APK : `apksigner verify --print-certs <apk>`.

## Runbook panne

Si GitHub Actions est down et qu'il faut publier en urgence :

```bash
cd apps/mobile
fvm flutter build apk --release   # nécessite key.properties + keystore.jks locaux
# Partager l'APK directement (ou l'attacher à la main à une GitHub Release).
```
