# Plan — Maquettes Web Desktop Piloo

> **Note:** ce plan est un plan **design** (livrables = maquettes Pencil), pas un plan code. Le format suit la convention TDD du skill writing-plans (tasks bite-sized, livrables vérifiables) adapté au design.

**Goal:** Designer les maquettes complètes de l'app web desktop Piloo dans Pencil — parité fonctionnelle avec mobile pour la consultation/saisie + ajouts desktop-natifs (table avancée, sidebar, multi-pane, raccourcis clavier visibles).

**Architecture:**
- **Nouveau fichier** `docs/design/piloo-web-desktop.pen` (séparé du mobile)
- **Tokens partagés** (couleurs, typographie, sémantique) — réutilise mobile + ajout échelle typo desktop
- **Design system desktop** propre (sidebar, topbar, table, drawer, modals) — composants Pencil réutilisables
- **Frames** 1440×1024 (desktop standard 13"/14"). Hauteur variable selon scroll
- **Cible dev** : Next.js 15 App Router + shadcn/ui customisé + Tailwind avec tokens Piloo

**Recap mobile pour référence**
Les maquettes mobile (25 écrans, design system, décisions validées) sont sur https://piloo-project.my-monkey.fr/design/recap.html — la cohérence visuelle entre mobile et desktop est cruciale.

---

## Périmètre & inventaire

### Layout types desktop (4)

| | Composition | Usage |
|---|---|---|
| **L1 — Public layout** | Header simplifié + content centré + footer | Landing, pages légales, login |
| **L2 — Auth layout** | Side image / hero gauche + form droite | Connexion, inscription, mdp oublié |
| **L3 — App shell** | Sidebar 240px + Topbar 64px + Main | Toutes les pages logged-in |
| **L4 — App shell + drawer** | App shell + panneau latéral droit (~400px) | Officine table avec détail boîte |

### Composants desktop (~28)

**Foundation**
1. AppShell wrapper (layout L3 + L4)
2. PublicHeader (logo + nav + login CTA)
3. PublicFooter
4. AuthHero (image + tagline gauche)
5. Sidebar nav (logo + items + user widget bottom)
6. Topbar (search global + notifications + officine switcher + avatar menu)

**Surfaces**
7. Card (default + interactive variants)
8. MetricCard (gros chiffre + delta + label)
9. Drawer / SidePanel (animé droite)
10. Modal / Dialog (centered + sized variants)
11. Toast (success/warn/error)
12. EmptyState (illustration + CTA)

**Data**
13. DataTable (sort + filter + select + pagination)
14. TableRow (regular + selected + hover)
15. FilterBar (chips + search + sort)
16. Pagination
17. Timeline (verticale + week-grid)

**Forms**
18. Button — Primary / Outline / Ghost / Apple / Google (desktop sizes)
19. Input (text, email, password, search)
20. Select / Combobox
21. Checkbox + Radio
22. Switch
23. DatePicker / DateRangePicker
24. PhraseInput (posologie naturelle, comme P2 mobile)

**Affordances**
25. Badge / Pill (status, role, priority)
26. Avatar (initials fallback, sizes)
27. Tooltip
28. KeyboardShortcut hint (`⌘K` style chip)

### Écrans à designer (24)

**Phase A — Public (5 écrans)**
- W1 Landing marketing
- W2 Connexion
- W3 Inscription
- W4 Vérification email
- W5 Mot de passe oublié

**Phase B — Onboarding (2 écrans)**
- W6 Choix type compte
- W7 Welcome / quick tour modal

**Phase C — App core (10 écrans)**
- W8 Dashboard (widgets + KPIs)
- W9 Aujourd'hui — Day view
- W10 Aujourd'hui — Week view
- W11 Officine — table + drawer détail boîte
- W12 Fiche médicament (modal)
- W13 Ordonnances — liste
- W14 Ordonnance — création (modal multi-step)
- W15 Ordonnance — détail
- W16 Alertes — feed
- W17 Plus / Profil

**Phase D — Settings (1 template, 4 sections détaillées)**
- W18 Settings — layout + Profil section
- W19 Settings — Notifications + Horaires
- W20 Settings — Sécurité (2FA)
- W21 Settings — Compte (export RGPD, suppression)

**Phase E — Partages M3 (3 écrans)**
- W22 Mes officines + switcher
- W23 Gestion partages (Owner)
- W24 Accepter invitation (page publique + intra-app)

**Hors scope**
- Vue pro multi-patients (M4+)
- Pages légales statiques (CGU/Privacy) — template W6 réutilisable mais pas designé
- Pricing page (post-MVP)

---

## Phase 1 — Initialisation & tokens

### Task 1.1 : Créer le fichier .pen + ouvrir l'éditeur

**Files:**
- Create: `docs/design/piloo-web-desktop.pen`

- [ ] **Step 1:** Ouvrir un nouveau document Pencil au chemin `docs/design/piloo-web-desktop.pen`

```
mcp__pencil__open_document(
  filePathOrTemplate: "/Users/maxim/Documents/my-monkey/piloo/docs/design/piloo-web-desktop.pen"
)
```

- [ ] **Step 2:** Vérifier l'éditeur ouvert et vide

```
mcp__pencil__get_editor_state(include_schema: false)
```

Expected: `Currently active editor: ...piloo-web-desktop.pen` + document vide

### Task 1.2 : Définir les tokens design

**Tokens identiques au mobile + ajout échelle typo desktop**

- [ ] **Step 1:** Set variables (couleurs + typo + spacing + radii) via `set_variables`

Couleurs : `bg`, `surface`, `surface-subtle`, `border`, `primary`, `primary-hover`, `primary-soft`, `accent`, `accent-soft`, `text-primary`, `text-secondary`, `text-tertiary`, `text-on-primary`, `success-bg/fg`, `warning-bg/fg`, `error-bg/fg`, `info-bg/fg`

Typographie desktop (échelle plus grande) :
- `font-title` = "Fraunces"
- `font-body` = "Manrope"
- (Sizes appliqués directement sur les nodes, pas en var)

Spacing :
- `space-xs` = 4, `sm` = 8, `md` = 12, `lg` = 16, `xl` = 24, `2xl` = 32, `3xl` = 48, `4xl` = 64

Radii :
- `radius-sm` = 6, `md` = 8, `lg` = 12, `xl` = 16, `full` = 999

- [ ] **Step 2:** Vérifier que les variables sont bien posées

```
mcp__pencil__get_variables(filePath: ".../piloo-web-desktop.pen")
```

Expected: 30+ variables listées

---

## Phase 2 — Design system desktop (composants foundation)

### Task 2.1 : PublicHeader + PublicFooter

**Position canvas:** zone "Design system" à x=3000, y=0 (séparée des écrans)

- [ ] **Step 1:** Créer **PublicHeader** réutilisable (1440×72)
  - Frame horizontal, padding [16, 32, 16, 32]
  - Gauche : wordmark `piloo` (Fraunces 28, "pil" primary + "oo" accent)
  - Centre : nav links (Fonctionnalités · Tarifs · Aide) — Manrope 14, text-secondary
  - Droite : `Connexion` (ghost button) + `S'inscrire` (primary button)

- [ ] **Step 2:** Créer **PublicFooter** réutilisable (1440×220)
  - Bg surface-subtle, padding [48, 64]
  - 4 colonnes : Produit / Légal / Aide / Contact + ligne séparatrice + copyright + petites mentions

- [ ] **Step 3:** Verify rendering

```
mcp__pencil__get_screenshot(nodeId: <publicHeader_id>)
```

### Task 2.2 : AuthHero (image gauche pour pages auth)

- [ ] **Step 1:** Frame 720×1024, fill gradient primary-soft → accent-soft (135°)
  - Centré : grand wordmark `piloo` (Fraunces 96)
  - Sous-titre : "Le carnet numérique de médicaments" (Fraunces 24)
  - Bullet visuels (3) : ✓ Scan instantané · ✓ Offline · ✓ Partage famille

- [ ] **Step 2:** Verify

### Task 2.3 : Sidebar nav (240px)

- [ ] **Step 1:** Frame `Sidebar` réutilisable, 240×1024
  - Bg surface, border-right border
  - Top section (padding 24) :
    - Logo wordmark mini (Fraunces 24)
    - Officine switcher (button avec house icon + nom officine + caret)
  - Nav items (vertical list, padding [4, 12]) :
    - Dashboard (squares-four icon)
    - Aujourd'hui (sun-horizon)
    - Officine (first-aid-kit)
    - Ordonnances (prescription)
    - Alertes (bell) — avec badge count
  - Spacer flex
  - Bottom section :
    - User widget : avatar + nom + email tronqué + caret menu (sign-out, settings)

- [ ] **Step 2:** Variants : itemActive (bg primary-soft, text primary, indicator left bar)

### Task 2.4 : Topbar (64px)

- [ ] **Step 1:** Frame `Topbar` 1200×64 (= 1440 - 240 sidebar)
  - Padding [12, 24]
  - Gauche : breadcrumb (Officine / Maison)
  - Centre : search global (input avec ⌘K hint à droite)
  - Droite : notifs bell (badge count) + avatar menu

### Task 2.5 : Buttons (Primary / Outline / Ghost / Apple / Google)

- [ ] **Step 1:** 5 variants à 3 sizes (sm 32h, md 40h, lg 48h)
  - Primary : bg primary, text white, hover primary-hover
  - Outline : surface, border, text-primary
  - Ghost : transparent, text-primary, hover surface-subtle
  - Apple : bg #111, white text, apple-logo-fill icon
  - Google : surface, border, google-logo icon

### Task 2.6 : Inputs (text, search, select)

- [ ] **Step 1:** Input base (height 40, radius md, border, padding [0, 14])
  - Variants : default / focused (ring primary) / error (border error-fg)
  - Search variant : icon magnifying-glass à gauche
  - Select : caret-down à droite

### Task 2.7 : DataTable

- [ ] **Step 1:** TableHeader row (bg surface-subtle, font-weight 600, padding [12, 16])
- [ ] **Step 2:** TableRow regular (padding [12, 16], border-bottom subtle, hover bg surface-subtle)
- [ ] **Step 3:** TableRow selected (bg primary-soft, left border primary 3px)
- [ ] **Step 4:** Pagination (Previous · 1 2 3 ... · Next + count "X-Y of Z")

### Task 2.8 : Drawer / SidePanel

- [ ] **Step 1:** Drawer 480×1024
  - Header : title + close X
  - Body scrollable
  - Footer optionnel avec actions

### Task 2.9 : Modal / Dialog

- [ ] **Step 1:** 3 sizes (sm 480, md 640, lg 800)
  - Backdrop noir 50%
  - Card center : header (title + close) + body + footer (cancel + primary action)

### Task 2.10 : Card + MetricCard

- [ ] **Step 1:** Card base (radius lg, surface, border, padding 24)
- [ ] **Step 2:** MetricCard : label + big number (Fraunces 36) + delta (success-fg arrow up / error-fg down) + sparkline placeholder

### Task 2.11 : Badge / Pill / Avatar / Tooltip

- [ ] **Step 1:** Badge sémantique (success/warning/error/info × variants soft + solid)
- [ ] **Step 2:** Avatar 4 sizes (xs 24, sm 32, md 40, lg 56) avec fallback initials
- [ ] **Step 3:** Tooltip (bg #111 white text, arrow)

### Task 2.12 : Timeline component (jour + week)

- [ ] **Step 1:** Day view : vertical timeline avec 4 sections moments (Matin/Midi/Soir/Coucher) + cards prises (réutilise pattern mobile mais wider)
- [ ] **Step 2:** Week view : grille 7 colonnes × 4 rangs moments, cards compactes

### Task 2.13 : PhraseInput (posologie naturelle desktop)

- [ ] **Step 1:** Reprend P2 mobile : "Je prends [N] comprimé · [M] fois par jour" — pills cliquables ouvrent dropdown
- [ ] **Step 2:** Adapté desktop : 18px base, plus d'air

### Task 2.14 : Verify design system completeness

- [ ] **Step 1:** Screenshot canvas zone design system
- [ ] **Step 2:** Confirmer : tous les composants visibles, alignement OK, hover states présents

---

## Phase 3 — Pages publiques

### Task 3.1 : W1 — Landing marketing

**Position:** x=0, y=100, width=1440, height=2400 (long scroll)

- [ ] **Step 1:** Layout L1 (PublicHeader 72 + content + PublicFooter 220)
- [ ] **Step 2:** Hero section (1440×600)
  - Bg gradient primary-soft → accent-soft
  - Centre : H1 Fraunces 64 "Le carnet numérique de médicaments"
  - Sub : Fraunces 24 "Scanne tes boîtes. Suis tes prises. Partage avec tes proches."
  - CTA : Primary "Créer un compte gratuit" + Ghost "Voir comment ça marche"
  - Mockup mobile (right side) : capture écran 02 Aujourd'hui
- [ ] **Step 3:** Section "3 étapes" (icon + titre + texte) : Scanner / Planifier / Partager
- [ ] **Step 4:** Section features (3 cards) : Offline · Privacy first · Famille & pros
- [ ] **Step 5:** Section trust (mentions légales, RGPD, "pas un dispositif médical")
- [ ] **Step 6:** Section CTA finale + footer

### Task 3.2 : W2 — Connexion

**Position:** x=1500, y=100, width=1440, height=1024

- [ ] **Step 1:** Layout L2 (AuthHero gauche 720 + form droite 720)
- [ ] **Step 2:** Form droite (centré, max-width 400) :
  - "Bon retour" Fraunces 36
  - Bouton **Apple** + bouton **Google**
  - Divider "ou"
  - Input email + input password (avec eye)
  - Lien "Mot de passe oublié ?" align right
  - Primary CTA "Se connecter"
  - Footer : "Pas encore de compte ? **S'inscrire**"

### Task 3.3 : W3 — Inscription

**Position:** x=3000, y=100

- [ ] **Step 1:** Layout L2
- [ ] **Step 2:** Form :
  - "Créons ton compte"
  - Apple + Google + divider
  - Prénom + Nom (2 cols)
  - Email
  - Password (avec helper "Au moins 8 caractères")
  - Choix type compte (radio cards : Particulier / Pro de santé)
  - Checkbox CGU + RGPD
  - CTA "Créer mon compte"
  - Lien "Déjà un compte ? Se connecter"

### Task 3.4 : W4 — Vérification email

**Position:** x=4500, y=100

- [ ] **Step 1:** Layout L2 simplifié (sans hero, juste content centré 480px)
- [ ] **Step 2:** Card centrée :
  - Hero icon enveloppe (envelope-simple-fill, primary)
  - "Vérifie ton email"
  - Email pill `maxime@exemple.fr`
  - Help bloc info
  - CTA "J'ai cliqué sur le lien"
  - Lien petit "Renvoyer dans 42 s"

### Task 3.5 : W5 — Mot de passe oublié

**Position:** x=6000, y=100

- [ ] **Step 1:** Card 480 centré
  - Hero icon clé (key-fill, accent)
  - "Mot de passe oublié"
  - Sub "Indique ton email, on t'envoie un lien."
  - Input email
  - CTA "Recevoir le lien"
  - Lien "Retour à la connexion"

---

## Phase 4 — Onboarding intra-app

### Task 4.1 : W6 — Choix type compte (alternative à intégration W3)

**Position:** x=0, y=2600

- [ ] **Step 1:** Layout L2
- [ ] **Step 2:** Form 480 centré
  - "Tu utilises Piloo pour..."
  - 2 grandes radio cards : Particulier (house-fill) / Pro de santé (first-aid)
  - CTA "Continuer"

### Task 4.2 : W7 — Welcome modal (post-signup)

**Position:** x=1500, y=2600 (overlay sur Dashboard)

- [ ] **Step 1:** Capture du Dashboard en arrière-plan (réutilise visuel W8 grisé)
- [ ] **Step 2:** Modal large (800px) centré
  - 3 slides en carousel : "Scanne" / "Suis" / "Partage"
  - Dots de pagination
  - Skip + Suivant + (slide finale) "C'est parti"

---

## Phase 5 — App core

### Task 5.1 : W8 — Dashboard

**Position:** x=0, y=3700

- [ ] **Step 1:** Layout L3 (Sidebar 240 + Topbar 64 + Main)
- [ ] **Step 2:** Main content (padding 32, gap 24)
  - Header : "Bonjour Maxime" Fraunces 36 + sub "Voici ce qui se passe aujourd'hui"
  - Row 1 : 4 MetricCards (Prises aujourd'hui · Stocks faibles · Alertes · Boîtes) avec deltas
  - Row 2 : 2 colonnes :
    - Card "Prochaines prises" (4-5 prises listées avec heure + nom + statut bouton "Valider")
    - Card "Alertes récentes" (3 alertes avec icône + meta)
  - Row 3 : Card pleine largeur "Stocks à surveiller" (mini-table 5 lignes : Médicament · Reste · Jours estimés · Action)

### Task 5.2 : W9 — Aujourd'hui (Day view)

**Position:** x=1500, y=3700

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Topbar : breadcrumb "Aujourd'hui"
- [ ] **Step 3:** Main :
  - Header row : H1 "Aujourd'hui" + tabs `Jour` / `Semaine` / `Mois` (Day actif) + day picker (< Lundi 23 avril >)
  - Timeline component vertical (réutilise pattern mobile, 4 sections × 1-2 cards each)
  - Sidebar droite (collapsed) : "Détails sélection" placeholder (visible quand prise sélectionnée)

### Task 5.3 : W10 — Aujourd'hui (Week view)

**Position:** x=3000, y=3700

- [ ] **Step 1:** Comme W9 mais tab `Semaine` actif
- [ ] **Step 2:** Grille 7 colonnes (Lun → Dim) × 4 rangs (Matin/Midi/Soir/Coucher)
  - Cellule : nb prises + petits dots colorés selon statut
  - Hover cellule : tooltip détaillé
  - Total semaine en footer

### Task 5.4 : W11 — Officine (table + drawer)

**Position:** x=4500, y=3700, width=1440, height=1024

- [ ] **Step 1:** Layout L4 (Sidebar + Topbar + Main + Drawer 480 droite)
- [ ] **Step 2:** Topbar : breadcrumb "Officine" + button "+ Nouvelle boîte"
- [ ] **Step 3:** Main toolbar :
  - Filter bar : chips (Tout 12 · Actif · Périmé 1 · Stock bas 2) + search input + sort dropdown
  - Bulk actions row (visible si selection > 0) : "X selected · Marquer vide · Supprimer · Exporter"
- [ ] **Step 4:** DataTable (7 cols : checkbox / Nom / DCI / Lot / Péremption / Stock / Officine / actions)
  - 8-10 lignes exemples (variantes statuts : actif/warning péremption/error périmée)
- [ ] **Step 5:** Drawer droite : détail boîte sélectionnée
  - Hero card médicament (icon + nom + DCI)
  - Info grid (4 cells : Péremption, Stock, Lot, Ajouté)
  - Lien "Voir fiche médicament"
  - Historique (3 entrées)
  - Footer : Modifier + Marquer vide

### Task 5.5 : W12 — Fiche médicament (modal)

**Position:** x=6000, y=3700 (overlay sur W11)

- [ ] **Step 1:** Modal lg (800×900) centré, backdrop
- [ ] **Step 2:** Header : title + close
- [ ] **Step 3:** Body :
  - Hero (primary-soft) : icon + nom + DCI + tags (Non listé / Remboursé 65%)
  - Info table (Principe actif cliquable, Laboratoire, Forme, CIP13)
  - Bloc IA résumé (accent-soft) : "À quoi ça sert" + texte
  - CTA "Voir notice officielle" (outline avec arrow-square-out)
  - Footer disclaimer italique

### Task 5.6 : W13 — Ordonnances (liste)

**Position:** x=0, y=4900

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Topbar : breadcrumb + "+ Nouvelle ordonnance" CTA
- [ ] **Step 3:** Main :
  - Filter chips : Active 2 · Terminée 5 · Toutes
  - Liste cards (3 cards exemples) : prescripteur + date + badge active/terminée + nb médicaments + 3 médocs preview + chevron

### Task 5.7 : W14 — Création ordonnance (modal multi-step)

**Position:** x=1500, y=4900

- [ ] **Step 1:** Modal lg centré
- [ ] **Step 2:** Header : title "Nouvelle ordonnance" + close + step indicator (1 Infos · 2 Prescriptions · 3 Récap, étape 2 active)
- [ ] **Step 3:** Body — montrer step 2 (Prescriptions) :
  - Card médicament sélectionné (avec lien Changer)
  - Bloc Posologie (PhraseInput "Je prends 1 comprimé · 2 fois par jour")
  - Moments de prise (4 chips : Matin actif / Midi / Soir / Coucher)
  - Avec repas toggle + Durée select
  - Lien "+ Ajouter une autre prescription"
- [ ] **Step 4:** Footer : Annuler + Précédent + Suivant

### Task 5.8 : W15 — Ordonnance détail

**Position:** x=3000, y=4900

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Header card : prescripteur + date + badge active + actions (Dupliquer / Modifier / Supprimer)
- [ ] **Step 3:** Liste prescriptions (chaque ligne : nom + posologie phrase + moments + durée + bouton "Voir prises")

### Task 5.9 : W16 — Alertes feed

**Position:** x=4500, y=4900

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Topbar + breadcrumb + button "Tout marquer lu"
- [ ] **Step 3:** Main : groupes par date (Aujourd'hui / Cette semaine / Plus ancien)
  - Cards alertes (icon coloré + titre + sub + dot non lu)
  - Variantes : prise oubliée (warning), péremption proche (accent), stock bas, manque signalé, partage accepté

### Task 5.10 : W17 — Plus / Profil (page principale paramètres)

**Position:** x=6000, y=4900

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Header : "Profil & paramètres"
- [ ] **Step 3:** Layout 2 colonnes :
  - Sidebar gauche (240) : nav settings (Profil actif / Notifications / Préférences / Sécurité / Compte)
  - Main : sous-page Profil :
    - Card avatar + bouton "Changer photo"
    - Form : Prénom · Nom · Email (+ vérifié badge) · Téléphone
    - Card "Type de compte" : Particulier (avec lien "Devenir pro")
    - CTA "Enregistrer"

---

## Phase 6 — Settings sub-pages

### Task 6.1 : W18 — Settings Notifications + Horaires

**Position:** x=0, y=6100

- [ ] **Step 1:** Même layout L3 + nav settings (Notifications actif)
- [ ] **Step 2:** Section "Préférences par canal" : 3 colonnes (Push / Email / SMS) × N events (Rappel prise / Prise oubliée / Péremption proche / Stock bas / Manque signalé) — chaque cellule = checkbox
- [ ] **Step 3:** Section "Horaires par défaut" : 4 time pickers (Matin 8:00 / Midi 12:00 / Soir 19:00 / Coucher 22:00) + warning "Modifier régénère les prises planifiées"

### Task 6.2 : W19 — Settings Sécurité (2FA)

**Position:** x=1500, y=6100

- [ ] **Step 1:** Layout settings
- [ ] **Step 2:** Sections :
  - Mot de passe : "Dernière modif il y a 30j" + CTA "Changer"
  - 2FA : toggle on/off + (si on) : codes de secours, app TOTP setup
  - Sessions actives : liste devices + "Déconnecter" par device

### Task 6.3 : W20 — Settings Compte (RGPD)

**Position:** x=3000, y=6100

- [ ] **Step 1:** Layout settings
- [ ] **Step 2:** Sections :
  - Export RGPD : "Télécharger toutes mes données" (button)
  - Langue : Français (select)
  - Thème : Clair / Sombre / Auto (M3+)
  - Zone danger (border error) : Supprimer mon compte (délai 7j)

---

## Phase 7 — Partages M3

### Task 7.1 : W21 — Mes officines

**Position:** x=0, y=7300

- [ ] **Step 1:** Layout L3
- [ ] **Step 2:** Header + button "+ Créer une officine"
- [ ] **Step 3:** Grid de cards officines (3 exemples, cf S1 mobile mais wider) :
  - Maison (Propriétaire, 12 boîtes, actif)
  - Papa (Éditeur, 8 boîtes, partagée par Marie D.)
  - Mme Dubois (Propriétaire, patient IDEL)

### Task 7.2 : W22 — Gestion partages

**Position:** x=1500, y=7300

- [ ] **Step 1:** Layout L3, breadcrumb "Officines / Maison / Partages"
- [ ] **Step 2:** Header : "Partages · Maison" + button "+ Inviter"
- [ ] **Step 3:** Section Membres : table (Avatar · Nom · Email · Rôle dropdown · actions Révoquer)
- [ ] **Step 4:** Section Invitations en attente : liste (Email · Rôle · Expire dans · Renvoyer / Annuler)
- [ ] **Step 5:** Bloc info Légende des rôles

### Task 7.3 : W23 — Modal Inviter

**Position:** x=3000, y=7300

- [ ] **Step 1:** Modal md centré (overlay sur W22)
- [ ] **Step 2:** Form :
  - Email destinataire
  - Radio cards rôle (Owner / Editor / Reader, Editor sélectionné)
  - Info "Lien expire dans 72h"
- [ ] **Step 3:** Footer : Annuler + Envoyer

### Task 7.4 : W24 — Accepter invitation (page publique)

**Position:** x=4500, y=7300

- [ ] **Step 1:** Layout L1 simplifié (PublicHeader + content centré)
- [ ] **Step 2:** Card 600 centré :
  - Hero avatar inviteur + "Sophie Laurent t'invite à rejoindre"
  - Big "Maison" Fraunces 56
  - Officine card (icon + meta)
  - Badge rôle "En tant qu'Éditeur"
  - Liste droits ✓/✗
  - 2 CTA : Accepter (primary) · Refuser (outline)

---

## Phase 8 — Export & livraison

### Task 8.1 : Export PNG de tous les écrans

- [ ] **Step 1:** Pour chaque écran W1-W24, export PNG 2x dans `docs/design/exports/web/`
- [ ] **Step 2:** Renommer en `W01-landing.png` ... `W24-accepter-invitation.png`

### Task 8.2 : Mettre à jour le hub

- [ ] **Step 1:** Créer une section "Web desktop" dans `index.html` du hub avec les 24 cards
- [ ] **Step 2:** Créer `recap-web.html` (sur le modèle de `recap.html` mobile)
- [ ] **Step 3:** Redéployer sur `piloo-project.my-monkey.fr`

### Task 8.3 : Synthèse pour le repo GitHub

- [ ] **Step 1:** Mettre à jour les tickets `platform:web` avec les liens vers les maquettes
- [ ] **Step 2:** Update issue body de E23 (Web desktop app) avec inventaire des écrans

---

## Self-review

**Spec coverage** (cf `ui-ux-guidelines.md` §"Liste des écrans web") :
- ✅ 1. Landing (W1)
- ✅ 2. Pages auth (W2-W5)
- ✅ 3. Dashboard (W8)
- ✅ 4. Officine détail (W11)
- ✅ 5. Ordonnances (W13-W15)
- ✅ 6. Timeline (W9-W10)
- ✅ 7. Partages (W21-W24)
- ✅ 8. Paramètres (W17-W20)
- ⏭️ 9. Vue pro — explicitement hors scope MVP (M4+)
- ⏭️ 10. Pages légales statiques — template W6 réutilisable, contenu réel via `viewer.html`

**Cohérence avec mobile :**
- Tokens identiques (couleurs, sémantique, radii)
- Composants équivalents pour les écrans communs (PhraseInput posologie P2 conservée)
- Style identique : Fraunces titres + Manrope corps, palette vert-sauge + terracotta

**Estimation effort** : ~3 sessions intensives Pencil (1 par phase 2-5 + 1 phases 6-7 + 1 export/livraison).

---

## Dépendances entre tâches

```
Phase 1 (init + tokens)
  ↓
Phase 2 (composants foundation) ← bloque tout le reste
  ↓
Phase 3 (public) ──┐
Phase 4 (onboarding) ──┤
Phase 5 (app core) ←┘ utilise composants Phase 2
  ↓
Phase 6 (settings) ← utilise W17 comme base
Phase 7 (partages) ← peut être parallèle de Phase 6
  ↓
Phase 8 (export + livraison)
```

---

## Décisions à confirmer avec l'utilisateur

1. **Frame width** : 1440px (laptop standard) — OK ? (alternative : 1280 ou 1536)
2. **Web responsive** : on prévoit le breakpoint tablette (768-1024) ou desktop-only pour MVP ?
3. **Settings — détaillés ou consolidés** : 4 sub-pages détaillés (proposé) OU 1 seul écran avec sections ?
4. **Pricing page** : pas dans le plan car post-MVP. Confirmer ?
5. **Vue pro** : explicitement hors MVP (M4+). Confirmer report ?
6. **Welcome modal post-signup** : utile ou skip (le mobile a déjà l'onboarding, web peut juste rediriger vers Dashboard) ?
