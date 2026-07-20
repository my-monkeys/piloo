# ADR 0005 — Release mobile : GitHub Actions remplace Codemagic

- **Statut** : Accepté (remplace [ADR 0002](./0002-flutter-ci.md))
- **Date** : 2026-07-20
- **Périmètre** : builds release mobile (`apps/mobile`, iOS TestFlight + Android APK). Les checks PR restent sur `mobile-ci.yml`.

## Contexte

L'ADR 0002 avait retenu Codemagic pour les builds Flutter (free tier macOS,
signing clé-en-main). Deux faits nouveaux ont invalidé cet arbitrage :

1. **Le repo est public** → runners macOS GitHub Actions gratuits. L'avantage
   « 500 min offertes » de Codemagic ne pèse plus rien.
2. **La review App Store de juillet 2026** : Apple refusait les builds locaux
   (ITMS-90111, Xcode beta/GM trop ancien). Le seul build accepté — celui de la
   1.0 validée — est sorti d'une chaîne GitHub Actions + fastlane
   (`.github/workflows/build-ios.yml`, PR #384), signature manuelle par clé API
   App Store Connect. Cette chaîne est donc déjà écrite, secrète-isée dans
   GitHub Secrets, et validée en conditions réelles.

Maintenir deux CI mobiles (Codemagic sur `v*`, GHA sur `ios-v*`) doublait les
builds et dispersait le suivi (dashboard Codemagic invisible depuis `gh`).

## Décision

- `build-ios.yml` devient la release iOS officielle, déclenchée par le même tag
  `v*` (hors `v*-demo`) que `android-release.yml` — un tag = les deux
  plateformes. La version est dérivée du tag (`v1.2.3` → `1.2.3+<epoch>`),
  `flutter analyze` + `flutter test` tournent avant le build (parité Codemagic).
- `codemagic.yaml` est supprimé. Non portés, volontairement :
  - l'upload **Play Console internal** (l'APK signé sur GitHub Releases suffit ;
    à recréer si l'app sort réellement sur le Play Store) ;
  - le flux **demo iOS** `v*-demo` → TestFlight (servi une seule fois ;
    l'équivalent Android `android-demo-release.yml` reste).

## Conséquences

- Un seul endroit pour suivre les builds (`gh run list`), un seul jeu de
  secrets (GitHub Secrets : `ASC_*`, `IOS_DIST_CERT_*`, `IOS_KEYCHAIN_PASSWORD`).
- L'app Codemagic doit être désactivée côté dashboard (action manuelle) pour
  couper les webhooks.
- Le build number passe d'un compteur monotone Codemagic à l'epoch Unix —
  toujours croissant, pas de collision TestFlight, mais des sauts non contigus.
- Runbook opérateur : `docs/deploy-mobile-ios.md` (réécrit pour GHA).
