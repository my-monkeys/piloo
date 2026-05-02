# UI/UX Guidelines — Piloo

Ce document pose les directions de design et **liste exhaustivement tous les écrans et composants à concevoir**. L'identité de marque (nom, couleurs, typographie) est validée. Les écrans et composants restent à designer en Figma en suivant les tokens définis ici.

---

## Identité de marque Piloo

### Nom et positionnement

**Nom du produit** : Piloo

**Baseline** (à raffiner) : *"Le carnet numérique de médicaments pour la maison."*

**Ton de marque** : rassurant, pro sans être froid, sobre sans être ennuyeux. Évite absolument les tournures infantilisantes, culpabilisantes, ou wellness-lifestyle creuses.

### Logo

À designer. Quelques principes à respecter :
- Le wordmark **piloo** en minuscules (plus doux qu'en majuscules).
- Mise en valeur des deux **oo** via couleur accent (terracotta) ou léger stylisme (petits points, lien entre les O).
- Version compacte : juste les deux **oo** accolés comme icône/favicon.
- Typographie Fraunces en poids medium pour le wordmark.

### Palette de couleurs (tokens définitifs)

**Couleurs de base**

| Token | Hex | Usage |
|---|---|---|
| `background` | `#faf8f3` | Fond d'écran principal (crème chaud) |
| `surface` | `#ffffff` | Cards, modales, surfaces élevées |
| `surface-subtle` | `#f1ede2` | Surfaces secondaires, zones calmes |
| `border` | `#e5e0d3` | Bordures de cards et séparateurs |

**Couleurs de marque**

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#4a6b64` | CTA principaux, éléments actifs, liens |
| `primary-hover` | `#3d5a54` | Hover/pressed |
| `primary-soft` | `#dbe3e0` | Backgrounds doux sur primary |
| `accent` | `#a8472e` | Accent chaud (logo, highlights importants) |
| `accent-soft` | `#f3d9cd` | Background doux accent |

**Couleurs de texte**

| Token | Hex | Usage |
|---|---|---|
| `text-primary` | `#252a30` | Texte principal |
| `text-secondary` | `#6b7280` | Texte secondaire, meta |
| `text-tertiary` | `#9ca3af` | Labels, captions |
| `text-on-primary` | `#ffffff` | Texte sur fond primary |

**Couleurs sémantiques**

| Token | BG | Text |
|---|---|---|
| `success` | `#d8e3d5` | `#355b3e` |
| `warning` | `#f5e4c3` | `#7a541c` |
| `error` | `#eed0c5` | `#8a382a` |
| `info` | `#d8dfe6` | `#35475a` |

### Typographie

**Famille de polices**

- **Titles** : Fraunces (serif moderne avec opsz) — weights 400, 500, 600
- **Body** : Manrope (sans-serif chaleureux) — weights 400, 500, 600, 700
- **Numerics tabulaires** : Manrope avec `font-variant-numeric: tabular-nums`

Ces polices sont disponibles sur Google Fonts, à importer via `next/font` côté web et `google_fonts` package côté Flutter.

**Échelle typographique** (tokens)

| Token | Mobile | Desktop | Usage |
|---|---|---|---|
| `display` | 32px / Fraunces 500 | 48px | Titres héros landing |
| `title-xl` | 24px / Fraunces 500 | 32px | Titres d'écran |
| `title-lg` | 20px / Fraunces 500 | 24px | Sections |
| `title-md` | 16px / Fraunces 500 | 18px | Cards, modales |
| `body-lg` | 16px / Manrope 400 | 16px | Corps de texte principal |
| `body-md` | 14px / Manrope 400 | 14px | Texte standard |
| `body-sm` | 13px / Manrope 400 | 13px | Texte secondaire |
| `caption` | 12px / Manrope 500 | 12px | Labels, meta |
| `label` | 11px / Manrope 600 uppercase | 11px | Eyebrow, sections |

### Système spatial

Grille en **multiples de 4px** (token base).

| Token | Valeur |
|---|---|
| `space-xs` | 4px |
| `space-sm` | 8px |
| `space-md` | 12px |
| `space-lg` | 16px |
| `space-xl` | 24px |
| `space-2xl` | 32px |
| `space-3xl` | 48px |
| `space-4xl` | 64px |

### Border radius

| Token | Valeur | Usage |
|---|---|---|
| `radius-sm` | 6px | Boutons petits, chips |
| `radius-md` | 8px | Boutons, inputs |
| `radius-lg` | 12px | Cards, surfaces |
| `radius-xl` | 16px | Modales, bottom sheets |
| `radius-full` | 999px | Badges, avatars |

### Shadows (légères, jamais agressives)

- `shadow-sm` : `0 1px 2px rgba(37, 42, 48, 0.04)`
- `shadow-md` : `0 2px 8px rgba(37, 42, 48, 0.06)`
- `shadow-lg` : `0 8px 24px rgba(37, 42, 48, 0.08)`

### Iconographie

**Library** : [Phosphor Icons](https://phosphoricons.com)

**Styles à utiliser**
- **Regular** (par défaut) : icônes standard
- **Fill** : pour les états actifs (ex : tab bar actif, cloche avec alertes)
- **Bold** : jamais utilisé seul, éviter

**Tailles standards**
- Inline dans texte : 16px
- Boutons : 20px
- FAB et icônes principales : 24px
- Hero / illustrations : 32px+

### Illustrations

**Style** : custom, à créer pour Piloo. Objectif : illustrations minimalistes cohérentes avec la palette (beige + vert sauge + terracotta), sans personnages ultra-stylisés type Duolingo.

**À produire** (5-8 illustrations) :
1. Onboarding écran 1 — "Scanner ses médicaments"
2. Onboarding écran 2 — "Suivre ses prises"
3. Onboarding écran 3 — "Partager avec ses proches"
4. Empty state "Officine vide"
5. Empty state "Pas de prises aujourd'hui"
6. Empty state "Pas d'alertes"
7. Empty state "Aucun partage"
8. Erreur / rupture (scan impossible, réseau down)

**Avant les illustrations custom** : démarrage possible avec Phosphor illustrations gratuites en placeholder, ou emojis stylisés.

### Voix & copywriting

**Ton**
- Tutoiement dans l'app (plus chaleureux, plus moderne).
- Vouvoiement dans les CGU/politique (plus formel, plus juridique).
- Phrases courtes, voix active.
- Éviter le jargon : "principe actif" plutôt que "DCI", "date de péremption" plutôt que "date limite d'utilisation".

**Mentions obligatoires** (cf. positionnement carnet de suivi)
- **Onboarding écran dédié** : disclaimer complet avec acceptation explicite. Phrase type : *"Piloo est un carnet numérique personnel. Il t'aide à organiser tes médicaments mais ne remplace ni ton ordonnance, ni l'avis de ton médecin ou pharmacien."*
- **Footer fiche info médicament** : *"Informations à titre indicatif. Pour toute question, consulte ton médecin ou pharmacien."*
- **Avant validation OCR ordonnance** : *"L'extraction automatique n'est pas fiable à 100%, vérifie chaque ligne avant de confirmer."*
- **CGU et politique de confidentialité** : mention formelle "n'est pas un dispositif médical au sens du règlement MDR".

### Mode et thème

**MVP** : **light mode uniquement**. Single source de vérité sur les tokens.

**V2** : ajout du dark mode avec des tokens dark dérivés. Respect de la préférence système par défaut, override manuel possible dans les paramètres.

---

## Principes directeurs

### Tonalité

- **Sobre et rassurant** : on touche à la santé, pas à un jeu. Couleurs apaisées, pas de gamification type "streak de prise" avec confettis.
- **Clair et sans jargon** : l'utilisateur type n'est pas un pro de santé. On dit "principe actif" et on explique en parenthèses, pas "DCI" nu.
- **Pas de culpabilisation** : une prise manquée, c'est OK, on la note et on continue. Pas de petits bonshommes déçus.
- **Mentions de responsabilité visibles mais pas intrusives** : "ce n'est pas un avis médical" doit apparaître où nécessaire, sans saturer l'écran.

### Priorités hiérarchiques

1. **Mobile-first**. Le scan est LA feature, la caméra est sur le téléphone. Le web est un complément (gestion, vue d'ensemble, administration).
2. **Rapidité d'action** : scanner une boîte et l'ajouter doit prendre < 10 secondes.
3. **Lisibilité personnes âgées** : tailles de police confortables par défaut, support du dynamic type, contrastes forts.
4. **Cohérence plateformes** : pas besoin que mobile et web soient identiques à l'identique, mais même langage visuel, même terminologie, même logique.

### Accessibilité (non négociable)

- Contrastes WCAG AA minimum (AAA sur les textes importants).
- Tailles de police respectant les préférences système.
- Labels ARIA sur tous les boutons icône côté web.
- Navigation clavier complète côté web.
- Support VoiceOver / TalkBack côté mobile (labels sémantiques sur tous les composants interactifs).
- Zones tactiles minimum 44×44 pt.
- Pas d'information véhiculée uniquement par la couleur (toujours doublée par icône ou texte).

---

## Système de design — options à concevoir

### Couleurs (tokens à définir)

- **Primaire** : couleur de marque (à choisir : vert médical ? bleu doux ? teal ? bordeaux chaud ?). À tester en évitant les clichés (bleu hôpital, rouge pharmacie) et les couleurs trop genrées.
- **Secondaire** : accent pour CTA, badges.
- **Statuts** :
  - Succès (prise validée, sync OK)
  - Attention (péremption proche, stock bas)
  - Erreur (péremption dépassée, échec de sync)
  - Info (neutre)
- **Surfaces** : background, card, elevated card, modal overlay.
- **Texte** : primary, secondary, tertiary, disabled.
- **Modes** : light, dark (minimum). Auto selon système.

### Typographie

- Police système ou police custom ? Pour un MVP, **police système** (SF Pro sur iOS, Roboto sur Android, Inter ou similar sur web) est le plus sûr.
- Échelle à définir : 6-8 niveaux (display, title, heading, body, body-small, caption, label, overline).
- Poids : minimum regular, medium, bold.

### Espacement

- Grille 4 ou 8 px.
- Spacing tokens : xs, sm, md, lg, xl, 2xl, 3xl.

### Composants de base (à designer)

- Boutons : primary, secondary, destructive, ghost, icon-only, avec états hover/pressed/disabled/loading.
- Champs de formulaire : input text, input numérique, dropdown, checkbox, radio, toggle switch.
- Cards : médicament (compact, expanded), officine, prise, alerte.
- Badges : statut boîte (actif/vide/périmée), rôle utilisateur (owner/editor/viewer), compteur notification.
- Chips : filtre actif, tag.
- Modales : confirmation, formulaire, bottom sheet (mobile).
- Toast / snackbar : feedback action rapide, avec undo.
- Loading states : skeleton, spinner, progress bar.
- Empty states : illustration + texte + CTA pour chaque écran.
- Error states : idem.

---

## Écrans mobile (Flutter)

### Onboarding

1. **Splash screen** avec logo.
2. **Welcome screens** (2-3 écrans) expliquant la valeur :
   - Scannez vos boîtes pour constituer votre officine
   - Programmez vos prises et recevez des rappels
   - Partagez l'accès à vos proches ou soignants
3. **Choix du type de compte** : Particulier / Pro de santé.
4. **Inscription** (email, mot de passe, nom, prénom).
5. **Vérification email** : écran d'attente + bouton "J'ai vérifié mon email".
6. **Mentions légales** : écran dédié avant la 1ère utilisation, acceptation explicite RGPD + disclaimer "carnet de suivi, pas outil médical". Obligatoire.
7. **Tutoriel rapide** (optionnel, skippable) : gestures clés, où est le scan.
8. **Permissions** : caméra, notifications, (optionnel) contacts pour invitations.

### Écran d'accueil (Tab bar principale)

Tab bar avec **3 onglets** (décision validée) :
1. **Aujourd'hui** (timeline de prises du jour)
2. **Officine** (inventaire)
3. **Plus** (paramètres, comptes, partage, aide)

Éléments complémentaires :
- **Bouton Scan** : FAB central flottant au-dessus de la tab bar (accessible au pouce, proéminent visuellement).
- **Icône cloche alertes** : dans le header de chaque écran, avec badge compteur rouge si alertes non lues. Tap → écran Alertes (push nav, pas tab).

### 1. Écran "Aujourd'hui"

- Date en header + sélecteur pour naviguer jour±1.
- Regroupement par moment : Matin / Midi / Soir / Coucher.
- Pour chaque prise :
  - Nom du médicament + dosage
  - Nombre d'unités à prendre
  - Horaire prévu
  - Statut visuel (cercle vide / coché / rayé / triangle "!")
  - Tap → modale d'action : Prise / Sautée / Reporter / Détails
- État vide : "Aucune prise prévue aujourd'hui. Ajouter une ordonnance ?"
- Swipe actions : validation rapide (pris / sauté).
- Bascule d'officine en haut si plusieurs (ex : basculer entre "Moi", "Papa", "Mme Dubois").

### 2. Écran "Officine" (inventaire)

- Header : nom de l'officine active + compteur de boîtes.
- Bascule "Par médicament" / "Par molécule" / "Liste à plat".
- Filtres rapides : Actif / Vide / Périmé, plus filtre par tag si v2.
- Barre de recherche.
- Liste des groupes (dépliables) ou boîtes (liste plate).
- FAB "+" pour ajouter : scan ou saisie manuelle.
- Tap sur une boîte → détail de la boîte (cf. plus bas).
- Tap long → actions rapides sans re-scan (marquer vide, ajuster stock…).

### 3. Écran "Scan"

- Caméra plein écran.
- Viseur visuel pour cadrer le DataMatrix.
- Haptic feedback + son subtil à la détection.
- Message "Rapprochez le code-barres" si rien détecté en 5s.
- Accès aux flash de la caméra (utile en armoire sombre).
- Bouton retour + bouton "Saisie manuelle" si pas de DataMatrix lisible.
- Après détection : **transition vers le flux d'ajout** (si boîte nouvelle) ou **popup actions rapides** (si boîte déjà connue).

### 4. Écran Ajout de boîte (post-scan)

- Header "Nouvelle boîte".
- Aperçu médicament : nom, dosage, forme, image si disponible.
- Champs pré-remplis :
  - Date de péremption (datepicker si modif)
  - Numéro de lot
  - Numéro de série (replié dans "Détails")
- Sélecteur d'officine cible (si plusieurs).
- Niveau initial : "Plein", "3/4", "Moitié", "1/4", ou nombre précis.
- Notes libres.
- Bouton "Ajouter à mon officine" + "Annuler".
- En cas de médicament non reconnu : message + bascule en saisie manuelle.

### 5. Popup actions rapides (re-scan)

- Bottom sheet (mobile) ou modal centrée.
- Header : nom médicament + "Déjà dans votre officine [Nom]".
- 4-6 grands boutons tactiles :
  - Marquer comme vide
  - Ajuster le stock
  - Infos médicament
  - Marquer comme périmée
  - Signaler un manque
- Bouton "Annuler" en bas.
- L'option "Ajuster stock" ouvre un sous-écran/modale avec les presets (Plein, 3/4, Moitié, 1/4, Presque vide) + champ précis.

### 6. Écran Détail boîte

- Nom + dosage + forme en header.
- Photo si disponible.
- Infos principales : lot, péremption, niveau stock, date d'ajout, ajoutée par.
- Historique des actions (ajustements de stock, changements de statut).
- Fiche info médicament (voir écran suivant) accessible via un onglet ou section dépliable.
- Actions : Modifier, Marquer vide, Marquer périmée, Supprimer.

### 7. Écran Fiche info médicament

- Nom commercial + dosage + forme.
- Principe actif (DCI) — cliquable → liste de tous les médicaments de l'officine avec ce DCI.
- Laboratoire.
- Taux de remboursement.
- **Résumé IA court** (2-3 lignes) avec pictogramme "généré automatiquement".
- Bouton "Ouvrir la notice officielle" → navigateur externe.
- Avertissement en bas : "Informations à titre indicatif. Pour toute question, consultez votre médecin ou pharmacien."

### 8. Écran Ordonnances (liste)

- Liste des ordonnances de l'officine, tri par date.
- Pour chaque ordonnance : date, prescripteur, nb de médicaments, badge "active" / "terminée".
- Tap → détail.
- FAB "+" → nouvelle ordonnance (saisie manuelle ou scan photo).

### 9. Écran Création ordonnance

- Étape 1 : infos générales (date, prescripteur).
- Étape 2 : ajout de prescriptions une par une.
  - Choix médicament : scan d'une boîte existante OU recherche textuelle dans BDPM.
  - Posologie : pickers pour unités, fréquence, moments de prise (checkboxes), durée.
  - With/without food.
  - Notes.
  - Ajouter une autre prescription → boucle.
- Étape 3 : récapitulatif + création.

### 10. Écran OCR ordonnance (v2 MVP)

- Prise de photo ou sélection depuis galerie.
- Écran d'attente pendant OCR (animation).
- Résultat : formulaire pré-rempli en édition, l'utilisateur valide/corrige chaque ligne.
- Mention explicite : "L'extraction automatique n'est pas fiable à 100%, vérifiez chaque ligne."

### 11. Écran Alertes

- Liste chronologique, tri inversé.
- Regroupement par type possible.
- Pour chaque alerte : icône selon type, titre, contexte, date.
- Tap → navigation vers la ressource concernée (boîte, prise, partage).
- Actions : marquer lue, tout marquer lu, filtres.
- Badge compteur sur tab bar.

### 12. Écrans Partage

- **Gestion des partages d'une officine** (owner) :
  - Liste des utilisateurs partagés avec leur rôle.
  - Bouton "Inviter quelqu'un" → formulaire : email + rôle (Propriétaire/Éditeur/Lecteur expliqués brièvement).
  - Retrait d'un partage avec confirmation.
- **Mes officines** (toutes) : liste avec rôle pour chaque, switch rapide.
- **Accepter une invitation** : si l'utilisateur clique sur un lien d'invitation.

### 13. Écrans Paramètres / Plus

- Profil utilisateur (nom, email, téléphone).
- Préférences notifications (par canal : push, email, SMS + digest quotidien).
- Horaires par défaut des moments (matin, midi, soir, coucher).
- Changement de mot de passe.
- 2FA (pour pros).
- Gestion des officines (rappel).
- Langue (FR verrouillé au MVP).
- Thème (light/dark/auto si on l'implémente).
- Aide & FAQ.
- CGU / Politique de confidentialité.
- Mentions légales + "Pas un dispositif médical".
- Contactez-nous / Feedback.
- Export de mes données (RGPD).
- Supprimer mon compte.
- Déconnexion.
- Version de l'app + version BDPM embarquée.

### 14. Écran "Vue pro" (si type_compte = pro)

- Dashboard léger : liste des patients suivis avec alertes en cours.
- Tap → officine du patient.
- Filtres : aujourd'hui / cette semaine, par statut.
- Note : au MVP cette vue est minimaliste, sans analytics poussés (repoussés en v3).

---

## Écrans web (Next.js)

Le web est pensé comme complément. Moins utilisé mais utile pour :
- Gestion administrative (profil, partages, préférences)
- Vue d'ensemble (tableau des stocks, vue mensuelle des prises)
- Saisie massive (ordonnances longues, confortable au clavier)
- Usage bureau pour un IDEL qui gère 15 patients

### Liste des écrans web

1. **Landing page marketing** (pour visiteurs non inscrits) : pitch + captures + CTA inscription. À designer avec soin puisque c'est la première impression.
2. **Pages auth** : connexion, inscription, mot de passe oublié, vérification email.
3. **Dashboard** (accueil post-login) :
   - Widgets : prochaines prises, alertes récentes, stocks faibles, officines récemment modifiées.
4. **Officine détail** :
   - Table inventaire avec tri/filtre/recherche.
   - Panneau latéral avec détails de la boîte sélectionnée.
   - Actions en bulk (multiselect).
5. **Ordonnances** : liste + détail + création.
6. **Timeline de prises** : vue jour, semaine, mois avec statuts.
7. **Partages** : gestion granulaire, invitations en cours.
8. **Paramètres** : mêmes options que mobile.
9. **Vue pro** (si type_compte = pro) : liste patients + navigation rapide.
10. **Mentions légales / CGU / Confidentialité** : pages publiques statiques.

### Points d'attention web

- Responsive mais pensé **desktop-first** pour l'usage pro.
- Le scan de DataMatrix sur web est **limité** (PWA avec caméra, moins fiable que natif). On peut le prévoir comme nice-to-have ou le retirer côté web.
- Keyboard shortcuts pour les pros : raccourci pour valider une prise, ajouter une boîte, etc.

---

## Composants transverses

### Notifications in-app

- Toast non-bloquant en bas/haut pour feedback action.
- Modale pour confirmations destructives.
- Banner en haut de l'app pour messages importants (mode hors-ligne, mise à jour disponible).

### Indicateur de synchronisation

- Petit badge ou icône quelque part (header ?) qui indique l'état :
  - ✅ Synchronisé
  - ⟳ Synchronisation en cours
  - ⚠️ Opérations en attente (N)
  - ⛔ Échec de sync (tap pour détails)

### Indicateur "hors ligne"

- Bandeau subtil en haut quand pas de réseau.
- Confirmation que les actions sont enregistrées localement.

### Mentions de responsabilité

- Phrase-type à afficher (ou équivalent) :
  - **Onboarding** : bloc dédié avec acceptation explicite.
  - **Création d'ordonnance** : petit texte sous le formulaire.
  - **Fiche info médicament** : footer.
  - **OCR résultat** : alert avant validation.
  - **Alertes de prise / stock** : non nécessaire (pas de recommandation).

---

## Illustrations & iconographie

### Icônes

- **Set cohérent** : Lucide (web et mobile) ou Phosphor. Simple, moderne, bonne couverture.
- Icônes fonctionnelles : scan, médicament, officine, partage, alerte, horloge, utilisateur, etc.

### Illustrations

- **Empty states** : illustrations douces pour :
  - Officine vide ("Commencez par scanner une boîte")
  - Pas de prises aujourd'hui ("Tout est calme !")
  - Pas d'alertes ("Rien à signaler")
  - Pas de partages ("Invitez un proche ou un soignant")
- **Onboarding** : 2-3 illustrations pour les écrans de bienvenue.

### Photos de médicaments

- BDPM ne fournit pas de photos officielles.
- Option 1 : pas de photo au MVP (texte + icône générique selon forme).
- Option 2 : banque de photos type Drugs.com ou photos génériques par forme (comprimé rond blanc, gélule rouge, etc.).
- Option 3 (v2) : l'utilisateur prend une photo lui-même au scan.

---

## Prototypage recommandé

Avant de coder, produire dans cet ordre :

1. **Wireframes low-fi** (Excalidraw, crayon) des 10-15 écrans mobile principaux. 1 journée.
2. **User flow** principal : ajouter une boîte, créer une ordonnance, valider une prise, inviter un proche. À faire en parallèle des wireframes.
3. **Moodboard / direction design** : 3-5 références (apps médicales ou non) pour figer la tonalité. Demi-journée.
4. **Design system minimal sur Figma** : couleurs, typo, spacing, composants de base (boutons, inputs, cards). 2-3 jours.
5. **High-fidelity mockups** des 10-15 écrans clés mobile + 5-8 écrans web. 1-2 semaines à temps plein ou spread sur M1-M2.
6. **Prototype interactif Figma** pour tester les 3-4 flux principaux sur 3-5 utilisateurs avant le code.

---

## Décisions de design validées

Toutes les questions d'identité et de direction visuelle ont été tranchées. Cf. section "Identité de marque Piloo" au début de ce document.

**Résumé des décisions**

| Décision | Choix retenu |
|---|---|
| Nom | **Piloo** |
| Direction visuelle | **A+C** — Beige chaleureux + précision nordique + accent terracotta |
| Couleur primaire | **Vert-sauge `#4a6b64`** |
| Couleur accent | **Terracotta `#a8472e`** |
| Mode | **Light only au MVP**, dark en v2 |
| Onboarding | **Obligatoire** (mentions légales vues) |
| Tab bar mobile | **3 onglets** : Aujourd'hui / Officine / Plus + scan en FAB + alertes en header |
| Illustrations | **Custom** (à créer ou sourcer auprès d'un illustrateur) |
| Photos médicaments | **Pas au MVP**, photo utilisateur en v2 |
| Set d'icônes | **Phosphor** (Regular + Fill) |
| Typographie | **Fraunces** (titres) + **Manrope** (corps) |

**Points à préparer avant M1**
- Sourcer 5-8 illustrations custom cohérentes (illustrateur freelance ~200-500€) — ou démarrer avec Phosphor illustrations en placeholder.
- Prévoir `photo_url` sur la table `boites` dès M1 (nullable) pour anticiper la v2.
