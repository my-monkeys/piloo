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

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/features/auth/presentation/session_provider.dart';
import 'package:piloo/features/officines/data/officines_list_provider.dart';
import 'package:piloo/shared/bdpm/bdpm_provider.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';

/// Version produit côté UI. Synchronisée manuellement avec `pubspec.yaml`
/// au moment des releases — voir Codemagic. Mise dans le footer du Plus.
const String _kAppVersion = '0.1.23';

class _Row {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.iconBg = PilooColors.primarySoft,
    this.iconFg = PilooColors.primary,
    this.routeName,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color iconBg;
  final Color iconFg;
  final String? routeName;
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

  static const _help = [
    _Row(
      icon: PhosphorIconsRegular.question,
      label: 'Aide & FAQ',
      iconBg: PilooColors.surfaceSubtle,
      iconFg: PilooColors.textPrimary,
    ),
    _Row(
      icon: PhosphorIconsFill.info,
      label: "Ce n'est pas un dispositif médical",
      iconBg: PilooColors.accentSoft,
      iconFg: PilooColors.accent,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final officinesCount = ref.watch(officinesListProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => null,
        );
    final bdpmVersion = ref.watch(bdpmDbProvider).maybeWhen(
          data: (db) => db?.version,
          orElse: () => null,
        );
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
                  _Section(
                    label: 'MON APP',
                    rows: _monAppRows(officinesCount),
                  ),
                  const SizedBox(height: 18),
                  _Section(label: 'PRÉFÉRENCES', rows: _prefs),
                  const SizedBox(height: 18),
                  _Section(label: 'AIDE & LÉGAL', rows: _help),
                  const SizedBox(height: 18),
                  _LogoutButton(onTap: () async {
                    await ref.read(sessionProvider.notifier).signOut();
                    if (context.mounted) context.go(RoutePath.welcome);
                  }),
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
        // pushNamed() résout le name de route → path enregistré
        // (cf. router.dart). `context.push('/${row.routeName!}')`
        // construisait à tort un path depuis le name (ex. '/settings-bdpm')
        // au lieu du vrai path (ex. '/settings/bdpm').
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
