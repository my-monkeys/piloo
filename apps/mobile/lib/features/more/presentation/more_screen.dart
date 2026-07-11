// Écran 12 Plus + sections (#151).
// Maquette : `H5SBa` du fichier docs/design/piloo-mobile.pen.
//
// Structure :
//  - Header "Plus"
//  - Card profil ($primary-soft) : avatar initiales 52, nom Fraunces
//    + email Manrope, chevron — tap → Profil (#153)
//  - 3 sections avec eyebrows tertiary 10pt 0.5LS :
//      MON APP : Mes officines (3) · Ordonnances · Notifications
//        (Push + Email)
//      PRÉFÉRENCES : Horaires par défaut · Langue (Français)
//      AIDE & LÉGAL : Aide & FAQ · Ce n'est pas un dispositif médical
//  - Chaque row = icône 32 sur tile colorée + label + valeur secondaire
//    optionnelle + chevron. Tile $primary-soft pour Mon App, tile
//    $surface-subtle pour Préférences, mix pour Aide & Légal (la rangée
//    "Ce n'est pas un dispositif médical" garde un tile $accent-soft
//    pour la signaler — rappel constant du positionnement).
//  - Bouton "Se déconnecter" : surface + bord + texte + icône rouge
//    $error-on
//  - Footer version "Piloo v0.1.0 · BDPM 2026-04"
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/features/onboarding/presentation/onboarding_tour_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';

/// Version produit côté UI. Synchronisée manuellement avec `pubspec.yaml`
/// au moment des releases — voir Codemagic. Mise dans le footer du Plus.
const String _kAppVersion = '0.1.26';

class _Row {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.iconBg = PilooColors.primarySoft,
    this.iconFg = PilooColors.primary,
    this.routeName,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color iconBg;
  final Color iconFg;
  final String? routeName;

  /// Surcharge la nav par defaut quand l'action n'est pas un push de
  /// route (ex: relancer un tour, toggle un flag local).
  final VoidCallback? onTap;
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  List<_Row> _monAppRows(int? officinesCount) => [
    _Row(
      icon: PhosphorIconsFill.house,
      label: 'Mes officines',
      value: officinesCount?.toString(),
      routeName: RouteName.officinesList,
    ),
    const _Row(
      icon: PhosphorIconsRegular.prescription,
      label: 'Ordonnances',
      routeName: RouteName.ordonnances,
    ),
    const _Row(
      icon: PhosphorIconsRegular.bell,
      label: 'Mes rappels',
      routeName: RouteName.rappels,
    ),
    const _Row(
      icon: PhosphorIconsRegular.bellRinging,
      label: 'Notifications',
      routeName: RouteName.settingsNotifications,
    ),
  ];

  static const _prefs = [
    _Row(
      icon: PhosphorIconsRegular.clock,
      label: 'Horaires par défaut',
      iconBg: PilooColors.surfaceSubtle,
      iconFg: PilooColors.textPrimary,
      routeName: RouteName.settingsHoraires,
    ),
    _Row(
      icon: PhosphorIconsRegular.translate,
      label: 'Langue',
      value: 'Français',
      iconBg: PilooColors.surfaceSubtle,
      iconFg: PilooColors.textPrimary,
    ),
    _Row(
      icon: PhosphorIconsRegular.database,
      label: 'Base médicaments',
      iconBg: PilooColors.surfaceSubtle,
      iconFg: PilooColors.textPrimary,
      routeName: RouteName.settingsBdpm,
    ),
  ];

  List<_Row> _helpRows(BuildContext context, WidgetRef ref) => [
    _Row(
      icon: PhosphorIconsRegular.playCircle,
      label: 'Revoir le tour guidé',
      iconBg: PilooColors.primarySoft,
      iconFg: PilooColors.primary,
      onTap: () {
        // ignore: discarded_futures
        ref.read(tourStepProvider.notifier).start();
      },
    ),
    _Row(
      icon: PhosphorIconsRegular.question,
      label: 'Aide & FAQ',
      iconBg: PilooColors.surfaceSubtle,
      iconFg: PilooColors.textPrimary,
      onTap: () => _showHelpSheet(context),
    ),
    _Row(
      icon: PhosphorIconsFill.info,
      label: "Ce n'est pas un dispositif médical",
      iconBg: PilooColors.accentSoft,
      iconFg: PilooColors.accent,
      onTap: () => _showMedicalDisclaimerSheet(context),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final officinesCount = ref
        .watch(officinesListProvider)
        .maybeWhen(data: (list) => list.length, orElse: () => null);
    final bdpmVersion = ref
        .watch(bdpmDbProvider)
        .maybeWhen(data: (db) => db?.version, orElse: () => null);
    final name = session?.name.trim().isNotEmpty == true
        ? session!.name
        : (session?.email.split('@').first ?? '');
    final email = session?.email ?? '';
    final initials = _computeInitials(name, email);

    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PilooScreenHeader(title: 'Plus', bellEnabled: false),
            Expanded(
              // Bottom padding 140 = tab bar Pill5 (~105) + safe area
              // home indicator (~34) — sinon le dernier élément se
              // retrouve caché sous la tab bar (extendBody: true côté
              // _MainShell pour laisser le $bg transparaître autour
              // de la pilule).
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                children: [
                  _ProfileCard(
                    initials: initials,
                    name: name.isEmpty ? '—' : name,
                    email: email,
                    onTap: () => context.push(RoutePath.settingsProfile),
                  ),
                  const SizedBox(height: 18),
                  _Section(label: 'MON APP', rows: _monAppRows(officinesCount)),
                  const SizedBox(height: 18),
                  _Section(label: 'PRÉFÉRENCES', rows: _prefs),
                  const SizedBox(height: 18),
                  _Section(label: 'AIDE & LÉGAL', rows: _helpRows(context, ref)),
                  const SizedBox(height: 18),
                  _LogoutButton(
                    onTap: () async {
                      await ref.read(sessionProvider.notifier).signOut();
                      if (context.mounted) context.go(RoutePath.welcome);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _formatFooter(bdpmVersion),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: PilooColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _computeInitials(String name, String email) {
  final source = name.trim().isNotEmpty ? name : email;
  if (source.isEmpty) return '?';
  final parts = source.split(RegExp(r'[\s.@]+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return source.substring(0, 1).toUpperCase();
  final letters = parts.take(2).map((p) => p.substring(0, 1).toUpperCase());
  return letters.join();
}

String _formatFooter(String? bdpmVersion) {
  final bdpm = bdpmVersion ?? '—';
  return 'Piloo v$_kAppVersion · BDPM $bdpm';
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PilooColors.primarySoft,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: PilooColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: PilooColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: PilooColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.rows});

  final String label;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: PilooColors.textTertiary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: PilooColors.surface,
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(color: PilooColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(rows.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Container(height: 1, color: PilooColors.border);
              }
              return _RowItem(row: rows[i ~/ 2]);
            }),
          ),
        ),
      ],
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // onTap custom prend la main si fourni (ex: relancer le tour),
        // sinon push de route par défaut.
        if (row.onTap != null) {
          row.onTap!();
          return;
        }
        if (row.routeName != null) {
          context.pushNamed(row.routeName!);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: row.iconBg,
              ),
              alignment: Alignment.center,
              child: Icon(row.icon, size: 16, color: row.iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            if (row.value != null) ...[
              const SizedBox(width: 8),
              Text(
                row.value!,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: PilooColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: PilooColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet « Aide & FAQ » : quelques réponses + contact email.
/// Auto-suffisant (aucune dépendance réseau pour s'ouvrir).
void _showHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InfoSheet(
      title: 'Aide & FAQ',
      children: [
        _FaqItem(
          q: 'Comment ajouter une boîte ?',
          a: 'Touche le bouton scan au centre de la barre et vise le code '
              'DataMatrix au dos de la boîte. Piloo reconnaît le médicament '
              'et pré-remplit tout.',
        ),
        _FaqItem(
          q: 'Comment partager une officine ?',
          a: 'Ouvre une officine, touche l\'icône membres, puis « Inviter '
              'quelqu\'un ». Choisis le rôle : propriétaire, éditeur ou lecteur.',
        ),
        _FaqItem(
          q: 'Mes données sont-elles privées ?',
          a: 'Oui. Aucun tracking publicitaire. Tes données restent les tiennes '
              'et tu peux supprimer ton compte à tout moment depuis ton profil.',
        ),
        const SizedBox(height: 8),
        Text(
          'Besoin d\'aide ? Écris-nous.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: PilooColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // ignore: discarded_futures
            launchUrl(
              Uri.parse('mailto:contact@piloo.fr?subject=Aide%20Piloo'),
              mode: LaunchMode.externalApplication,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: PilooColors.primary,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsRegular.envelope,
                    size: 16, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'contact@piloo.fr',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Bottom sheet « Ce n'est pas un dispositif médical » : rappel du
/// positionnement (cf. CLAUDE.md — non-classification MDR).
void _showMedicalDisclaimerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InfoSheet(
      title: "Ce n'est pas un dispositif médical",
      children: [
        Text(
          'Piloo est un carnet numérique, un aide-mémoire personnel pour la '
          'maison. Ce n\'est pas un dispositif médical.',
          style: GoogleFonts.manrope(
            fontSize: 15,
            height: 1.55,
            color: PilooColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Il ne remplace ni ton ordonnance, ni l\'avis de ton médecin ou '
          'pharmacien, et ne fait aucune recommandation clinique automatique '
          '(pas d\'alerte d\'interaction, pas de validation de posologie).',
          style: GoogleFonts.manrope(
            fontSize: 15,
            height: 1.55,
            color: PilooColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pour toute question de santé, consulte un professionnel.',
          style: GoogleFonts.manrope(
            fontSize: 15,
            height: 1.55,
            fontWeight: FontWeight.w600,
            color: PilooColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          20,
          22,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PilooColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q,
            style: GoogleFonts.manrope(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: PilooColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            a,
            style: GoogleFonts.manrope(
              fontSize: 13.5,
              height: 1.5,
              color: PilooColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              PhosphorIconsRegular.signOut,
              size: 16,
              color: PilooColors.errorOn,
            ),
            const SizedBox(width: 10),
            Text(
              'Se déconnecter',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PilooColors.errorOn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
