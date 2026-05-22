// Modale "Rappel rapide" (#98).
// 4 toggles matin/midi/soir/coucher avec champ numérique inline (1-99).
// Au moins un moment doit avoir une quantité — sinon le bouton créer
// reste désactivé (cf. validation back qui rejette aussi).
//
// Pas de bouton "date début / fin" sur ce premier ship : on prend
// today comme date_debut, date_fin null (rappel sans fin). UI plus
// avancée = follow-up.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';

class RappelQuickResult {
  const RappelQuickResult({
    required this.matin,
    required this.midi,
    required this.soir,
    required this.coucher,
    required this.unite,
  });

  final int? matin;
  final int? midi;
  final int? soir;
  final int? coucher;
  final String unite;

  bool get hasAtLeastOneMoment =>
      matin != null || midi != null || soir != null || coucher != null;
}

/// Ouvre la modale. Retourne le résultat saisi (ou null si annulé).
Future<RappelQuickResult?> showRappelQuickSheet(
  BuildContext context, {
  required String medicamentName,
  /// Unité par défaut (BDPM doseUnit si dispo, sinon 'comprimé').
  String suggestedUnite = 'comprimé',
}) {
  return showModalBottomSheet<RappelQuickResult>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RappelQuickSheet(
      medicamentName: medicamentName,
      suggestedUnite: suggestedUnite,
    ),
  );
}

class _RappelQuickSheet extends StatefulWidget {
  const _RappelQuickSheet({
    required this.medicamentName,
    required this.suggestedUnite,
  });

  final String medicamentName;
  final String suggestedUnite;

  @override
  State<_RappelQuickSheet> createState() => _RappelQuickSheetState();
}

class _RappelQuickSheetState extends State<_RappelQuickSheet> {
  // null = moment non coché. Quand on coche, on initialise à 1 par défaut.
  int? _matin;
  int? _midi;
  int? _soir;
  int? _coucher;

  bool get _canSubmit =>
      _matin != null || _midi != null || _soir != null || _coucher != null;

  void _toggle(String key, bool on) {
    setState(() {
      final defaultQty = on ? 1 : null;
      switch (key) {
        case 'matin':
          _matin = defaultQty;
        case 'midi':
          _midi = defaultQty;
        case 'soir':
          _soir = defaultQty;
        case 'coucher':
          _coucher = defaultQty;
      }
    });
  }

  void _setQty(String key, int qty) {
    final clamped = qty.clamp(1, 99);
    setState(() {
      switch (key) {
        case 'matin':
          _matin = clamped;
        case 'midi':
          _midi = clamped;
        case 'soir':
          _soir = clamped;
        case 'coucher':
          _coucher = clamped;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Padding bottom adaptatif au clavier — la sheet contient des
    // TextField qui ne doivent pas être masqués quand le keyboard monte.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboardInset),
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
            _Header(name: widget.medicamentName),
            const SizedBox(height: 16),
            _MomentRow(
              icon: PhosphorIconsRegular.sun,
              label: 'Matin',
              qty: _matin,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('matin', v),
              onQtyChange: (n) => _setQty('matin', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.sunHorizon,
              label: 'Midi',
              qty: _midi,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('midi', v),
              onQtyChange: (n) => _setQty('midi', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.cloudSun,
              label: 'Soir',
              qty: _soir,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('soir', v),
              onQtyChange: (n) => _setQty('soir', n),
            ),
            const SizedBox(height: 8),
            _MomentRow(
              icon: PhosphorIconsRegular.moon,
              label: 'Coucher',
              qty: _coucher,
              unite: widget.suggestedUnite,
              onToggle: (v) => _toggle('coucher', v),
              onQtyChange: (n) => _setQty('coucher', n),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _SecondaryButton(onTap: () => Navigator.of(context).pop())),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _PrimaryButton(
                    onTap: _canSubmit
                        ? () => Navigator.of(context).pop(
                              RappelQuickResult(
                                matin: _matin,
                                midi: _midi,
                                soir: _soir,
                                coucher: _coucher,
                                unite: widget.suggestedUnite,
                              ),
                            )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

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
              PhosphorIconsFill.bell,
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
                  'NOUVEAU RAPPEL',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: PilooColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
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

class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.icon,
    required this.label,
    required this.qty,
    required this.unite,
    required this.onToggle,
    required this.onQtyChange,
  });

  final IconData icon;
  final String label;
  final int? qty;
  final String unite;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQtyChange;

  bool get _on => qty != null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PilooColors.surface,
      borderRadius: BorderRadius.circular(PilooRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.lg),
        onTap: () => onToggle(!_on),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PilooRadius.lg),
            border: Border.all(
              color: _on ? PilooColors.primary : PilooColors.border,
              width: _on ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _on ? PilooColors.primarySoft : PilooColors.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 18,
                  color: _on ? PilooColors.primary : PilooColors.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _on ? PilooColors.textPrimary : PilooColors.textSecondary,
                  ),
                ),
              ),
              if (_on)
                _QtyStepper(
                  value: qty!,
                  unite: unite,
                  onChange: onQtyChange,
                )
              else
                Text(
                  'Aucune',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: PilooColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.unite,
    required this.onChange,
  });

  final int value;
  final String unite;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepBtn(
          icon: PhosphorIconsRegular.minus,
          onTap: value > 1 ? () => onChange(value - 1) : null,
        ),
        Container(
          width: 56,
          alignment: Alignment.center,
          child: Text(
            '$value $unite${value > 1 ? 's' : ''}',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PilooColors.textPrimary,
            ),
          ),
        ),
        _StepBtn(
          icon: PhosphorIconsRegular.plus,
          onTap: value < 99 ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PilooColors.surfaceSubtle,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: disabled ? PilooColors.textTertiary : PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? PilooColors.surfaceSubtle : PilooColors.primary,
      borderRadius: BorderRadius.circular(PilooRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(PilooRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            'Créer le rappel',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: disabled ? PilooColors.textTertiary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.onTap});
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
          alignment: Alignment.center,
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
    );
  }
}
