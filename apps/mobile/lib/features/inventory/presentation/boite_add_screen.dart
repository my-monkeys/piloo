// Écran 05 Nouvelle boîte post-scan (#89).
// Maquette : `BRaE1` du fichier docs/design/piloo-mobile.pen.
//
// Form pré-rempli depuis le DataMatrix qu'on vient de scanner. Pour
// le POC, données mockées (Doliprane 1000 mg, lot LOT42AB7, exp
// 03/2028) — sera branché sur le résultat du parser GS1 (#81) et la
// résolution BDPM (#83) plus tard.
//
// Structure :
//  - Header centré : back left, "Nouvelle boîte" Fraunces 20, ghost
//    40 right pour équilibrer le layout
//  - Card preview médicament ($primary-soft, radius 12) : tile blanc
//    56 + icône pill-fill primary, nom Fraunces 18, DCI Manrope 12,
//    forme + nb unités Manrope primary
//  - Row péremption (éditable, icône pencil) + n° lot
//  - Select officine cible (caret-down)
//  - 5 chips niveau initial (Plein actif primary, autres outline)
//  - Textarea notes (optionnel) hauteur 72
//  - Spacer + 2 boutons Annuler (outline) / Ajouter (primary)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';
import 'package:piloo/shared/widgets/piloo_circle_back_button.dart';

enum _StockLevel { plein, troisQuarts, moitie, unQuart, presqueVide }

class BoiteAddScreen extends StatefulWidget {
  const BoiteAddScreen({super.key});

  @override
  State<BoiteAddScreen> createState() => _BoiteAddScreenState();
}

class _BoiteAddScreenState extends State<BoiteAddScreen> {
  _StockLevel _stock = _StockLevel.plein;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PilooColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MedicamentPreview(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Field(
                            label: 'PÉREMPTION',
                            child: _ValueRow(
                              text: '03 / 2028',
                              trailing: const Icon(
                                PhosphorIconsRegular.pencilSimple,
                                size: 16,
                                color: PilooColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Field(
                            label: 'N° DE LOT',
                            child: _ValueRow(text: 'LOT42AB7'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      label: 'OFFICINE CIBLE',
                      child: _ValueRow(
                        leading: const Icon(
                          PhosphorIconsFill.house,
                          size: 16,
                          color: PilooColors.primary,
                        ),
                        text: 'Maison',
                        trailing: const Icon(
                          PhosphorIconsRegular.caretDown,
                          size: 14,
                          color: PilooColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StockChips(
                      value: _stock,
                      onChanged: (v) => setState(() => _stock = v),
                    ),
                    const SizedBox(height: 16),
                    _NotesField(controller: _notesCtrl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: PilooButton(
                      label: 'Annuler',
                      variant: PilooButtonVariant.outline,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PilooButton(
                      label: 'Ajouter',
                      variant: PilooButtonVariant.primary,
                      // No-op tant que la persistance Drift n'est pas
                      // câblée (#90 / #91). Le tap fera un push vers
                      // /today.
                      onPressed: () => Navigator.of(context).maybePop(),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Header avec titre centré : back left + ghost 40 right pour
    // équilibrer la largeur (sinon le titre dérive vers la droite).
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PilooCircleBackButton(),
          Flexible(
            child: Text(
              'Nouvelle boîte',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _MedicamentPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PilooColors.primarySoft,
        borderRadius: BorderRadius.circular(PilooRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PilooColors.surface,
              borderRadius: BorderRadius.circular(PilooRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsFill.pill,
              size: 28,
              color: PilooColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doliprane 1000 mg',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paracétamol · Sanofi',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: PilooColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Comprimé pelliculé · 8 unités',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PilooColors.primary,
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: PilooColors.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.text, this.leading, this.trailing});

  final String text;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PilooColors.surface,
        borderRadius: BorderRadius.circular(PilooRadius.md),
        border: Border.all(color: PilooColors.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StockChips extends StatelessWidget {
  const _StockChips({required this.value, required this.onChanged});

  final _StockLevel value;
  final ValueChanged<_StockLevel> onChanged;

  static const _options = [
    (_StockLevel.plein, 'Plein'),
    (_StockLevel.troisQuarts, '3/4'),
    (_StockLevel.moitie, 'Moitié'),
    (_StockLevel.unQuart, '1/4'),
    (_StockLevel.presqueVide, 'Presque vide'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: 'NIVEAU INITIAL',
      child: Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _StockChip(
                label: _options[i].$2,
                selected: value == _options[i].$1,
                onTap: () => onChanged(_options[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: selected ? PilooColors.primary : PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: selected ? null : Border.all(color: PilooColors.border),
        ),
        alignment: Alignment.center,
        // Padding horizontal pour que "Presque vide" tienne sans
        // overflow sur les viewports étroits.
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: label.length > 6 ? 11 : 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color:
                selected ? PilooColors.textOnPrimary : PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: 'NOTES (OPTIONNEL)',
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(color: PilooColors.border),
        ),
        child: TextField(
          controller: controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: 'Armoire salle de bain…',
            hintStyle: GoogleFonts.manrope(
              fontSize: 14,
              color: PilooColors.textTertiary,
            ),
          ),
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: PilooColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
