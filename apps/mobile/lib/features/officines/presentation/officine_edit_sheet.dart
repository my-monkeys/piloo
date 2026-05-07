// Sheet création / renommage d'officine (#71).
//
// Bottom sheet avec form simple (nom + icône) qui sert pour les 2
// cas d'usage. Câblée depuis le bouton + de S1 (#72) ou depuis le
// menu actions secondaires d'une card officine.
//
// Archivage : confirmation via AlertDialog (helper séparé exposé
// `confirmArchiveOfficine`).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:piloo/core/theme/colors.dart';
import 'package:piloo/core/theme/radius.dart';
import 'package:piloo/shared/widgets/piloo_button.dart';

enum OfficineIconKind { house, heart, userCircle, briefcase }

class OfficineDraft {
  OfficineDraft({this.name = '', this.icon = OfficineIconKind.house});
  String name;
  OfficineIconKind icon;
}

/// Affiche la sheet d'édition. Retourne le draft modifié ou null si
/// annulation. Préremplir `initial` pour le cas renommage.
Future<OfficineDraft?> showOfficineEditSheet(
  BuildContext context, {
  OfficineDraft? initial,
}) {
  final draft = initial ?? OfficineDraft();
  return showModalBottomSheet<OfficineDraft>(
    context: context,
    backgroundColor: PilooColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _OfficineEditSheet(
      draft: draft,
      isEdit: initial != null,
    ),
  );
}

/// Confirmation avant archivage. Retourne true si l'utilisateur a
/// confirmé.
Future<bool> confirmArchiveOfficine(
  BuildContext context, {
  required String officineName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Archiver cette officine ?'),
      content: Text(
        '"$officineName" sera archivée. Les boîtes et ordonnances ne '
        'seront pas supprimées, mais l\'officine ne s\'affichera plus '
        'dans tes listes. Tu pourras la restaurer depuis les paramètres.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Archiver',
            style: GoogleFonts.manrope(color: PilooColors.errorOn),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _OfficineEditSheet extends StatefulWidget {
  const _OfficineEditSheet({required this.draft, required this.isEdit});

  final OfficineDraft draft;
  final bool isEdit;

  @override
  State<_OfficineEditSheet> createState() => _OfficineEditSheetState();
}

class _OfficineEditSheetState extends State<_OfficineEditSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.draft.name);

  static const _iconChoices = [
    (kind: OfficineIconKind.house, icon: PhosphorIconsFill.house, label: 'Foyer'),
    (kind: OfficineIconKind.heart, icon: PhosphorIconsFill.heart, label: 'Proche'),
    (kind: OfficineIconKind.userCircle, icon: PhosphorIconsFill.userCircle, label: 'Patient'),
    (kind: OfficineIconKind.briefcase, icon: PhosphorIconsFill.briefcase, label: 'Pro'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.draft.name = name;
    Navigator.of(context).pop(widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
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
            Center(
              child: Text(
                widget.isEdit
                    ? 'Renommer l\'officine'
                    : 'Nouvelle officine',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: PilooColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'NOM',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: PilooColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: PilooColors.surface,
                borderRadius: BorderRadius.circular(PilooRadius.md),
                border: Border.all(color: PilooColors.border),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _nameCtrl,
                autofocus: !widget.isEdit,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintText: 'Maison, Bureau, Papa…',
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
            const SizedBox(height: 18),
            Text(
              'ICÔNE',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: PilooColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < _iconChoices.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _IconChoice(
                      icon: _iconChoices[i].icon,
                      label: _iconChoices[i].label,
                      selected: widget.draft.icon == _iconChoices[i].kind,
                      onTap: () => setState(
                        () => widget.draft.icon = _iconChoices[i].kind,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            PilooButton(
              label: widget.isEdit ? 'Enregistrer' : 'Créer',
              variant: PilooButtonVariant.primary,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: selected ? 11 : 12),
        decoration: BoxDecoration(
          color: PilooColors.surface,
          borderRadius: BorderRadius.circular(PilooRadius.md),
          border: Border.all(
            color: selected ? PilooColors.primary : PilooColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color:
                  selected ? PilooColors.primary : PilooColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: PilooColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
