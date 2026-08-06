# Fiche Google Play Store — Piloo

Textes et assets pour la fiche Play Console. Cohérents avec la fiche App Store
(app `6767163944`, publiée le 2026-07-22) et avec la landing `piloo.my-monkey.fr`.

> **Ton** : tutoiement, comme l'app et la landing. La fiche App Store existante
> vouvoie (rédigée avant la refonte) — à aligner un jour pour l'homogénéité.

---

## 1. Identité

| Champ                     | Valeur                                                                      | Limite                |
| ------------------------- | --------------------------------------------------------------------------- | --------------------- |
| **Nom de l'application**  | `Piloo · Carnet de médicaments`                                             | 30 car. (29 utilisés) |
| **Description courte**    | `Ton carnet de médicaments à la maison : scan, stock, péremption, rappels.` | 80 car. (73 utilisés) |
| **Catégorie**             | Médecine                                                                    | —                     |
| **Tags**                  | suivi de médicaments, santé, rappels                                        | 5 max                 |
| **Public cible**          | 18 ans et plus                                                              | —                     |
| **Contient des annonces** | Non                                                                         | —                     |
| **Achats intégrés**       | Non (au lancement — le plan Famille arrivera plus tard)                     | —                     |

## 2. Description complète (4000 car. max)

```
Piloo, c'est ton carnet numérique de médicaments — un meilleur cahier de pharmacie pour la maison.

SCAN INSTANTANÉ
Scanne le DataMatrix au dos de tes boîtes : Piloo reconnaît le médicament dans la base officielle BDPM (ANSM) et pré-remplit le nom, le dosage, la forme et la date de péremption. Zéro saisie.

TON OFFICINE, RANGÉE
Tout ton stock en un coup d'œil. Regroupe par médicament ou par molécule, repère d'un regard ce qui est périmé ou bientôt épuisé, et retrouve n'importe quelle boîte en deux secondes.

RAPPELS DE PRISE
Matin, midi, soir, coucher : Piloo range tes prises par moment de la journée et te rappelle chacune au bon moment. Pratique pour la pilule, un antibiotique sur 7 jours ou un traitement au long cours.

FICHE MÉDICAMENT COMPLÈTE
Résumé clair, indications officielles ANSM, posologie, précautions d'emploi, effets indésirables. Les infos de la notice, en lisible.

CARNET PARTAGÉ
Partage une officine avec un proche, un parent âgé ou un aidant, avec le bon niveau d'accès : Propriétaire, Éditeur ou Lecteur. Chacun voit ce qu'il doit voir.

MARCHE HORS-LIGNE
Ajoute une boîte à la pharmacie sans réseau : tout est enregistré sur ton téléphone et se synchronise dès que la connexion revient.

100 % PRIVÉ
Aucun tracker publicitaire, aucune revente de données, aucun partage avec un laboratoire. Tes données de santé restent les tiennes, et tu peux supprimer ton compte à tout moment depuis l'app (Plus › Supprimer mon compte).

—

IMPORTANT — Piloo est un aide-mémoire personnel, pas un dispositif médical. Il ne remplace ni ton ordonnance, ni l'avis de ton médecin ou de ton pharmacien. Piloo ne fait aucune recommandation clinique : pas de validation de posologie, pas d'alerte d'interaction médicamenteuse. Pour toute question de santé, consulte un professionnel.

Piloo est développé en France par My-Monkey, à Montpellier.
```

## 3. Assets graphiques

| Asset                          | Format requis                       | État                                                                            |
| ------------------------------ | ----------------------------------- | ------------------------------------------------------------------------------- |
| **Icône**                      | 512 × 512 PNG 32 bits               | ✅ dispo — `apps/mobile/assets/branding/app-icon.png` (1024², à redimensionner) |
| **Feature graphic**            | 1024 × 500 PNG/JPG, **obligatoire** | ✅ `out/feature-graphic.png`                                                    |
| **Captures téléphone**         | 2 à 8, ratio 9:16, min 320 px       | ✅ `out/screenshot-1..4.png` (1080 × 1920)                                      |
| **Captures tablette 7" / 10"** | optionnelles                        | ⬜ facultatif (des captures iPad existent déjà)                                 |

### Régénérer les visuels

```bash
node docs/playstore/generate.mjs
```

- `raw/` — captures brutes de l'émulateur (écrans réels, compte peuplé)
- `slides.json` — accroches et sous-titres
- `template.html` — habillage 1080 × 1920 (fond crème, blobs, titre Fraunces)
- `out/` — visuels prêts à téléverser

Les captures App Store (1290 × 2796) ne sont pas réutilisables : leur ratio 2,17
dépasse la limite Play de 2:1. Le format retenu est le 9:16 canonique.
Pour recapturer les écrans : émulateur de cookie-server (AVD `glance`,
1080 × 2400), helper `~/piloo-emu.sh`, compte de test peuplé.

## 4. URLs obligatoires

| Champ                        | Valeur                                                |
| ---------------------------- | ----------------------------------------------------- |
| Site web                     | `https://piloo.my-monkey.fr`                          |
| E-mail de contact            | `contact@piloo.fr`                                    |
| Politique de confidentialité | `https://piloo.my-monkey.fr/legal/privacy`            |
| **Suppression du compte**    | `https://piloo.my-monkey.fr/legal/suppression-compte` |

⚠️ L'URL de suppression de compte est **obligatoire** pour toute app qui permet
de créer un compte. Elle doit être accessible **sans être connecté** et décrire
à la fois la suppression in-app et la voie de recours pour quelqu'un qui n'a
plus l'application.

## 5. Data safety (formulaire Play Console)

Données **collectées et liées à l'identité**, jamais partagées avec des tiers,
jamais utilisées à des fins publicitaires ou de suivi :

| Type               | Donnée                                         | Finalité                                   | Obligatoire |
| ------------------ | ---------------------------------------------- | ------------------------------------------ | ----------- |
| Infos personnelles | Nom, e-mail                                    | Fonctionnement de l'app, gestion du compte | Oui         |
| Infos de santé     | Médicaments, prises, ordonnances               | Fonctionnement de l'app                    | Oui         |
| Identifiants       | ID de compte, jeton d'appareil (notifications) | Fonctionnement de l'app                    | Oui         |

À cocher également : chiffrement en transit (HTTPS partout), possibilité de
demander la suppression des données, aucune donnée partagée avec des tiers.

## 6. Classification du contenu (questionnaire IARC)

App utilitaire de santé, sans violence, sexe, jeu d'argent ni contenu généré par
les utilisateurs partagé publiquement → **PEGI 3 / Tout public** attendu.
Répondre « Oui » à « références à des médicaments » (l'app liste des
médicaments prescrits) ; ce n'est pas de la promotion de drogues.

## 7. Déclarations de permissions

| Permission                                 | Justification                                                                                                                                                                                                        |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CAMERA`                                   | Scan du DataMatrix des boîtes de médicaments                                                                                                                                                                         |
| `POST_NOTIFICATIONS`                       | Rappels de prise et alertes de péremption                                                                                                                                                                            |
| `USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM` | Rappels de prise à l'heure exacte. Google autorise l'alarme exacte sans formulaire pour les apps de type **médicament / alarme / agenda** — c'est le cœur de fonction de Piloo. À rappeler dans les notes de review. |
| `RECEIVE_BOOT_COMPLETED`                   | Replanifier les rappels après un redémarrage                                                                                                                                                                         |

`READ_CONTACTS` a été retirée en #398 (jamais utilisée) : plus aucune permission
sensible à justifier par formulaire.

## 8. Reste à trancher / faire

- [ ] **Compte Google Play Developer** — 25 $ une fois. Type de compte à choisir
      _avant_ de créer l'app : un compte **personnel** créé récemment impose de
      recruter **12 testeurs pendant 14 jours** avant toute publication en
      production ; un compte **organisation** (My-Monkey, asso loi 1901, avec
      numéro D-U-N-S) en est dispensé. Décision structurante pour le planning.
- [ ] Feature graphic 1024 × 500 + captures Android
- [ ] Page `/legal/suppression-compte` (créée dans la même PR que ce document)
- [ ] Version : publier en **1.0** pour s'aligner sur l'App Store (le versionName
      actuel des builds est `0.1.x`)
- [ ] Play App Signing : ajouter l'empreinte SHA-256 de Google dans
      `assetlinks.json` une fois l'app créée (cf. `apps/mobile/docs/ci-android.md`)
