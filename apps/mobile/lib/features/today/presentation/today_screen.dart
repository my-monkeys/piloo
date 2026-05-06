// Écran 02 Aujourd'hui (#115). Maquette `ZNRR8`.
//
// Vue principale après onboarding : timeline des prises du jour
// regroupées en 4 sections (Matin/Midi/Soir/Coucher). Pour cette
// première itération, données mockées en local — la connexion à
// la DB locale (Drift) + sync arrive avec les tickets timeline
// (#14 epic).
//
// Statuts de prise rendus :
//  - prise   : cercle plein vert $success + check
//  - à venir : cercle vide bord $border
//  - oubliée : cercle plein $warning-on + warning-fill, et la card
//    elle-même passe en fond $warning + bord $warning-on (signal fort
//    qu'une action est attendue)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_day_picker.dart';
import 'package:piloo/shared/widgets/piloo_screen_header.dart';

enum PriseStatus { taken, upcoming, missed }

class _Prise {
  const _Prise({
    required this.name,
    required this.meta,
    required this.timeOrLabel,
    required this.status,
  });

  final String name;
  final String? meta;
  final String timeOrLabel;
  final PriseStatus status;
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // Date mockée pour la review visuelle (un lundi pour matcher la
  // maquette qui montre "LUNDI 20 avril"). Sera remplacée par
  // DateTime.now() quand le backend timeline sera branché.
  DateTime _date = DateTime(2026, 4, 20);

  void _shiftDay(int delta) {
    setState(() => _date = _date.add(Duration(days: delta)));
  }

  // Mock — sera remplacé par un provider Riverpod consommant la DB
  // locale + sync, groupé par moment.
  List<_Prise> get _matin => const [
        _Prise(
          name: 'Doliprane 1000 mg',
          meta: '1 comprimé',
          timeOrLabel: '8:00',
          status: PriseStatus.taken,
        ),
        _Prise(
          name: 'Kardegic 75 mg',
          meta: '1 sachet · avec repas',
          timeOrLabel: '8:30',
          status: PriseStatus.upcoming,
        ),
      ];

  List<_Prise> get _midi => const [
        _Prise(
          name: 'Metformine 500 mg',
          meta: '1 comprimé · avec repas',
          timeOrLabel: '12:30',
          status: PriseStatus.upcoming,
        ),
      ];

  List<_Prise> get _soir => const [
        _Prise(
          name: 'Ramipril 5 mg',
          meta: 'Prévue à 19:00 · non validée',
          timeOrLabel: 'Oubliée',
          status: PriseStatus.missed,
        ),
      ];

  List<_Prise> get _coucher => const [
        _Prise(
          name: 'Lercanidipine 10 mg',
          meta: null,
          timeOrLabel: '22:00',
          status: PriseStatus.upcoming,
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
            PilooScreenHeader(
              title: "Aujourd'hui",
              bellEnabled: false,
            ),
            PilooDayPicker(
              date: _date,
              onPrev: () => _shiftDay(-1),
              onNext: () => _shiftDay(1),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      icon: PhosphorIconsFill.sunHorizon,
                      label: 'Matin',
                      countLabel: '${_matin.length} prises',
                      countColor: PilooColors.textTertiary,
                      prises: _matin,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.sun,
                      label: 'Midi',
                      countLabel: '1 prise',
                      countColor: PilooColors.textTertiary,
                      prises: _midi,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.moon,
                      label: 'Soir',
                      countLabel: '1 oubliée',
                      countColor: PilooColors.warningOn,
                      prises: _soir,
                    ),
                    const SizedBox(height: 16),
                    _Section(
                      icon: PhosphorIconsFill.moonStars,
                      label: 'Coucher',
                      countLabel: '1 prise',
                      countColor: PilooColors.textTertiary,
                      prises: _coucher,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.countLabel,
    required this.countColor,
    required this.prises,
  });

  final IconData icon;
  final String label;
  final String countLabel;
  final Color countColor;
  final List<_Prise> prises;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: PilooColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: PilooColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                countLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: countColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(prises.length, (i) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: _PriseCard(prise: prises[i]),
          );
        }),
      ],
    );
  }
}

class _PriseCard extends StatelessWidget {
  const _PriseCard({required this.prise});

  final _Prise prise;

  @override
  Widget build(BuildContext context) {
    final missed = prise.status == PriseStatus.missed;
    final cardColor = missed ? PilooColors.warning : PilooColors.surface;
    final borderColor = missed ? PilooColors.warningOn : PilooColors.border;
    final timeColor = switch (prise.status) {
      PriseStatus.taken => PilooColors.textSecondary,
      PriseStatus.upcoming => PilooColors.textPrimary,
      PriseStatus.missed => PilooColors.warningOn,
    };
    final metaColor = missed ? PilooColors.warningOn : PilooColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _StatusDot(status: prise.status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prise.name,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
                  ),
                ),
                if (prise.meta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    prise.meta!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: metaColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            prise.timeOrLabel,
            style: GoogleFonts.manrope(
              fontSize: missed ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: timeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PriseStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      PriseStatus.taken => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.success,
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsBold.check,
            size: 14,
            color: PilooColors.successOn,
          ),
        ),
      PriseStatus.upcoming => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: PilooColors.border, width: 2),
          ),
        ),
      PriseStatus.missed => Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: PilooColors.warningOn,
          ),
          alignment: Alignment.center,
          child: const Icon(
            PhosphorIconsFill.warning,
            size: 14,
            color: Colors.white,
          ),
        ),
    };
  }
}
