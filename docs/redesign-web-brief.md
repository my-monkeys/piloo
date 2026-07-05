# Prompt — Redesign du site web Piloo

> À coller tel quel à un designer / une IA de design. Il décrit **ce que fait
> chaque page et les données disponibles**, plus notre **palette** et nos
> **icônes**. Le **design est libre** : ne reproduis pas l'existant, innove.

---

Tu redessines **l'application web de Piloo** (Next.js 15 App Router, Tailwind CSS,
shadcn/ui). Tu peux ajouter des composants shadcn, changer toute la mise en page,
l'architecture visuelle, la navigation, les composants, la typo, le motion. Le
back-end, les routes et les données ne changent pas — tu redessines la surface.

## Le produit

Piloo est un **carnet numérique de médicaments** pour la maison, avec un pont
léger patient ↔ pro de santé. On scanne ses boîtes, on suit son stock et ses
dates de péremption, on voit sa timeline de prises du jour, on partage un carnet
entre proches (rôles Propriétaire / Éditeur / Lecteur), et un compte pro suit
plusieurs patients.

Positionnement à préserver dans l'UI : **ce n'est PAS un dispositif médical**,
pas un validateur d'ordonnance. C'est un aide-mémoire personnel, calme et
rassurant. Slogan actuel : « Tes médicaments, au calme. »

Public : grand public FR (patients, aidants), + pros de santé. **Français,
tutoiement.** Données de **santé** → sobre, digne de confiance, aucun tracker
tiers sur les écrans médicaux.

## Objectifs du redesign (le pourquoi)

1. **Plus beau / premium** — l'existant fait « basique / généré ». On veut une
   vraie direction visuelle, une hiérarchie soignée.
2. **Plus léger** — moins dense, plus aéré, plus rapide à lire.
3. **Orienté humain, pas technique** — aujourd'hui on affiche des **codes CIP13
   bruts** (13 chiffres) au lieu des **noms de médicaments**. Le nom lisible doit
   être partout la donnée principale ; les codes techniques (CIP13, lot, n° série)
   passent en secondaire ou disparaissent. (Le nom `denomination` existe dans la
   base BDPM et est déjà saisi à l'ajout — il faut juste le mettre en avant.)

---

## Les pages

Trois zones : **marketing public**, **authentification**, **app connectée**
(aujourd'hui : sidebar gauche fixe + contenu). Tu peux repenser la navigation.

### Marketing (public, pas d'auth)

| Page       | Rôle                                        | Données affichées                                                                                                                                                                                                        |
| ---------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/`        | Landing / vitrine, convertir en inscription | Statique : hero + slogan, 6 atouts (scan DataMatrix, timeline du jour, carnet partagé, OCR ordonnance, hors-ligne, base BDPM officielle), bloc « ce que Piloo n'est PAS » (pas un dispositif médical), CTA, footer légal |
| `/pricing` | Tarifs (3 offres)                           | Statique : Gratuit / Famille (4,99 €) / Pro de santé (19 €, « bientôt »), features par offre, FAQ                                                                                                                        |
| `/status`  | État du système (public)                    | Composants (Base de données, Base BDPM, Résumés IA) avec statut ok/dégradé/hors-service + horodatage. Aucune donnée nominative                                                                                           |

### Authentification (carte centrée)

| Page               | Rôle                                    | Données                                                                                                        |
| ------------------ | --------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `/sign-in`         | Connexion                               | email, mot de passe ; boutons Google (actif) / Apple (désactivé) ; liens mot de passe oublié + créer un compte |
| `/sign-up`         | Inscription                             | prénom, nom, email, mot de passe (≥8), type de compte (Particulier / Pro de santé) ; Google                    |
| `/forgot-password` | Demande de reset                        | email (message générique anti-énumération)                                                                     |
| `/reset-password`  | Nouveau mot de passe                    | mot de passe + confirmation (via token)                                                                        |
| `/check-inbox`     | « Vérifie tes emails » post-inscription | email affiché, bouton renvoyer le lien                                                                         |
| `/email-verified`  | Confirmation email OK                   | message + CTA vers le tableau de bord                                                                          |

### App connectée (une **officine active** est sélectionnée ; chaque page a un état vide « pas d'officine »)

| Page                   | Rôle                                                                    | Données affichées                                                                                                                                                                                                                                                                                                                                                        |
| ---------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/dashboard`           | Accueil post-login, aperçu du jour (3 widgets)                          | **Prochaines prises** (nom du médicament + heure, alerte si prises oubliées) · **Alertes** (péremption <30j/<7j, stock bas, prise oubliée, manque signalé + temps relatif) · **Stock** (compteurs Actives / Périmées / Vides)                                                                                                                                            |
| `/timeline`            | Grille semaine 7 jours × 4 moments (matin/midi/soir/coucher) des prises | Chips de prise = nom médicament + heure, colorées par statut (prise / prévue / sautée / oubliée). Clic → dialog : nom, heure prévue, statut, indication ; actions Marquer prise / sautée / réinitialiser                                                                                                                                                                 |
| `/inventory`           | Inventaire des boîtes de l'officine (table + recherche + détail)        | Par boîte : **nom du médicament (à mettre en avant — actuellement seul le CIP13 est montré ⚠️)**, péremption, stock (unités restantes / initiales), statut (Active/Périmée/Vide), + secondaire : lot, n° série, CIP13, date d'ajout, notes. Actions : ajouter (recherche BDPM par nom/CIP → dénomination, forme, dosage), ajuster stock, marquer vide/périmée, supprimer |
| `/ordonnances`         | Liste des ordonnances de l'officine + création                          | Par ordonnance : date, prescripteur, source (manuelle/OCR), notes. Création : date, prescripteur, notes + N prescriptions (médicament avec autocomplétion BDPM, unités/prise, unité, fréquence, moments, durée, avec repas, indication)                                                                                                                                  |
| `/ordonnances/[id]`    | Détail d'une ordonnance                                                 | En-tête (date, prescripteur, source, notes) + prescriptions : **nom médicament** (principal), CIP13 secondaire, durée, posologie (unités, fréquence/moments/horaires, avec repas), indication                                                                                                                                                                            |
| `/rappels`             | Plannings de prise par médicament (pause/reprise, édition)              | Par rappel : **nom médicament**, actif/en pause, horaires (matin/midi/soir/coucher + quantité + unité), période (début → fin), notes. Actions masquées pour le rôle Lecteur                                                                                                                                                                                              |
| `/pro/patients`        | Tableau multi-patients (compte pro)                                     | Carte par officine accessible : nom, rôle (Propriétaire/Éditeur/Lecteur), type (perso / patient suivi), nb boîtes (+ périmées), prises du jour (validées/total, restantes), oubliées, **observance jour %** (code couleur). Clic → active l'officine                                                                                                                     |
| `/settings/officines`  | Gestion des officines + invitations                                     | Invitations en attente (nom officine, invité par, rôle, accepter) · officines (nom, type, rôle, active) : activer, inviter (propriétaire), supprimer. Créer une officine (nom, type). Inviter un proche (rôle Éditeur/Lecteur, email optionnel, lien 72 h)                                                                                                               |
| `/invitations/[token]` | Acceptation d'invitation (public)                                       | Nom officine, rôle, invité par, expiration, états (en attente / expirée / acceptée / révoquée), bouton accepter                                                                                                                                                                                                                                                          |
| `/admin/summaries`     | Admin : résumés IA des médicaments                                      | Par médicament : dénomination, CIP13, dosage, forme, titulaire, résumé IA + version ; filtres, recherche, taux de couverture, édition inline                                                                                                                                                                                                                             |

### Pages légales

`/legal/cgu`, `/legal/privacy`, `/legal/mentions`, `/legal/cookies` — texte statique + bannière cookies globale. Doivent rester lisibles (colonne étroite, typo confortable).

---

## Données — entités et champs (pour bien nommer les choses)

- **officine** : nom, type (perso / patient), rôle de l'utilisateur (owner/editor/viewer), date de naissance (patient), notes.
- **boîte** : `denomination` (nom, via BDPM) · cip13, lot, n° série, péremption, unités initiales/restantes, statut (active/vide/périmée), notes, date d'ajout.
- **ordonnance** : prescripteur, date, source (manuelle/OCR), notes.
- **prescription** : `nom_texte` (nom), posologie (unités par prise, unité, fréquence quotidien/hebdo/à la demande, moments matin/midi/soir/coucher, horaires, avec repas), durée (jours ; vide = à vie), indication, notes.
- **prise planifiée** : nom médicament, heure prévue, statut (prévue/prise/sautée/oubliée), indication.
- **rappel** : nom, unité, quantités par moment, période (début/fin), actif.
- **alerte** : type (péremption 30j/7j, stock bas, prise oubliée, manque signalé), date.
- **médicament BDPM** (référence officielle) : dénomination, forme (comprimé, sirop, injectable…), dosage, voie, titulaire — sert aux recherches et à afficher un **nom lisible + une icône par forme**.

> **Règle transverse** : le **nom lisible du médicament** est toujours l'élément principal. CIP13 / lot / n° série = métadonnées discrètes.

---

## Identité visuelle actuelle (nos ancres — à faire évoluer si tu veux mieux)

C'est notre palette de marque : chaleureuse, calme, cohérente avec le
positionnement. Tu peux la raffiner, mais elle définit l'esprit « au calme ».

**Palette (hex)**

| Rôle                                          | Couleur               |
| --------------------------------------------- | --------------------- |
| Fond app (crème chaud)                        | `#faf8f3`             |
| Surface (cartes, modales)                     | `#ffffff`             |
| Surface secondaire                            | `#f1ede2`             |
| Bordures                                      | `#e5e0d3`             |
| **Primaire** (vert sauge — CTA, actif, liens) | `#4a6b64`             |
| Primaire hover                                | `#3d5a54`             |
| Primaire doux (fonds actifs, badges)          | `#dbe3e0`             |
| **Accent** (terracotta — logo, highlights)    | `#a8472e`             |
| Accent doux                                   | `#f3d9cd`             |
| Texte principal                               | `#252a30`             |
| Texte secondaire                              | `#6b7280`             |
| Texte tertiaire                               | `#9ca3af`             |
| Succès (fond / texte)                         | `#d8e3d5` / `#355b3e` |
| Alerte (fond / texte)                         | `#f5e4c3` / `#7a541c` |
| Erreur (fond / texte)                         | `#eed0c5` / `#8a382a` |
| Info (fond / texte)                           | `#d8dfe6` / `#35475a` |

Rayons : 6 / 8 / 12 / 16 / plein. Espacements : 4/8/12/16/24/32/48/64.
Typo **prévue** (pas encore chargée, à câbler) : **Fraunces** (titres, serif
éditorial) + **Manrope** (corps/UI). Source de vérité des tokens :
`packages/design-tokens/tokens.json`.

**Icônes**

- Installé aujourd'hui : **`lucide-react`** (à peine utilisé). shadcn est configuré sur lucide.
- L'identité **prévue** est **Phosphor** (Regular + Fill), avec une **icône par forme
  de médicament** (comprimé, seringue, flacon, sirop, spray, gouttes, pansement…).
- Choisis **une** famille d'icônes cohérente (lucide ou Phosphor) et tiens-t'y.

---

## Ce que tu dois livrer / ta liberté

- Tu proposes **la direction visuelle complète** : mise en page, navigation
  (garder ou non la sidebar), hiérarchie, composants, densité, états vides,
  micro-interactions, responsive, dark mode si pertinent (aujourd'hui light only).
- **Priorités** : élégance sobre + légèreté + **noms de médicaments en héros**
  (finis les murs de CIP13, surtout sur `/inventory`).
- Contraintes fermes : rester en **Next.js 15 + Tailwind + shadcn/ui**, **FR /
  tutoiement**, **données de santé** (sobriété, pas de tracker tiers), ne jamais
  suggérer que c'est un dispositif médical.
- Le reste (esthétique, composition, motion, jusqu'à faire évoluer la palette) :
  **c'est toi qui inventes.**
