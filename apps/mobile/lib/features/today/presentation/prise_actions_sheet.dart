// Bottom sheet validation d'une prise (#117).
//
// Pas de maquette dédiée — on s'aligne sur le pattern visuel de la
// `quick_actions_sheet.dart` (#101) : header info en card subtle +
// actions colorées sémantiquement + bouton Annuler.
//
// 3 actions :
//  - taken    : "Marquer comme prise" (check, success vert)
//  - skipped  : "Sauter cette prise" (skip-forward, warning ambre)
//  - snoozed  : "Reporter de 30 min" (clock-clockwise, accent)
//
// Sera appelé depuis Today screen au tap sur une prise card. L'action
// retournée sera convertie en `pending_operations` côté worker sync
// (#91).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum PriseAction { taken, skipped, snoozed }

class PriseActionsContext {
  const PriseActionsContext({
    required this.medicamentName,
    required this.dose,
    required this.scheduledLabel,
  });

  final String medicamentName;
  final String dose;
  // ex: "Prévue à 8:00" ou "Prévue à 19:00 · oubliée"
  final String scheduledLabel;
}

Future<PriseAction?> showPriseActionsSheet(
  BuildContext context, {
  required PriseActionsContext info,
}) {
  return showModalBottomSheet<PriseAction>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PriseActionsSheet(info: info),
  );
}

class _PriseActionsSheet extends StatelessWidget {
  const _PriseActionsSheet({required this.info});

  final PriseActionsContext info;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: PilooColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _SheetHeader(info: info),
            const SizedBox(height: 16),
            _ActionRow(
              icon: PhosphorIconsRegular.check,
              iconColor: PilooColors.successOn,
              iconBg: PilooColors.success,
              title: 'Marquer comme prise',
              subtitle: 'Confirme que tu as bien pris ce médicament',
              onTap: () => Navigator.of(context).pop(PriseAction.taken),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.skipForward,
              iconColor: PilooColors.warningOn,
              iconBg: PilooColors.warning,
              title: 'Sauter cette prise',
              subtitle: 'La prise sera marquée comme sautée',
              onTap: () => Navigator.of(context).pop(PriseAction.skipped),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.clockClockwise,
              iconColor: PilooColors.accent,
              iconBg: PilooColors.accentSoft,
              title: 'Reporter de 30 min',
              subtitle: 'Te rappellera plus tard',
              onTap: () => Navigator.of(context).pop(PriseAction.snoozed),
            ),
            const SizedBox(height: 16),
            _CancelButton(onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.info});

  final PriseActionsContext info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PilooColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PilooColors.primarySoft,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.pill,
              size: 22,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.medicamentName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fraunces(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.dose} · ${info.scheduledLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PilooColors.surface,
      borderRadius: BorderRadius.circular(PilooRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(color: PilooColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PilooColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: PilooColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(PilooRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.md),
            border: Border.all(color: PilooColors.border),
          ),
          child: Center(
            child: Text(
              'Annuler',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
