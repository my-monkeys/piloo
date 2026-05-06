// Écran 11 Alertes (#149).
// Maquette : `mSCqq` du fichier docs/design/piloo-mobile.pen.
//
// Structure :
//  - Header "Alertes" + action "Tout lire" (texte primary, no-op
//    tant qu'il n'y a pas de provider notifications)
//  - Liste groupée par date (AUJOURD'HUI, CETTE SEMAINE) avec
//    eyebrows tertiary 10pt 0.5 letter-spacing
//  - 5 types d'alertes :
//      - missed (prise oubliée) : card fond $warning + icône
//        warning-fill blanche sur tile $warning-on
//      - expiring (péremption proche) : icône clock-fill accent sur
//        tile $accent-soft
//      - lowStock (stock bas) : icône package $warning-on sur tile
//        $warning
//      - shared (info / partage) : icône hand-waving $info-on sur
//        tile $info — opacity 0.7 = lue
//      - success (partage accepté) : icône check-circle-fill
//        $success-on sur tile $success — opacity 0.7 = lue
//  - Dot rouge à droite = unread (présent sur les 2 premières,
//    absent sur les 3 dernières + opacity 0.7)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum _AlertType { missed, expiring, lowStock, info, success }

class _Alert {
  const _Alert({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.unread,
  });

  final _AlertType type;
  final String title;
  final String subtitle;
  final bool unread;
}

class AlertesScreen extends StatelessWidget {
  const AlertesScreen({super.key});

  static const _today = [
    _Alert(
      type: _AlertType.missed,
      title: 'Prise oubliée — Ramipril 5 mg',
      subtitle: 'Prévue à 19:00 · il y a 1h',
      unread: true,
    ),
    _Alert(
      type: _AlertType.expiring,
      title: 'Péremption proche — Kardegic 75 mg',
      subtitle: 'Expire dans 6 semaines · Maison',
      unread: true,
    ),
  ];

  static const _thisWeek = [
    _Alert(
      type: _AlertType.lowStock,
      title: 'Stock bas — Metformine 500 mg',
      subtitle: 'Moins de 5 jours · pense à renouveler',
      unread: false,
    ),
    _Alert(
      type: _AlertType.info,
      title: 'Manque signalé par Papa',
      subtitle: 'Doliprane 1000 mg · il y a 3 jours',
      unread: false,
    ),
    _Alert(
      type: _AlertType.success,
      title: 'Partage accepté',
      subtitle: 'Sylvie a rejoint « Maman »',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            Expanded(
              // Bottom padding 140 = tab bar (~105) + safe area home
              // indicator (extendBody: true côté _MainShell).
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                children: [
                  _Group(label: "AUJOURD'HUI", alerts: _today),
                  const SizedBox(height: 14),
                  _Group(label: 'CETTE SEMAINE', alerts: _thisWeek),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Le PilooScreenHeader ne propose pas de slot "action texte" — on
    // recompose ici car c'est une particularité de cet écran.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Alertes',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: PilooColors.textPrimary,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {/* no-op tant qu'il n'y a pas de provider */},
            child: Text(
              'Tout lire',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PilooColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.alerts});

  final String label;
  final List<_Alert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
        const SizedBox(height: 8),
        ...List.generate(alerts.length, (i) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: _AlertCard(alert: alerts[i]),
          );
        }),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _Alert alert;

  ({Color cardBg, Color iconBg, Color iconFg, Color dotColor, IconData icon})
      get _style => switch (alert.type) {
            _AlertType.missed => (
                cardBg: PilooColors.warning,
                iconBg: PilooColors.warningOn,
                iconFg: Colors.white,
                dotColor: PilooColors.warningOn,
                icon: PhosphorIconsFill.warning,
              ),
            _AlertType.expiring => (
                cardBg: PilooColors.surface,
                iconBg: PilooColors.accentSoft,
                iconFg: PilooColors.accent,
                dotColor: PilooColors.accent,
                icon: PhosphorIconsFill.clock,
              ),
            _AlertType.lowStock => (
                cardBg: PilooColors.surface,
                iconBg: PilooColors.warning,
                iconFg: PilooColors.warningOn,
                dotColor: PilooColors.warningOn,
                icon: PhosphorIconsRegular.package,
              ),
            _AlertType.info => (
                cardBg: PilooColors.surface,
                iconBg: PilooColors.info,
                iconFg: PilooColors.infoOn,
                dotColor: PilooColors.infoOn,
                icon: PhosphorIconsRegular.handWaving,
              ),
            _AlertType.success => (
                cardBg: PilooColors.surface,
                iconBg: PilooColors.success,
                iconFg: PilooColors.successOn,
                dotColor: PilooColors.successOn,
                icon: PhosphorIconsFill.checkCircle,
              ),
          };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final isMissed = alert.type == _AlertType.missed;
    final subtitleColor =
        isMissed ? PilooColors.warningOn : PilooColors.textSecondary;

    return Opacity(
      // Cards lues : opacity 0.7 (cf. maquette).
      opacity: alert.unread ? 1.0 : 0.7,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: s.cardBg,
          borderRadius: BorderRadius.circular(PilooRadius.lg),
          border: isMissed
              ? null
              : Border.all(color: PilooColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.iconBg,
              ),
              alignment: Alignment.center,
              child: Icon(s.icon, size: 18, color: s.iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (alert.unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.dotColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
