// Bottom sheet popup actions rapides (#101).
// Maquette : `8zkAT` du fichier docs/design/piloo-mobile.pen.
//
// S'ouvre après le scan d'une boîte déjà connue dans une officine.
// Le scan-flow (#84) appelle `showQuickActionsSheet` avec les infos
// de la boîte trouvée. Pour la review visuelle, on l'expose en plus
// via la route `/_dev/quick-actions` (à défaut d'écran réel post-scan
// implémenté).
//
// 5 actions, chacune avec sa couleur sémantique :
//  1. Ajuster le stock — primary (action neutre/principale)
//  2. Voir la fiche médicament — info bleu
//  3. Marquer comme vide — warning ambre
//  4. Marquer comme périmée — error rouge
//  5. Signaler un manque — accent terracotta (notification d'un proche)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/router/routes.dart';
import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum QuickAction {
  adjustStock,
  seeInfo,
  markEmpty,
  markExpired,
  reportMissing,
}

class QuickActionsContext {
  const QuickActionsContext({
    required this.officineLabel,
    required this.medicamentName,
    this.cip13,
  });

  /// Label affiché dans le header de la sheet : "Maison · Doliprane 1000 mg".
  final String officineLabel;
  final String medicamentName;
  final String? cip13;
}

/// Affiche la sheet et retourne l'action choisie (ou null si annulé /
/// dismiss). Drag-to-dismiss natif via showModalBottomSheet
/// (isScrollControlled: true permet une hauteur custom).
Future<QuickAction?> showQuickActionsSheet(
  BuildContext context, {
  required QuickActionsContext info,
}) {
  return showModalBottomSheet<QuickAction>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _QuickActionsSheet(info: info),
  );
}

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet({required this.info});

  final QuickActionsContext info;

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
              icon: PhosphorIconsRegular.slidersHorizontal,
              iconColor: PilooColors.primary,
              iconBg: PilooColors.primarySoft,
              title: 'Ajuster le stock',
              subtitle: 'Plein · 3/4 · Moitié · 1/4 · Vide',
              onTap: () => Navigator.of(context).pop(QuickAction.adjustStock),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.info,
              iconColor: PilooColors.infoOn,
              iconBg: PilooColors.info,
              title: 'Voir la fiche médicament',
              onTap: () {
                Navigator.of(context).pop(QuickAction.seeInfo);
                if (info.cip13 != null) {
                  Navigator.of(context)
                      .pushNamed(RoutePath.medicamentInfo(info.cip13!));
                }
              },
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.checkCircle,
              iconColor: PilooColors.warningOn,
              iconBg: PilooColors.warning,
              title: 'Marquer comme vide',
              onTap: () => Navigator.of(context).pop(QuickAction.markEmpty),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.warningOctagon,
              iconColor: PilooColors.errorOn,
              iconBg: PilooColors.error,
              title: 'Marquer comme périmée',
              onTap: () => Navigator.of(context).pop(QuickAction.markExpired),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.handWaving,
              iconColor: PilooColors.accent,
              iconBg: PilooColors.accentSoft,
              title: 'Signaler un manque',
              onTap: () =>
                  Navigator.of(context).pop(QuickAction.reportMissing),
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

  final QuickActionsContext info;

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
                  'DÉJÀ DANS VOTRE OFFICINE',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.officineLabel} · ${info.medicamentName}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PilooColors.textPrimary,
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
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: PilooColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: PilooColors.textTertiary,
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
