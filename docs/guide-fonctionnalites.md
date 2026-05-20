---
title: 'Piloo — Guide des fonctionnalités'
subtitle: "Tour d'horizon du site web"
date: 'Mai 2026'
---

# Piloo — Guide des fonctionnalités

**Piloo** est un carnet numérique de médicaments pour la maison, avec un pont léger entre les particuliers (et leurs aidants) et les professionnels de santé qui passent à domicile. Ce guide passe en revue tout ce que le site web permet de faire.

> _Piloo est un aide-mémoire personnel. Il ne remplace ni votre ordonnance, ni l'avis de votre médecin ou pharmacien._

---

## 1. Découverte et inscription

### 1.1 Landing publique

La page d'accueil présente le produit en trois étapes (scanner, suivre, partager), met en avant les fonctionnalités clés, les éléments de réassurance (RGPD, hébergement français) puis renvoie vers l'inscription.

![Landing marketing](design/exports/web/W01-landing.png)

### 1.2 Inscription

Création d'un compte en quelques champs avec acceptation explicite des CGU et de la politique RGPD.

![Inscription](design/exports/web/W03-signup.png)

### 1.3 Connexion

Connexion par email + mot de passe, ou via Apple / Google. Lien direct vers la réinitialisation.

![Connexion](design/exports/web/W02-login.png)

### 1.4 Vérification d'email

Un email de confirmation est envoyé. L'utilisateur peut relancer l'envoi après un court délai.

![Vérification email](design/exports/web/W04-verif-email.png)

### 1.5 Mot de passe oublié

Réinitialisation par lien magique envoyé par email (expiration 1h).

![Mot de passe oublié](design/exports/web/W05-mdp-oublie.png)

---

## 2. Onboarding

### 2.1 Choix du type de compte

Au premier accès, l'utilisateur choisit entre :

- **Particulier** — gère sa propre armoire à pharmacie et éventuellement celle de proches.
- **Professionnel de santé** — gère plusieurs officines patients (aide-soignant, IDEL, SSIAD…).

![Choix du type de compte](design/exports/web/W06-choix-type.png)

### 2.2 Bienvenue

Une mini visite guidée en trois étapes pose les bases : scanner une boîte, créer une ordonnance, inviter un proche.

![Welcome modal](design/exports/web/W07-welcome-modal.png)

---

## 3. Tableau de bord

Vue d'entrée de l'application connectée :

- 4 indicateurs clés (boîtes en stock, prises du jour, alertes, partages actifs)
- Les prochaines prises à venir
- Les alertes les plus récentes (péremption, stock bas, manque signalé…)

![Dashboard](design/exports/web/W08-dashboard.png)

---

## 4. Aujourd'hui — la timeline des prises

### 4.1 Vue Jour

Liste chronologique des prises de la journée, regroupées par moment : matin, midi, soir, coucher. Chaque prise peut être marquée _prise_, _sautée_ ou _reportée_. Un panneau latéral récapitule la journée.

![Aujourd'hui — vue Jour](design/exports/web/W09-aujourdhui.png)

### 4.2 Vue Semaine

Grille 7 jours × 4 moments avec statuts colorés : utile pour repérer les oublis et préparer la semaine.

![Aujourd'hui — vue Semaine](design/exports/web/W10-week-view.png)

---

## 5. Officine — l'inventaire des boîtes

### 5.1 Inventaire principal

Tableau filtrable des boîtes : par officine, par statut (active / vide / périmée), tri par date de péremption. Regroupement par médicament ou par molécule (DCI), ou vue plate de toutes les boîtes. Le panneau latéral montre le détail d'une boîte sélectionnée (lot, péremption, niveau de stock, historique).

![Officine — table + drawer](design/exports/web/W11-officine.png)

### 5.2 Fiche médicament

Au tap sur un médicament, modale d'informations issues de la BDPM (Base de Données Publique des Médicaments) :

- Nom, dosage, forme galénique
- Principe actif (DCI), laboratoire, taux de remboursement
- Résumé en langage simple (pré-généré)
- Lien vers la notice officielle

![Fiche médicament](design/exports/web/W12-fiche-medicament.png)

---

## 6. Ordonnances

### 6.1 Liste des ordonnances

Toutes les ordonnances saisies, avec prescripteur, date, et un aperçu des médicaments concernés.

![Ordonnances — liste](design/exports/web/W13-ordonnances.png)

### 6.2 Création d'une ordonnance

Modale multi-étapes pour saisir une ordonnance :

- Date et prescripteur (nom + spécialité)
- Médicaments (recherche BDPM ou scan d'une boîte)
- Posologie structurée : nombre d'unités × fréquence, moments de prise, avec/sans repas, durée
- Génération automatique des prises planifiées qui alimentent la timeline

![Création d'ordonnance](design/exports/web/W14-creation-ordonnance.png)

### 6.3 Détail d'une ordonnance

Fiche complète : praticien, statistiques d'observance (prises validées, oubliées, sautées) et liste des prescriptions actives.

![Détail ordonnance](design/exports/web/W15-ordonnance-detail.png)

---

## 7. Alertes

Flux unifié des événements importants, groupés par date. Cinq types d'alertes :

| Type                  | Déclenchement                                |
| --------------------- | -------------------------------------------- |
| Péremption à 30 jours | Une boîte arrive bientôt à péremption        |
| Péremption à 7 jours  | Urgence péremption (push + email)            |
| Stock bas             | Stock estimé < 7 jours de traitement         |
| Prise oubliée         | Aucune validation 1h après l'horaire prévu   |
| Manque signalé        | Un partagé a indiqué qu'un médicament manque |

![Alertes](design/exports/web/W16-alertes.png)

---

## 8. Paramètres

### 8.1 Profil

Édition des informations personnelles : nom, prénom, email, téléphone, type de compte.

![Profil](design/exports/web/W17-profil.png)

### 8.2 Notifications & horaires

Matrice canal × événement : pour chaque type d'alerte, choisir le canal (push, email, SMS). Définition des horaires par défaut des moments de prise (matin, midi, soir, coucher).

![Notifications](design/exports/web/W18-notifs.png)

### 8.3 Sécurité

Changement de mot de passe, activation de la double authentification (TOTP), liste des sessions actives avec révocation.

![Sécurité](design/exports/web/W19-securite.png)

### 8.4 Compte & RGPD

- Export des données personnelles
- Choix de la langue et du thème
- Zone de danger : suppression de compte (délai de grâce 7 jours)

![Compte & RGPD](design/exports/web/W20-compte-rgpd.png)

---

## 9. Officines & partages

### 9.1 Mes officines

Liste des officines accessibles, avec le rôle de l'utilisateur sur chacune et l'officine active. Création possible d'une officine supplémentaire (ex : pour un parent).

![Mes officines](design/exports/web/W21-mes-officines.png)

### 9.2 Gestion des partages

Pour chaque officine, tableau des membres et de leurs rôles, plus les invitations en attente. Trois rôles disponibles :

- **Propriétaire** — tous les droits, y compris la gestion des partages.
- **Éditeur** — peut ajouter / modifier des boîtes, gérer les ordonnances, marquer les prises.
- **Lecteur** — consultation uniquement, mais peut signaler un manque.

![Gestion des partages](design/exports/web/W22-gestion-partages.png)

### 9.3 Inviter un membre

Modale d'invitation : email + choix du rôle, génération d'un lien d'invitation signé valable 72h.

![Modal Inviter](design/exports/web/W23-modal-inviter.png)

### 9.4 Acceptation d'invitation

Page publique sur laquelle atterrit le destinataire du lien : aperçu de l'officine, rôle proposé, et bouton d'acceptation après connexion / inscription.

![Accepter une invitation](design/exports/web/W24-accepter-invitation.png)

---

## En résumé

Piloo couvre tout le cycle d'usage d'une armoire à pharmacie connectée :

1. **Inventaire** — scanner ses boîtes, suivre les stocks et les dates de péremption.
2. **Prises** — timeline jour / semaine, notifications, observance.
3. **Ordonnances** — saisie structurée, génération des prises planifiées.
4. **Partage** — rôles granulaires entre patient, aidant familial et professionnel.
5. **Alertes** — péremption, stock bas, oublis, manques signalés.

Le tout en mode offline-first, avec une base médicaments officielle BDPM mise à jour deux fois par jour.
