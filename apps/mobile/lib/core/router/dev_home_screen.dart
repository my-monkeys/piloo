// Écran de navigation de dev (liste cliquable des 32 routes M1).
//
// Temporaire : posé sur la route racine `/` tant que l'écran A1 Splash
// (#58) n'est pas implémenté. Quand #58 atterrira, ce widget sera
// déplacé derrière un toggle dev (long-press du logo, par exemple) ou
// supprimé.
//
// Permet à l'équipe design de reviewer chaque écran sans avoir à
// rebuilder l'app pour changer `initialLocation`.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:piloo/core/theme/colors.dart';

import 'routes.dart';

class DevHomeScreen extends StatelessWidget {
  const DevHomeScreen({super.key});

  static const _sections = <({String title, List<({String label, String path})> routes})>[
    (
      title: 'Auth & onboarding',
      routes: [
        (label: 'O1 Welcome', path: RoutePath.welcome),
        (label: 'O2 Mentions légales', path: RoutePath.legal),
        (label: 'O3 Permissions', path: RoutePath.permissions),
        (label: 'A2 Type de compte', path: RoutePath.accountType),
        (label: 'A3 Connexion', path: RoutePath.signIn),
        (label: 'A4 Inscription email + password', path: RoutePath.signUp),
        (label: 'A5 Vérification email', path: RoutePath.verifyEmail),
        (label: 'A6 Mot de passe oublié', path: RoutePath.forgotPassword),
      ],
    ),
    (
      title: 'Tab bar',
      routes: [
        (label: '01 Aujourd\'hui', path: RoutePath.today),
        (label: '02 Officine', path: RoutePath.officine),
        (label: '12 Plus', path: RoutePath.more),
      ],
    ),
    (
      title: 'Actions',
      routes: [
        (label: 'Scan', path: RoutePath.scan),
        (label: 'Alertes', path: RoutePath.alertes),
      ],
    ),
    (
      title: 'Boîtes',
      routes: [
        (label: 'Nouvelle boîte (post-scan)', path: RoutePath.boiteAdd),
      ],
    ),
    (
      title: 'Ordonnances',
      routes: [
        (label: 'Liste ordonnances', path: RoutePath.ordonnances),
        (label: 'Création ordonnance', path: RoutePath.ordonnanceCreate),
        (label: 'OCR ordonnance', path: RoutePath.ordonnanceOcr),
      ],
    ),
    (
      title: 'Officines & partages',
      routes: [
        (label: 'Mes officines', path: RoutePath.officinesList),
      ],
    ),
    (
      title: 'Paramètres',
      routes: [
        (label: 'Settings', path: RoutePath.settings),
        (label: 'Profil', path: RoutePath.settingsProfile),
        (label: 'Notifications', path: RoutePath.settingsNotifications),
        (label: 'Horaires par défaut', path: RoutePath.settingsHoraires),
        (label: 'Sécurité (2FA)', path: RoutePath.settingsSecurity),
      ],
    ),
    (
      title: 'Pro',
      routes: [
        (label: 'Vue pro dashboard', path: RoutePath.proDashboard),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      appBar: AppBar(
        backgroundColor: PilooColors.background,
        title: const Text('Piloo — Dev menu'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _Banner(),
            for (final section in _sections) _Section(section: section),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PilooColors.warning,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        kReleaseMode
            ? 'Build release : ce menu ne devrait pas être visible.'
            : 'Dev menu temporaire — sera remplacé par A1 Splash (#58).',
        style: TextStyle(
          color: PilooColors.warningOn,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});

  final ({String title, List<({String label, String path})> routes}) section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            section.title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: PilooColors.textTertiary,
            ),
          ),
        ),
        for (final route in section.routes)
          ListTile(
            dense: true,
            title: Text(route.label),
            subtitle: Text(
              route.path,
              style: const TextStyle(
                fontSize: 12,
                color: PilooColors.textTertiary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => context.push(route.path),
          ),
      ],
    );
  }
}
