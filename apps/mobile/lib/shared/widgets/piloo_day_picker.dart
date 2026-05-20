// Day picker — maquette `7QQlM` du frame Aujourd'hui (#115).
// Deux boutons cercles 36 + zone centrale (eyebrow LUNDI + date Fraunces).
// Tap chevron gauche / droit = -1j / +1j.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';

class PilooDayPicker extends StatelessWidget {
  const PilooDayPicker({
    required this.date,
    required this.onPrev,
    required this.onNext,
    super.key,
  });

  final DateTime date;
  /// `null` désactive le bouton (border + icône grisés, pas de tap).
  /// Sert à montrer la borne min/max sans masquer le contrôle.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  static const _weekdays = [
    'LUNDI',
    'MARDI',
    'MERCREDI',
    'JEUDI',
    'VENDREDI',
    'SAMEDI',
    'DIMANCHE',
  ];

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final eyebrow = _weekdays[date.weekday - 1];
    final dateLabel = '${date.day} ${_months[date.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Chevron(icon: PhosphorIconsRegular.caretLeft, onTap: onPrev),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: PilooColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ],
          ),
          _Chevron(icon: PhosphorIconsRegular.caretRight, onTap: onNext),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: disabled ? PilooColors.surfaceSubtle : PilooColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: disabled ? PilooColors.textTertiary : PilooColors.textPrimary,
        ),
      ),
    );
  }
}
