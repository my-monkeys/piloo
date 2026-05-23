// Bottom sheet popup actions rapides (#101).
// Maquette : `8zkAT` du fichier docs/design/piloo-mobile.pen.
//
// S'ouvre après le scan d'une boîte déjà connue dans une officine.
// Le scan-flow (#84) appelle `showQuickActionsSheet` avec les infos
// de la boîte trouvée. Pour la review visuelle, on l'expose en plus
// via la route `/_dev/quick-actions` (à défaut d'écran réel post-scan
// implémenté).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

enum QuickAction {
  seeInfo,
  adjustStock,
  rename,
  reportMissing,
  /// Incrémente `nombre_boites` sur la boîte existante. Affiché
  /// uniquement quand on ouvre la sheet après un 409 conflict côté
  /// scan : l'user vient de re-scanner un (cip13, lot) déjà connu et
  /// veut signaler qu'il a une 2e boîte physique du même lot.
  addAnotherBox,
  /// Ouvre la modale "Rappel rapide" (#98) — matin/midi/soir/coucher
  /// × quantité, sans passer par une ordonnance.
  setRappel,
}

class QuickActionsContext {
  const QuickActionsContext({
    required this.officineLabel,
    required this.medicamentName,
    this.cip13,
    this.recognizedFromBdpm = false,
    this.peremptionDate,
    this.canAddAnotherBox = false,
    this.substances = const [],
  });

  /// Label affiché dans le header de la sheet : "Maison · Doliprane 1000 mg".
  final String officineLabel;
  final String medicamentName;
  final String? cip13;

  /// True si le médicament est reconnu dans BDPM (le `_mapApiBoite` a
  /// trouvé une dénomination via `BdpmDb.findByCip13`). Quand vrai, on
  /// masque l'action "Renommer" — l'user n'a aucune raison de renommer
  /// un médoc dont le nom officiel est déjà connu.
  final bool recognizedFromBdpm;

  /// Date de péremption de la boîte. Quand non null et dans le futur,
  /// on masque l'action "Marquer comme périmée" — la péremption est
  /// connue, l'app la calculera automatiquement le jour venu.
  final DateTime? peremptionDate;

  /// Affiche l'action "+1 boîte (j'en ai une autre)". Utilisé quand la
  /// sheet est ouverte suite à un 409 conflict côté scan — l'user peut
  /// alors incrémenter `nombre_boites` au lieu d'abandonner.
  final bool canAddAnotherBox;

  /// Substances actives (DCI). Affichées sous le nom dans le header
  /// pour que l'user identifie tout de suite ce qu'il a en main —
  /// utile pour les noms commerciaux peu parlants. Vide si médoc
  /// hors CIS_COMPO_bdpm.
  final List<String> substances;
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
            // Action en tête quand on vient d'un 409 conflict : c'est
            // probablement ce que l'user veut faire si elle re-scan le
            // même lot. Affiché uniquement dans ce contexte.
            if (info.canAddAnotherBox) ...[
              _ActionRow(
                icon: PhosphorIconsRegular.plusCircle,
                iconColor: PilooColors.primary,
                iconBg: PilooColors.primarySoft,
                title: '+1 boîte (j\'en ai une autre)',
                subtitle: 'Même lot, ajoute simplement au compteur',
                onTap: () =>
                    Navigator.of(context).pop(QuickAction.addAnotherBox),
              ),
              const SizedBox(height: 8),
            ],
            _ActionRow(
              icon: PhosphorIconsRegular.bell,
              iconColor: PilooColors.accent,
              iconBg: PilooColors.accentSoft,
              title: 'Définir un rappel rapide',
              subtitle: 'Matin · Midi · Soir · Coucher',
              onTap: () => Navigator.of(context).pop(QuickAction.setRappel),
            ),
            const SizedBox(height: 8),
            // Voir la fiche : 2e position, juste après le rappel.
            // (Résumé IA + notice ANSM.)
            _ActionRow(
              icon: PhosphorIconsRegular.info,
              iconColor: PilooColors.infoOn,
              iconBg: PilooColors.info,
              title: 'Voir la fiche médicament',
              onTap: () => Navigator.of(context).pop(QuickAction.seeInfo),
            ),
            const SizedBox(height: 8),
            _ActionRow(
              icon: PhosphorIconsRegular.slidersHorizontal,
              iconColor: PilooColors.primary,
              iconBg: PilooColors.primarySoft,
              title: 'Ajuster le stock',
              subtitle: 'Plein · 3/4 · Moitié · 1/4 · Vide',
              onTap: () => Navigator.of(context).pop(QuickAction.adjustStock),
            ),
            // "Renommer" : pertinent uniquement quand le scan n'a pas
            // trouvé le médicament en BDPM (cas du médoc inconnu ou
            // étranger). Cacher sinon — sinon l'user croit qu'il doit
            // renommer un Doliprane officiellement reconnu.
            if (!info.recognizedFromBdpm) ...[
              const SizedBox(height: 8),
              _ActionRow(
                icon: PhosphorIconsRegular.pencilSimple,
                iconColor: PilooColors.textPrimary,
                iconBg: PilooColors.surfaceSubtle,
                title: 'Renommer',
                subtitle: 'Utile quand le médicament est inconnu en base',
                onTap: () => Navigator.of(context).pop(QuickAction.rename),
              ),
            ],
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

/// Vrai quand la péremption connue est strictement antérieure à
/// aujourd'hui. `null` (péremption inconnue) → on n'affiche pas
/// l'état périmé, pas d'info fiable.
bool _isExpired(DateTime? peremption) {
  if (peremption == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return peremption.isBefore(today);
}

String _formatFr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.info});

  final QuickActionsContext info;

  @override
  Widget build(BuildContext context) {
    final expired = _isExpired(info.peremptionDate);
    final bgColor = expired ? PilooColors.error : PilooColors.surfaceSubtle;
    final iconBg = expired ? PilooColors.errorOn : PilooColors.primarySoft;
    final iconColor = expired ? PilooColors.error : PilooColors.primary;
    final iconData =
        expired ? PhosphorIconsFill.warningOctagon : PhosphorIconsFill.pill;
    final eyebrowColor =
        expired ? PilooColors.errorOn : PilooColors.textTertiary;
    final textColor =
        expired ? PilooColors.errorOn : PilooColors.textPrimary;
    final subtleColor =
        expired ? PilooColors.errorOn : PilooColors.textTertiary;
    final eyebrow = expired
        ? 'PÉRIMÉ DEPUIS LE ${_formatFr(info.peremptionDate!)}'
        : 'DÉJÀ DANS VOTRE OFFICINE';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, size: 22, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: eyebrowColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.officineLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subtleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info.medicamentName,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.3,
                  ),
                ),
                if (info.substances.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    info.substances.join(' + '),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: expired ? PilooColors.errorOn : PilooColors.accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
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
